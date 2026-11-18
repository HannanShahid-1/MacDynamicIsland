import AppKit
import SwiftUI

/// The island's motion vocabulary. Every animation in the app comes from here so
/// the whole thing moves with one personality: quick to respond, soft to land,
/// with a little overshoot wherever something arrives.
///
/// Bounce lives in the damping fraction (1 = no overshoot, lower = bouncier).
/// With Reduce Motion on, every spring is critically damped: same timing, no bounce.
@MainActor
enum IslandMotion {
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private static func spring(response: Double, damping: Double) -> Animation {
        .spring(response: response, dampingFraction: reduceMotion ? 1 : damping, blendDuration: 0)
    }

    // MARK: Surface (the black shape itself)

    /// Notch to expanded island. Reaches full size in about 0.2s, overshoots ~5%, settles.
    static var open: Animation { spring(response: 0.44, damping: 0.68) }

    /// Expanded island back into the notch: faster than opening, with a soft landing.
    static var close: Animation { spring(response: 0.36, damping: 0.82) }

    /// One resting shape to another: tab to tab, a banner's ears, the box score dropping down.
    static var morph: Animation { spring(response: 0.42, damping: 0.70) }

    // MARK: Content

    /// Expanded content arriving once the surface has started to open.
    static var contentIn: Animation { spring(response: 0.40, damping: 0.74) }

    /// Anything leaving. Exits are short and never bounce: only arrivals get attention.
    static var contentOut: Animation { .easeOut(duration: 0.12) }

    /// A tab's content sliding in. Extra bounce because the distance is short.
    static var tabContent: Animation { spring(response: 0.44, damping: 0.64) }

    /// Small things popping into place: banner icons, badges, a swapped glyph.
    static var pop: Animation { spring(response: 0.34, damping: 0.58) }

    /// A selection indicator sliding between options.
    static var select: Animation { spring(response: 0.36, damping: 0.68) }

    /// Lists and grids rearranging.
    static var rearrange: Animation { spring(response: 0.38, damping: 0.74) }

    /// Text and artwork swapping for new values.
    static var crossfade: Animation { .easeInOut(duration: 0.22) }

    // MARK: Pointer feedback

    /// Hover in and out.
    static var hover: Animation { spring(response: 0.28, damping: 0.62) }

    /// Finger down: immediate.
    static var pressDown: Animation { spring(response: 0.16, damping: 0.90) }

    /// Finger up: springs back past its resting size.
    static var pressUp: Animation { spring(response: 0.32, damping: 0.50) }

    /// A switch's knob.
    static var toggle: Animation { spring(response: 0.30, damping: 0.62) }

    // MARK: Timing

    /// How long after the last change the surface may still be visibly moving.
    /// The window keeps its extra room until this has passed.
    static let settleTime: TimeInterval = 0.85

    /// How long ambient refreshes should stay out of the way of a surface animation.
    static let quietTime: TimeInterval = 0.60
}

/// Scale, fade and blur together: how content arrives and leaves.
struct IslandMaterialize: ViewModifier {
    let isVisible: Bool
    var hiddenScale: CGFloat = 0.90
    var hiddenBlur: CGFloat = 8
    var anchor: UnitPoint = .top

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : hiddenScale, anchor: anchor)
            .blur(radius: isVisible ? 0 : hiddenBlur)
    }
}

/// Horizontal nudge plus blur, used by transitions that need more than the built-ins.
struct IslandSlideBlur: ViewModifier {
    let offsetX: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .blur(radius: blur)
    }
}

extension AnyTransition {
    /// Content of a tab arriving from the side it lives on (`direction` +1 = from the
    /// right) while the previous tab's content sinks back and fades.
    @MainActor
    static func islandTab(direction: CGFloat) -> AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.94, anchor: .top))
                .combined(with: .modifier(
                    active: IslandSlideBlur(offsetX: direction * 44, blur: 6),
                    identity: IslandSlideBlur(offsetX: 0, blur: 0)
                )),
            removal: .opacity
                .combined(with: .scale(scale: 0.96, anchor: .top))
                .combined(with: .modifier(
                    active: IslandSlideBlur(offsetX: 0, blur: 6),
                    identity: IslandSlideBlur(offsetX: 0, blur: 0)
                ))
                .animation(IslandMotion.contentOut)
        )
    }

    /// Something small popping in and out from `anchor`.
    static func islandPop(scale: CGFloat = 0.6, anchor: UnitPoint = .center) -> AnyTransition {
        .opacity.combined(with: .scale(scale: scale, anchor: anchor))
    }
}

extension View {
    func islandMaterialize(
        _ isVisible: Bool,
        hiddenScale: CGFloat = 0.90,
        hiddenBlur: CGFloat = 8,
        anchor: UnitPoint = .top
    ) -> some View {
        modifier(IslandMaterialize(
            isVisible: isVisible,
            hiddenScale: hiddenScale,
            hiddenBlur: hiddenBlur,
            anchor: anchor
        ))
    }
}
