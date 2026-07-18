import SwiftUI

#if os(macOS)
import AppKit
public typealias UniversalImage = NSImage
#else
import UIKit
public typealias UniversalImage = UIImage
#endif

public extension Image {
    /// Injects platform-agnostic support into the standard SwiftUI Image hierarchy
    init(universalImage: UniversalImage) {
        #if os(macOS)
        self.init(nsImage: universalImage)
        #else
        self.init(uiImage: universalImage)
        #endif
    }
}
