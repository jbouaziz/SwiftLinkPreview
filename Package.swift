//
//  Package.swift
//  SwiftLinkPreview
//
//  Created by Leonardo Cardoso on 04/07/2016.
//  Copyright © 2016 leocardz.com. All rights reserved.
//

// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "SwiftLinkPreview",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v10),
        .tvOS(.v10),
        .watchOS(.v3)
    ],
    products: [
        .library(name: "SwiftLinkPreview", targets: ["SwiftLinkPreview"]),
    ],
    targets: [
        .target(name: "SwiftLinkPreview"),
    ],
    swiftLanguageVersions: [.v5]
)
