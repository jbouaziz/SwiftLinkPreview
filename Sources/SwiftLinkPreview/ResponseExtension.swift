//
//  ResponseExtension.swift
//  SwiftLinkPreview
//
//  Created by Giuseppe Travasoni on 20/11/2018.
//  Copyright © 2018 leocardz.com. All rights reserved.
//

import Foundation

internal extension Response {
    
    var dictionary: [String: Any] {
        var responseData:[String: Any] = [:]
        responseData["url"] = url
        responseData["finalUrl"] = finalUrl
        responseData["canonicalUrl"] = canonicalUrl
        responseData["title"] = title
        responseData["description"] = description
        responseData["images"] = images
        responseData["image"] = image
        responseData["icon"] = icon
        responseData["video"] = video
        responseData["price"] = price
        return responseData
    }
    
    enum Key: String {
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
    
    mutating func set(_ value: Any, for key: Key) {
        switch key {
        case .url, .finalUrl, .canonicalUrl:
            // Those are not updatable
            break
        case .title:
            if let value = value as? String { self.title = value }
        case .description:
            if let value = value as? String { self.description = value }
        case .image:
            if let value = value as? String { self.image = value }
        case .images:
            if let value = value as? [String] { self.images = value }
        case .icon:
            if let value = value as? String { self.icon = value }
        case .video:
            if let value = value as? String { self.video = value }
        case .price:
            if let value = value as? String { self.price = value }
        }
    }
    
    func value(for key: Key) -> Any? {
        switch key {
        case .url:
            return self.url
        case .finalUrl:
            return self.finalUrl
        case .canonicalUrl:
            return self.canonicalUrl
        case .title:
            return self.title
        case .description:
            return self.description
        case .image:
            return self.image
        case .images:
            return self.images
        case .icon:
            return self.icon
        case .video:
            return self.video
        case .price:
            return self.price
        }
    }
}
