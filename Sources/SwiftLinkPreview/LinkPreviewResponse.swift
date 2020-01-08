//
//  Response.swift
//  SwiftLinkPreview
//
//  Created by Giuseppe Travasoni on 20/11/2018.
//  Copyright © 2018 leocardz.com. All rights reserved.
//

import Foundation

public struct LinkPreviewResponse: Equatable {
    
    public let url: URL
    public let finalUrl: URL
    public let canonicalUrl: String

    public internal(set) var title: String?
    public internal(set) var description: String?
    public internal(set) var images: [String]?
    public internal(set) var image: String?
    public internal(set) var icon: String?
    public internal(set) var video: String?
    public internal(set) var price: String?

    init(url: URL) {
        self.url = url
        self.finalUrl = url.extractRedirectionIfNeeded()
        self.canonicalUrl = url.extractCanonicalURL()
    }
}

internal extension URL {

    // Extract canonical URL
    func extractCanonicalURL() -> String {

        let preUrl: String = absoluteString
        let url = preUrl
            .replace("http://", with: "")
            .replace("https://", with: "")
            .replace("file://", with: "")
            .replace("ftp://", with: "")

        guard preUrl != url else {
            return preUrl.extractBaseUrl()
        }
        if let canonicalUrl = Regex.pregMatchFirst(url, regex: Regex.cannonicalUrlPattern, index: 1),
            !canonicalUrl.isEmpty {
            return canonicalUrl.extractBaseUrl()
        }
        return url.extractBaseUrl()
    }

    /// Extract url redirection inside the GET query.
    /// Like https://www.dji.com/404?url=http%3A%2F%2Fwww.dji.com%2Fmatrice600-pro%2Finfo#specs -> http://www.dji.com/de/matrice600-pro/info#specs
    func extractRedirectionIfNeeded() -> URL {
        var url = self
        var absoluteString = url.absoluteString + "&id=12"

        if let range = absoluteString.range(of: "url="),
            let lastChar = absoluteString.last,
            let lastCharIndex = absoluteString.range(of: String(lastChar), options: .backwards, range: nil, locale: nil) {
            absoluteString = String(absoluteString[range.upperBound ..< lastCharIndex.upperBound])

            if let range = absoluteString.range(of: "&"),
                let firstChar = absoluteString.first,
                let firstCharIndex = absoluteString.firstIndex(of: firstChar) {
                absoluteString = String(absoluteString[firstCharIndex ..< absoluteString.index(before: range.upperBound)])

                if let decoded = absoluteString.removingPercentEncoding, let newURL = URL(string: decoded) {
                    url = newURL
                }
            }

        }

        return url
    }
}

fileprivate extension String {

    /// Extract base URL
    func extractBaseUrl() -> String {
        return String(split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)[0])
    }
}
