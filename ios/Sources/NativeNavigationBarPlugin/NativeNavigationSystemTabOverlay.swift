/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Derived from @capgo/capacitor-native-navigation
 * (https://github.com/Cap-go/capacitor-native-navigation), Copyright (c) Capgo.
 * See NOTICE for details.
 *
 * iOS 26+ system Liquid Glass tab bar hosting. The system tab bar needs a real
 * `UITabBarController`, but the Capacitor WKWebView must never become that
 * controller's child: UIKit would then own the WebView's frame and safe area
 * and report the tab bar's own inset through `env(safe-area-inset-bottom)`.
 * Instead the controller is layered over the WebView inside a passthrough host
 * view, so the WebView keeps the device safe area it has without this plugin. */

import UIKit

/// The frame `systemTabRootContainer` should get on a layout pass, given its
/// current origin (relative to its superview) and that superview's bounds.
///
/// `layoutChrome()` cannot use `rootView.bounds` for this: once the container
/// has replaced `bridge.viewController.view`, `rootView` in that function IS
/// the container, so its `.bounds` always starts at `(0, 0)` regardless of
/// where the container actually sits in its own superview. A host app that
/// pushes the WebView below the status bar (e.g. `@capacitor/status-bar`'s
/// `overlaysWebView: false`) gives the container a non-zero origin before
/// this plugin ever runs; assigning `rootView.bounds` straight to
/// `container.frame` snaps that origin back to `(0, 0)` without growing the
/// height to compensate, leaving a status-bar-height gap permanently exposed
/// at the screen's bottom edge (the superview's raw background shows
/// through it). Keeping the existing origin and only extending width/height
/// out to the superview's true edges avoids that regression on every layout
/// pass (rotation, keyboard events, tab updates all trigger one).
func nativeNavigationSystemTabContainerFrame(
    currentOrigin: CGPoint,
    superviewBounds: CGRect
) -> CGRect {
    CGRect(
        x: currentOrigin.x,
        y: currentOrigin.y,
        width: superviewBounds.width - currentOrigin.x,
        height: superviewBounds.height - currentOrigin.y
    )
}

/// True when `hit` belongs to `tabBar` and should receive the touch.
func nativeNavigationSystemTabPassthroughAllowsHit(_ hit: UIView?, tabBar: UITabBar?) -> Bool {
    guard let hit, let tabBar else {
        return false
    }
    return hit === tabBar || hit.isDescendant(of: tabBar)
}

func nativeNavigationSystemTabAppearanceHasOpaqueBackground(_ appearance: UITabBarAppearance) -> Bool {
    if appearance.backgroundEffect != nil {
        return true
    }
    if let backgroundColor = appearance.backgroundColor,
       backgroundColor.cgColor.alpha > 0.001 {
        return true
    }
    if let shadowColor = appearance.shadowColor,
       shadowColor.cgColor.alpha > 0.001 {
        return true
    }
    return false
}

/// Clears the legacy background layers in place so the platform's own Liquid
/// Glass surface is the only thing drawn behind the system tab bar.
func nativeNavigationMakeSystemTabAppearanceTransparent(_ appearance: UITabBarAppearance) {
    appearance.backgroundEffect = nil
    appearance.backgroundColor = .clear
    appearance.shadowColor = .clear
}

func nativeNavigationSystemTabTransparentStandardAppearance(
    from source: UITabBarAppearance
) -> UITabBarAppearance {
    let appearance = source.copy()
    nativeNavigationMakeSystemTabAppearanceTransparent(appearance)
    return appearance
}

/// Full-bleed host for the system `UITabBarController`'s view. Every touch
/// outside the tab bar itself falls through to the WebView underneath.
final class NativeNavigationSystemTabHostView: UIView {
    weak var tabBar: UITabBar?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return nativeNavigationSystemTabPassthroughAllowsHit(hit, tabBar: tabBar) ? hit : nil
    }
}
