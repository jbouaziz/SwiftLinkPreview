//
//  SwiftLinkPreview.swift
//  SwiftLinkPreview
//
//  Created by Leonardo Cardoso on 09/06/2016.
//  Copyright © 2016 leocardz.com. All rights reserved.
//
import Foundation

public enum SwiftLinkResponseKey: String {
    case url
    case finalUrl
    case canonicalUrl
    case title
    case description
    case image
    case images
    case icon
    case video
    case price
}

open class Cancellable: NSObject {
    public private(set) var isCancelled: Bool = false

    open func cancel() {
        isCancelled = true
    }
}

open class SwiftLinkPreview: NSObject {

    // MARK: - Vars
    static let titleMinimumRelevant: Int = 15
    static let decriptionMinimumRelevant: Int = 100

    public var session: URLSession
    public let workQueue: DispatchQueue
    public let responseQueue: DispatchQueue
    public let cache: Cache

    public static let defaultWorkQueue = DispatchQueue.global(qos: .userInitiated)

    // MARK: - Constructor

    //Swift-only init with default parameters
    @nonobjc public init(session: URLSession = URLSession.shared, workQueue: DispatchQueue = SwiftLinkPreview.defaultWorkQueue, responseQueue: DispatchQueue = DispatchQueue.main, cache: Cache = DisabledCache.instance) {
        self.workQueue = workQueue
        self.responseQueue = responseQueue
        self.cache = cache
        self.session = session
    }

    //Objective-C init with default parameters
    @objc public override init() {
        let _session = URLSession.shared
        let _workQueue: DispatchQueue = SwiftLinkPreview.defaultWorkQueue
        let _responseQueue: DispatchQueue = DispatchQueue.main
        let _cache: Cache  = DisabledCache.instance

        self.workQueue = _workQueue
        self.responseQueue = _responseQueue
        self.cache = _cache
        self.session = _session
    }

    //Objective-C init with paramaters.  nil objects will default.  Timeout values are ignored if InMemoryCache is disabled.
    @objc public init(session: URLSession?, workQueue: DispatchQueue?, responseQueue: DispatchQueue?, disableInMemoryCache: Bool, cacheInvalidationTimeout: TimeInterval, cacheCleanupInterval: TimeInterval) {

        let _session = session ?? URLSession.shared
        let _workQueue = workQueue ?? SwiftLinkPreview.defaultWorkQueue
        let _responseQueue = responseQueue ?? DispatchQueue.main
        let _cache: Cache  = disableInMemoryCache ? DisabledCache.instance : InMemoryCache(invalidationTimeout: cacheInvalidationTimeout, cleanupInterval: cacheCleanupInterval)

        self.workQueue = _workQueue
        self.responseQueue = _responseQueue
        self.cache = _cache
        self.session = _session
    }

    // MARK: - Functions
    // Make preview
    //Swift-only preview function using Swift specific closure types
    @nonobjc @discardableResult
    open func preview(_ text: String, onSuccess: @escaping (LinkPreviewResponse) -> Void, onError: @escaping (PreviewError) -> Void) -> Cancellable {

        let cancellable = Cancellable()

        self.session = URLSession(
            configuration: self.session.configuration,
            delegate: self, // To handle redirects
            delegateQueue: self.session.delegateQueue
        )

        let successResponseQueue = { (response: LinkPreviewResponse) in
            guard !cancellable.isCancelled else { return }
            self.responseQueue.async {
                guard !cancellable.isCancelled else { return }
                onSuccess(response)
            }
        }

        let errorResponseQueue = { (error: PreviewError) in
            guard !cancellable.isCancelled else { return }
            self.responseQueue.async {
                guard !cancellable.isCancelled else { return }
                onError(error)
            }
        }

        guard let url = self.extractURL(text: text) else {
            onError(.noURLHasBeenFound(text))
            return cancellable
        }
        workQueue.async {  [unowned self] in
            guard !cancellable.isCancelled else { return }

            if let result = self.cache.slp_getCachedResponse(url: url.absoluteString) {
                successResponseQueue(result)
            } else {

                self.unshortenURL(url, cancellable: cancellable, completion: { unshortened in
                    if let result = self.cache.slp_getCachedResponse(url: unshortened.absoluteString) {
                        successResponseQueue(result)
                    } else {
                        var result = LinkPreviewResponse(url: url)

                        self.extractInfo(response: &result, cancellable: cancellable, completion: { result in
                            self.cache.slp_setCachedResponse(url: unshortened.absoluteString, response: result)
                            self.cache.slp_setCachedResponse(url: url.absoluteString, response: result)

                            successResponseQueue(result)
                        }, onError: errorResponseQueue)
                    }
                }, onError: errorResponseQueue)
            }
        }

        return cancellable
    }

