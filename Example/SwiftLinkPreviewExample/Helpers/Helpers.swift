//
//  Helpers.swift
//  SwiftLinkPreviewExample
//
//  Created by Jonathan Bouaziz on 07/01/2020.
//  Copyright © 2020 leocardz.com. All rights reserved.
//

import UIKit
import SwiftLinkPreview
import ImageSlideshow

extension UIViewController {
    func debug_showAlert(title: String, message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

extension String {

    /// Returns an image source from a remote text url
    var imageSource: SDWebImageSource? {
        return SDWebImageSource(
            urlString: self,
            placeholder: UIImage(named: "Placeholder")
        )
    }
}

extension Response {

    /// Debug method to print
    func debugPrint() {
        print("url: ", url ?? "no url")
        print("finalUrl: ", finalUrl ?? "no finalUrl")
        print("canonicalUrl: ", canonicalUrl ?? "no canonicalUrl")
        print("title: ", title ?? "no title")
        print("images: ", images ?? "no images")
        print("image: ", image ?? "no image")
        print("video: ", video ?? "no video")
        print("icon: ", icon ?? "no icon")
        print("description: ", description ?? "no description")
    }
}
