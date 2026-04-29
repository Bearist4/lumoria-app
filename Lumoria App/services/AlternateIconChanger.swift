//
//  AlternateIconChanger.swift
//  Lumoria App
//
//  Helper that switches the alternate app icon WITHOUT the system
//  "You have changed the icon for…" alert.
//
//  iOS 10.3+ doesn't expose a documented silent path for
//  setAlternateIconName(_:). Calling the private
//  `_setAlternateIconName:withResult:` selector achieves the same
//  underlying state change and skips the alert that the public wrapper
//  injects. Many shipping apps use this — App Review tolerates it but
//  it's still a private API, so we fall back to the public call if the
//  selector ever disappears.
//
//  Usage:
//      AlternateIconChanger.set(nil)              // back to primary
//      AlternateIconChanger.set("AppIcon-Dark")   // alternate
//

import UIKit

@MainActor
enum AlternateIconChanger {
    static func set(_ name: String?, completion: ((Error?) -> Void)? = nil) {
        let app = UIApplication.shared
        guard app.supportsAlternateIcons else { completion?(nil); return }
        guard app.alternateIconName != name else { completion?(nil); return }

        let selector = NSSelectorFromString("_setAlternateIconName:withResult:")
        if app.responds(to: selector),
           let method = class_getInstanceMethod(UIApplication.self, selector) {
            typealias SilentSetter = @convention(c) (
                NSObject, Selector, NSString?, @escaping (NSError?) -> Void
            ) -> Void
            let imp = method_getImplementation(method)
            let function = unsafeBitCast(imp, to: SilentSetter.self)
            function(app, selector, name as NSString?) { error in
                DispatchQueue.main.async { completion?(error) }
            }
            return
        }

        // Fallback: public API (will show the alert).
        Task { @MainActor in
            do {
                try await app.setAlternateIconName(name)
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
}
