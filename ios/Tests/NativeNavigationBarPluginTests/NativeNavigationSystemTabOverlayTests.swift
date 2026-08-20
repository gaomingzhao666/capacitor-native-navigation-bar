/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Derived from @capgo/capacitor-native-navigation
 * (https://github.com/Cap-go/capacitor-native-navigation), Copyright (c) Capgo.
 * See NOTICE for details. */

import UIKit
import WebKit
import XCTest
@testable import NativeNavigationBarPlugin

final class NativeNavigationSystemTabOverlayTests: XCTestCase {
    func testContainerFrameKeepsStatusBarPushedOriginAndReachesTheSuperviewBottomEdge() {
        // overlaysWebView: false pushes the WebView (and this container) down
        // by the status bar's height before this plugin ever runs.
        let frame = nativeNavigationSystemTabContainerFrame(
            currentOrigin: CGPoint(x: 0, y: 54),
            superviewBounds: CGRect(x: 0, y: 0, width: 402, height: 874)
        )

        XCTAssertEqual(frame.origin, CGPoint(x: 0, y: 54))
        XCTAssertEqual(frame.height, 820)
        // The container must reach the superview's true bottom edge — no gap
        // exposing the superview's raw background underneath the tab bar.
        XCTAssertEqual(frame.maxY, 874)
        XCTAssertEqual(frame.width, 402)
    }

    func testContainerFrameIsIdempotentAcrossRepeatedLayoutPasses() {
        // layoutChrome() runs on every rotation, keyboard event, and tab
        // update. Feeding each result's own origin back in (as the real
        // call site does via `container.frame.origin`) must not let the
        // origin — and therefore the exposed gap — drift across calls.
        let superviewBounds = CGRect(x: 0, y: 0, width: 402, height: 874)
        var frame = nativeNavigationSystemTabContainerFrame(
            currentOrigin: CGPoint(x: 0, y: 54),
            superviewBounds: superviewBounds
        )

        for _ in 0..<5 {
            frame = nativeNavigationSystemTabContainerFrame(
                currentOrigin: frame.origin,
                superviewBounds: superviewBounds
            )
        }

        XCTAssertEqual(frame.origin, CGPoint(x: 0, y: 54))
        XCTAssertEqual(frame.maxY, 874)
    }

    func testContainerFrameFillsTheSuperviewWhenAlreadyFullBleed() {
        // overlaysWebView: true (or no StatusBar customization at all) keeps
        // the container at the superview's origin — this must stay a no-op.
        let frame = nativeNavigationSystemTabContainerFrame(
            currentOrigin: .zero,
            superviewBounds: CGRect(x: 0, y: 0, width: 402, height: 874)
        )

        XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 402, height: 874))
    }

    func testSystemTabStandardAppearanceCanBecomeFullyTransparent() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        XCTAssertTrue(nativeNavigationSystemTabAppearanceHasOpaqueBackground(appearance))

        let transparentAppearance = nativeNavigationSystemTabTransparentStandardAppearance(
            from: appearance
        )

        XCTAssertFalse(nativeNavigationSystemTabAppearanceHasOpaqueBackground(transparentAppearance))
        XCTAssertNil(transparentAppearance.backgroundEffect)
        XCTAssertLessThanOrEqual(
            transparentAppearance.backgroundColor?.cgColor.alpha ?? 0,
            0.001
        )
        XCTAssertLessThanOrEqual(
            transparentAppearance.shadowColor?.cgColor.alpha ?? 0,
            0.001
        )
    }

    func testTransparentSystemTabAppearanceDoesNotMutateTheSourceAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        _ = nativeNavigationSystemTabTransparentStandardAppearance(from: appearance)

        XCTAssertTrue(nativeNavigationSystemTabAppearanceHasOpaqueBackground(appearance))
    }

    @MainActor
    func testPassthroughOnlyAcceptsTouchesInsideTheSystemTabBar() {
        let tabBar = UITabBar()
        let tabBarChild = UIView()
        tabBar.addSubview(tabBarChild)
        let unrelated = UIView()

        XCTAssertTrue(nativeNavigationSystemTabPassthroughAllowsHit(tabBar, tabBar: tabBar))
        XCTAssertTrue(nativeNavigationSystemTabPassthroughAllowsHit(tabBarChild, tabBar: tabBar))
        XCTAssertFalse(nativeNavigationSystemTabPassthroughAllowsHit(unrelated, tabBar: tabBar))
        XCTAssertFalse(nativeNavigationSystemTabPassthroughAllowsHit(nil, tabBar: tabBar))
        XCTAssertFalse(nativeNavigationSystemTabPassthroughAllowsHit(tabBar, tabBar: nil))
    }

    @MainActor
    func testHostViewLetsTouchesOutsideTheTabBarReachTheWebViewBelow() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let webView = WKWebView(frame: container.bounds)
        container.addSubview(webView)

        let tabController = NativeNavigationTabController()
        let contentController = NativeNavigationTabContentController()
        contentController.tabBarItem = UITabBarItem(title: "Home", image: nil, tag: 0)
        tabController.setViewControllers([contentController], animated: false)

        let hostView = NativeNavigationSystemTabHostView(frame: container.bounds)
        hostView.tabBar = tabController.tabBar
        tabController.view.frame = hostView.bounds
        hostView.addSubview(tabController.view)
        container.addSubview(hostView)
        container.setNeedsLayout()
        container.layoutIfNeeded()

        let contentPoint = CGPoint(x: container.bounds.midX, y: 120)
        XCTAssertNil(hostView.hitTest(contentPoint, with: nil))
        XCTAssertTrue(container.hitTest(contentPoint, with: nil)?.isDescendant(of: webView) ?? false)

        let tabBarPoint = tabController.tabBar.convert(
            CGPoint(x: tabController.tabBar.bounds.midX, y: tabController.tabBar.bounds.midY),
            to: hostView
        )
        XCTAssertNotNil(hostView.hitTest(tabBarPoint, with: nil))
    }

    @MainActor
    func testSystemTabHostingLeavesTheWebViewOutsideTheTabController() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let webView = WKWebView(frame: container.bounds)
        container.addSubview(webView)

        let tabController = NativeNavigationTabController()
        let contentController = NativeNavigationTabContentController()
        contentController.tabBarItem = UITabBarItem(title: "Home", image: nil, tag: 0)
        tabController.setViewControllers([contentController], animated: false)

        let hostView = NativeNavigationSystemTabHostView(frame: container.bounds)
        hostView.tabBar = tabController.tabBar
        hostView.addSubview(tabController.view)
        container.addSubview(hostView)
        container.setNeedsLayout()
        container.layoutIfNeeded()

        // The WebView must stay a sibling of the tab controller. Anything else
        // hands UIKit control of its frame and safe area.
        XCTAssertTrue(webView.superview === container)
        XCTAssertFalse(webView.isDescendant(of: tabController.view))
        XCTAssertFalse(contentController.view.subviews.contains(webView))
        XCTAssertEqual(webView.frame, container.bounds)
    }

    @MainActor
    func testSystemTabChromeStaysTransparentOverTheWebView() {
        let tabController = NativeNavigationTabController()
        let contentController = NativeNavigationTabContentController()
        tabController.setViewControllers([contentController], animated: false)
        _ = tabController.view
        _ = contentController.view

        XCTAssertEqual(tabController.view.backgroundColor, .clear)
        XCTAssertFalse(tabController.view.isOpaque)
        XCTAssertEqual(contentController.view.backgroundColor, .clear)
        XCTAssertFalse(contentController.view.isOpaque)
        XCTAssertFalse(contentController.view.isUserInteractionEnabled)
    }
}
