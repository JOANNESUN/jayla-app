//
//  ImageProcessing.swift
//  Jayla
//
//  Cross-platform image helpers. The UIKit specifics are hidden inside
//  these functions so every call site (views, onboarding) stays platform-
//  agnostic and the whole target still type-checks on macOS.
//

import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PhotoProcessing {
    /// Decode `data`, downscale so its longest side ≤ `maxDimension`, and
    /// re-encode as JPEG. Returns nil if the data isn't a valid image.
    /// This is why we never store a 12 MP original — just a ~KB thumbnail.
    static func downscaledJPEG(from data: Data,
                               maxDimension: CGFloat = 1024,
                               quality: CGFloat = 0.8) -> Data? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        let maxSide = max(image.size.width, image.size.height)
        let target: UIImage
        if maxSide > maxDimension, maxSide > 0 {
            let scale = maxDimension / maxSide
            let newSize = CGSize(width: image.size.width * scale,
                                 height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            target = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            target = image
        }
        return target.jpegData(compressionQuality: quality)
        #else
        return data
        #endif
    }
}

extension Image {
    /// Build a SwiftUI Image from raw photo bytes; nil if decode fails.
    init?(photoData: Data) {
        #if canImport(UIKit)
        guard let ui = UIImage(data: photoData) else { return nil }
        self.init(uiImage: ui)
        #elseif canImport(AppKit)
        guard let ns = NSImage(data: photoData) else { return nil }
        self.init(nsImage: ns)
        #else
        return nil
        #endif
    }
}