    //Objective-C wrapper for preview method.  Core incompataility is use of Swift specific enum types in closures.
    //Returns a dictionary of rsults rather than enum for success, and an NSError object on error that encodes the local error description on error
    /*
     Keys for the dictionary are derived from the enum names above.  That enum def is canonical, below is a convenience comment
     url
     finalUrl
     canonicalUrl
     title
     description
     image
     images
     icon
     
     */
    @objc @discardableResult open func previewLink(_ text: String, onSuccess: @escaping (Dictionary<String, Any>) -> Void, onError: @escaping (NSError) -> Void) -> Cancellable {

        func success (_ result: LinkPreviewResponse) {
            onSuccess(result.dictionary)
        }

        func failure (_ theError: PreviewError) {
            var errorCode: Int
            errorCode = 1

            switch theError {
            case .noURLHasBeenFound:
                errorCode = 1
            case .invalidURL:
                errorCode = 2
            case .cannotBeOpened:
                errorCode = 3
            case .parseError:
                errorCode = 4
            }

            onError(NSError(domain: "SwiftLinkPreviewDomain",
                            code: errorCode,
                            userInfo: [NSLocalizedDescriptionKey: theError.description]))
        }

        return self.preview(text, onSuccess: success, onError: failure)
    }
}

// Extraction functions
extension SwiftLinkPreview {

    // Extract first URL from text
    open func extractURL(text: String) -> URL? {
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let range = NSRange(location: 0, length: text.utf16.count)
            let matches = detector.matches(in: text, options: [], range: range)

            return matches.compactMap { $0.url }.first
        } catch {
            return nil
        }
    }

    // Unshorten URL by following redirections
    fileprivate func unshortenURL(_ url: URL, cancellable: Cancellable, completion: @escaping (URL) -> Void, onError: @escaping (PreviewError) -> Void) {

        if cancellable.isCancelled {return}

        var task: URLSessionDataTask?
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        task = session.dataTask(with: request, completionHandler: { data, response, error in
            defer {
                task = nil
            }
            guard error == nil else {
                self.workQueue.async {
                    if !cancellable.isCancelled {
                        onError(.cannotBeOpened("\(url.absoluteString): \(error.debugDescription)"))
                    }
                }
                return
            }
            if let finalResult = response?.url {
                if (finalResult.absoluteString == url.absoluteString) {
                    self.workQueue.async {
                        if !cancellable.isCancelled {
                            completion(url)
                        }
                    }
                } else {
                    task?.cancel()
                    self.unshortenURL(finalResult, cancellable: cancellable, completion: completion, onError: onError)
                }
            } else {
                self.workQueue.async {
                    if !cancellable.isCancelled {
                        completion(url)
                    }
                }
            }
        })

        if let task = task {
            task.resume()
        } else {
            self.workQueue.async {
                if !cancellable.isCancelled {
                    onError(.cannotBeOpened(url.absoluteString))
                }
            }
        }
    }

    // Extract HTML code and the information contained on it
    fileprivate func extractInfo(response: inout LinkPreviewResponse, cancellable: Cancellable, completion: @escaping (LinkPreviewResponse) -> Void, onError: @escaping (PreviewError) -> Void) {
        guard !cancellable.isCancelled else { return }

        let url = response.finalUrl

        guard !url.absoluteString.isImage() else {
            // If it's an image, there's no title
            response.images = [url.absoluteString]
            response.image = url.absoluteString
            completion(response)
            return
        }

        guard let sourceUrl = url.scheme == "http" || url.scheme == "https" ? url: URL( string: "http://\(url)" )
            else {
                if !cancellable.isCancelled { onError(.invalidURL(url.absoluteString)) }
                return
        }
        var request = URLRequest( url: sourceUrl )
        request.addValue("text/html,application/xhtml+xml,application/xml", forHTTPHeaderField: "Accept")
        let (data, urlResponse, error) = session.synchronousDataTask(with: request )
        if let error = error {
            if !cancellable.isCancelled {
                let details = "\(sourceUrl.absoluteString): \(error.localizedDescription)"
                onError( .cannotBeOpened( details ) )
                return
            }
        }
        if let data = data, let urlResponse = urlResponse, let encoding = urlResponse.textEncodingName,
            let source = NSString( data: data, encoding:
                CFStringConvertEncodingToNSStringEncoding( CFStringConvertIANACharSetNameToEncoding( encoding as CFString ) ) ) {
            if !cancellable.isCancelled {
                self.parseHtmlString(source as String, response: response, completion: completion)
            }
        } else {
            do {
                let data = try Data(contentsOf: sourceUrl)
                var source: NSString? = nil
                NSString.stringEncoding(for: data, encodingOptions: nil, convertedString: &source, usedLossyConversion: nil)

                if let source = source {
                    if !cancellable.isCancelled {
                        self.parseHtmlString(source as String, response: response, completion: completion)
                    }
                } else {
                    onError(.cannotBeOpened(sourceUrl.absoluteString))
                }
            } catch _ {
                if !cancellable.isCancelled {
                    onError(.parseError(sourceUrl.absoluteString))
                }
            }
        }
    }

    private func parseHtmlString(_ htmlString: String, response: LinkPreviewResponse, completion: @escaping (LinkPreviewResponse) -> Void) {
        completion(self.performPageCrawling(self.cleanSource(htmlString), response: response))
    }

    // Removing unnecessary data from the source
    private func cleanSource(_ source: String) -> String {

        var source = source

        source = source.deleteTagByPattern(Regex.inlineStylePattern)
        source = source.deleteTagByPattern(Regex.inlineScriptPattern)
        source = source.deleteTagByPattern(Regex.scriptPattern)
        source = source.deleteTagByPattern(Regex.commentPattern)

        return source

    }

    // Perform the page crawiling
    private func performPageCrawling(_ htmlCode: String, response: LinkPreviewResponse) -> LinkPreviewResponse {
        var result = self.crawIcon(htmlCode, result: response)

        let sanitizedHtmlCode = htmlCode.deleteTagByPattern(Regex.linkPattern).extendedTrim

        result = self.crawlMetaTags(sanitizedHtmlCode, result: result)

        var otherResponse = self.crawlTitle(sanitizedHtmlCode, result: result)

        otherResponse = self.crawlDescription(otherResponse.htmlCode, result: otherResponse.result)
        
        otherResponse = self.crawlPrice(otherResponse.htmlCode, result: otherResponse.result)

        return self.crawlImages(otherResponse.htmlCode, result: otherResponse.result)
    }
}

