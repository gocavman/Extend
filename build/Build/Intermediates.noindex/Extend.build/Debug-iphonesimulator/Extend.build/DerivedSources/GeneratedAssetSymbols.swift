import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "Apple" asset catalog image resource.
    static let apple = DeveloperToolsSupport.ImageResource(name: "Apple", bundle: resourceBundle)

    /// The "Dumbbell" asset catalog image resource.
    static let dumbbell = DeveloperToolsSupport.ImageResource(name: "Dumbbell", bundle: resourceBundle)

    /// The "Kettlebell" asset catalog image resource.
    static let kettlebell = DeveloperToolsSupport.ImageResource(name: "Kettlebell", bundle: resourceBundle)

    /// The "Shaker" asset catalog image resource.
    static let shaker = DeveloperToolsSupport.ImageResource(name: "Shaker", bundle: resourceBundle)

    /// The "topview1" asset catalog image resource.
    static let topview1 = DeveloperToolsSupport.ImageResource(name: "topview1", bundle: resourceBundle)

    /// The "topview2" asset catalog image resource.
    static let topview2 = DeveloperToolsSupport.ImageResource(name: "topview2", bundle: resourceBundle)

    /// The "topview3" asset catalog image resource.
    static let topview3 = DeveloperToolsSupport.ImageResource(name: "topview3", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "Apple" asset catalog image.
    static var apple: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .apple)
#else
        .init()
#endif
    }

    /// The "Dumbbell" asset catalog image.
    static var dumbbell: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dumbbell)
#else
        .init()
#endif
    }

    /// The "Kettlebell" asset catalog image.
    static var kettlebell: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .kettlebell)
#else
        .init()
#endif
    }

    /// The "Shaker" asset catalog image.
    static var shaker: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .shaker)
#else
        .init()
#endif
    }

    /// The "topview1" asset catalog image.
    static var topview1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .topview1)
#else
        .init()
#endif
    }

    /// The "topview2" asset catalog image.
    static var topview2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .topview2)
#else
        .init()
#endif
    }

    /// The "topview3" asset catalog image.
    static var topview3: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .topview3)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "Apple" asset catalog image.
    static var apple: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .apple)
#else
        .init()
#endif
    }

    /// The "Dumbbell" asset catalog image.
    static var dumbbell: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .dumbbell)
#else
        .init()
#endif
    }

    /// The "Kettlebell" asset catalog image.
    static var kettlebell: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .kettlebell)
#else
        .init()
#endif
    }

    /// The "Shaker" asset catalog image.
    static var shaker: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .shaker)
#else
        .init()
#endif
    }

    /// The "topview1" asset catalog image.
    static var topview1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .topview1)
#else
        .init()
#endif
    }

    /// The "topview2" asset catalog image.
    static var topview2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .topview2)
#else
        .init()
#endif
    }

    /// The "topview3" asset catalog image.
    static var topview3: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .topview3)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

