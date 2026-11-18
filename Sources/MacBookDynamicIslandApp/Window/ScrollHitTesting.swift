import AppKit

@MainActor
enum ScrollHitTesting {
    /// True when `locationInWindow` is over a visible scroll view whose content is
    /// wider than its viewport, i.e. one that has something to scroll sideways.
    /// A row whose content already fits does not count.
    static func isOverHorizontallyScrollableContent(_ locationInWindow: CGPoint, in rootView: NSView) -> Bool {
        scrollViews(in: rootView).contains { scrollView in
            guard !scrollView.isHiddenOrHasHiddenAncestor,
                  let documentView = scrollView.documentView,
                  documentView.frame.width > scrollView.contentSize.width + 1 else {
                return false
            }

            return scrollView.convert(scrollView.bounds, to: nil).contains(locationInWindow)
        }
    }

    private static func scrollViews(in view: NSView) -> [NSScrollView] {
        var found: [NSScrollView] = []

        if let scrollView = view as? NSScrollView {
            found.append(scrollView)
        }

        for subview in view.subviews {
            found += scrollViews(in: subview)
        }

        return found
    }
}