// Tag functions
extension SwiftLinkPreview {

    // searc for favicn
    internal func crawIcon(_ htmlCode: String, result: LinkPreviewResponse) -> LinkPreviewResponse {
        var result = result

        let metatags = Regex.pregMatchAll(htmlCode, regex: Regex.linkPattern, index: 1)

        let filters = [ { (link: String) -> Bool in link.range(of: "apple-touch") != nil }, { (link: String) -> Bool in link.range(of: "shortcut") != nil }, { (link: String) -> Bool in link.range(of: "icon") != nil }
        ]

        for filter in filters {
            guard let first = metatags.filter(filter).first else {
                continue
            }
            let matches = Regex.pregMatchAll(first, regex: Regex.hrefPattern, index: 1)
            if let val = matches.first {
                result.icon = self.addImagePrefixIfNeeded(val.replace("\"", with: ""), result: result)
                return result
            }
        }

        return result
    }

    // Search for meta tags
    internal func crawlMetaTags(_ htmlCode: String, result: LinkPreviewResponse) -> LinkPreviewResponse {

        var result = result

        let possibleTags: [String] = [
            LinkPreviewResponse.Key.title.rawValue,
            LinkPreviewResponse.Key.description.rawValue,
            LinkPreviewResponse.Key.image.rawValue,
            LinkPreviewResponse.Key.video.rawValue,
        ]

        let metatags = Regex.pregMatchAll(htmlCode, regex: Regex.metatagPattern, index: 1)

        for metatag in metatags {
            for tag in possibleTags {
                if (metatag.range(of: "property=\"og:\(tag)") != nil ||
                    metatag.range(of: "property='og:\(tag)") != nil ||
                    metatag.range(of: "name=\"twitter:\(tag)") != nil ||
                    metatag.range(of: "name='twitter:\(tag)") != nil ||
                    metatag.range(of: "name=\"\(tag)") != nil ||
                    metatag.range(of: "name='\(tag)") != nil ||
                    metatag.range(of: "itemprop=\"\(tag)") != nil ||
                    metatag.range(of: "itemprop='\(tag)") != nil) {

                    if let key = LinkPreviewResponse.Key(rawValue: tag),
                        result.value(for: key) == nil {
                        if let value = Regex.pregMatchFirst(metatag, regex: Regex.metatagContentPattern, index: 2) {
                            let value = value.decoded.extendedTrim
                            if tag == "image" {
                                let value = addImagePrefixIfNeeded(value, result: result)
                                if value.isImage() { result.set(value, for: key) }
                            } else if tag == "video" {
                                let value = addImagePrefixIfNeeded(value, result: result)
                                if value.isVideo() { result.set(value, for: key) }
                            } else {
                                result.set(value, for: key)
                            }
                        }
                    }
                }
            }
        }

        return result
    }

