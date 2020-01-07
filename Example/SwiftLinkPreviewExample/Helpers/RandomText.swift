//
//  RandomText.swift
//  SwiftLinkPreviewExample
//
//  Created by Jonathan Bouaziz on 07/01/2020.
//  Copyright © 2020 leocardz.com. All rights reserved.
//

import Foundation

private let randomTexts: [String] = [
    "blinkist.com",
    "uber.com",
    "tw.yahoo.com",
    "https://www.linkedin.com/",
    "www.youtube.com",
    "www.google.com",
    "facebook.com",

    "https://leocardz.com/swift-link-preview-5a9860c7756f",
    "NASA! 🖖🏽 https://www.nasa.gov/",
    "https://www.theverge.com/2016/6/21/11996280/tesla-offer-solar-city-buy",
    "Shorten URL http://bit.ly/14SD1eR",
    "Tweet! https://twitter.com",

    "A Gallery https://www.nationalgallery.org.uk",
    "www.dji.com/matrice600-pro/info#specs",

    "A Brazilian website http://globo.com",
    "Another Brazilian website https://uol.com.br",
    "Some Vietnamese chars https://vnexpress.net/",
    "Japan!!! https://www3.nhk.or.jp/",
    "A Russian website >> https://habrahabr.ru",

    "Youtube?! It does! https://www.youtube.com/watch?v=cv2mjAgFTaI",
    "Also Vimeo https://vimeo.com/67992157",

    "Even with image itself https://lh6.googleusercontent.com/-aDALitrkRFw/UfQEmWPMQnI/AAAAAAAFOlQ/mDh1l4ej15k/w337-h697-no/db1969caa4ecb88ef727dbad05d5b5b3.jpg",
    "Well, it's a gif! https://goo.gl/jKCPgp"
]

struct LoremIpsum {

    /// Fetches a random text
    static func getRandomText() -> String {
        return randomTexts[Int(arc4random_uniform(UInt32(randomTexts.count)))]
    }
}