    // Crawl for title if needed
    internal func crawlTitle(_ htmlCode: String, result: LinkPreviewResponse) -> (htmlCode: String, result: LinkPreviewResponse) {
        var result = result
        let title = result.title

        if title == nil || title?.isEmpty ?? true {
            if let value = Regex.pregMatchFirst(htmlCode, regex: Regex.titlePattern, index: 2) {
                if value.isEmpty {
                    let fromBody: String = self.crawlCode(htmlCode, minimum: SwiftLinkPreview.titleMinimumRelevant)
                    if !fromBody.isEmpty {
                        result.title = fromBody.decoded.extendedTrim
                        return (htmlCode.replace(fromBody, with: ""), result)
                    }
                } else {
                    result.title = value.decoded.extendedTrim
                }
            }
        }

        return (htmlCode, result)
    }

    // Crawl for description if needed
    internal func crawlDescription(_ htmlCode: String, result: LinkPreviewResponse) -> (htmlCode: String, result: LinkPreviewResponse) {
        var result = result
        let description = result.description

        if description == nil || description?.isEmpty ?? true {
            let value: String = self.crawlCode(htmlCode, minimum: SwiftLinkPreview.decriptionMinimumRelevant)
            if !value.isEmpty {
                result.description = value.decoded.extendedTrim
            }
        }

        return (htmlCode, result)
    }

    // Crawl for images
    internal func crawlImages(_ htmlCode: String, result: LinkPreviewResponse) -> LinkPreviewResponse {

        var result = result
        let mainImage = result.image
        if mainImage == nil || mainImage?.isEmpty == true {

            let images = result.images

            if images == nil || images?.isEmpty ?? true {
                let values = Regex.pregMatchAll(htmlCode, regex: Regex.imageTagPattern, index: 2)
                if !values.isEmpty {
                    let imgs = values.map { self.addImagePrefixIfNeeded($0, result: result) }

                    result.images = imgs
                    result.image = imgs.first
                }
            }
        } else {
            result.images = [self.addImagePrefixIfNeeded(mainImage ?? String(), result: result)]
        }
        return result
    }
    
    // Crawl for price
    internal func crawlPrice(_ htmlCode: String, result: LinkPreviewResponse) -> (htmlCode: String, result: LinkPreviewResponse) {
        var result = result
        
        let mainPrice = result.price
        
        if mainPrice == nil || mainPrice?.isEmpty ?? true {
            let values = Regex.pregMatchAll(htmlCode, regex: Regex.pricePattern, index: 1)
            if !values.isEmpty {
                result.price = values.first
            }
        }
        
        return (htmlCode, result)
    }

    // Add prefix image if needed
    fileprivate func addImagePrefixIfNeeded(_ image: String, result: LinkPreviewResponse) -> String {

        let canonicalUrl = result.canonicalUrl
        let finalUrl = result.finalUrl.absoluteString

        if finalUrl.hasPrefix("https:") {
            if image.hasPrefix("//") {
                return "https:" + image
            } else if image.hasPrefix("/") {
                return "https://" + canonicalUrl + image
            }
        } else if image.hasPrefix("//") {
            return "http:" + image
        } else if image.hasPrefix("/") {
            return "http://" + canonicalUrl + image
        }

        return removeSuffixIfNeeded(image)

    }

    private func removeSuffixIfNeeded(_ image: String) -> String {
        if let index = image.firstIndex(of: "?") {
            return String(image[..<index])
        }
        return image
    }

    // Crawl the entire code
    internal func crawlCode(_ content: String, minimum: Int) -> String {

        let resultFirstSearch = self.getTagContent("p", content: content, minimum: minimum)

        guard resultFirstSearch.isEmpty else {
            return resultFirstSearch
        }

        let resultSecondSearch = self.getTagContent("div", content: content, minimum: minimum)
        guard resultSecondSearch.isEmpty else {
            return resultSecondSearch
        }

        let resultThirdSearch = self.getTagContent("span", content: content, minimum: minimum)
        guard resultThirdSearch.isEmpty else {
            return resultThirdSearch
        }
        if resultThirdSearch.count >= resultFirstSearch.count {
            if resultThirdSearch.count >= resultThirdSearch.count {
                return resultThirdSearch
            }
            return resultThirdSearch

        }
        return resultFirstSearch
    }

    // Get tag content
    private func getTagContent(_ tag: String, content: String, minimum: Int) -> String {

        let pattern = Regex.tagPattern(tag)

        let index = 2
        let rawMatches = Regex.pregMatchAll(content, regex: pattern, index: index)

        let matches = rawMatches.filter({ $0.extendedTrim.tagsStripped.count >= minimum })
        var result = matches.count > 0 ? matches[0] : ""

        if result.isEmpty,
            let match = Regex.pregMatchFirst(content, regex: pattern, index: 2) {
            result = match.extendedTrim.tagsStripped
        }

        return result

    }

}

// MARK: - URLSessionDataDelegate
extension SwiftLinkPreview: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest,
                           completionHandler: @escaping (URLRequest?) -> Void) {
        var request = request
        request.httpMethod = "GET"
        completionHandler(request)
    }
}
