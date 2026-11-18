import AppKit
import SwiftUI

struct HomeWidgetLayoutEditor: View {
    @ObservedObject var store: IslandStore
    @Namespace private var widgetNamespace
    @State private var draggingWidget: HomeWidget?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            orderedWidgetStrip
            widgetToggleRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var orderedWidgetStrip: some View {
        HStack(spacing: 8) {
            ForEach(store.visibleHomeWidgets) { widget in
                HomeWidgetDragTile(
                    widget: widget,
                    isDragging: draggingWidget == widget,
                    canRemove: store.canRemoveHomeWidget(widget)
                ) {
                    withAnimation(IslandMotion.rearrange) {
                        store.toggleHomeWidget(widget)
                    }
                }
                .matchedGeometryEffect(id: widget.id, in: widgetNamespace)
                .onDrag {
                    draggingWidget = widget
                    return NSItemProvider(object: widget.rawValue as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: HomeWidgetDropDelegate(
                        targetWidget: widget,
                        store: store,
                        draggingWidget: $draggingWidget
                    )
                )
                .transition(.islandPop(scale: 0.8))
            }
        }
        .padding(8)
        .frame(width: 504, height: 82, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .animation(IslandMotion.rearrange, value: store.visibleHomeWidgets)
    }

    private var widgetToggleRow: some View {
        HStack(spacing: 8) {
            ForEach(HomeWidget.optionOrder) { widget in
                HomeWidgetToggleChip(
                    widget: widget,
                    isSelected: store.isHomeWidgetSelected(widget),
                    canRemove: store.canRemoveHomeWidget(widget)
                ) {
                    withAnimation(IslandMotion.rearrange) {
                        store.toggleHomeWidget(widget)
                    }
                }
            }
        }
    }
}

struct HomeWidgetDragTile: View {
    let widget: HomeWidget
    let isDragging: Bool
    let canRemove: Bool
    let removeAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 7) {
                Image(systemName: widget.systemName)
                    .font(.system(size: 20, weight: .heavy))
                    .frame(height: 24)
                    .foregroundStyle(tileIconColor)

                Text(widget.shortTitle)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if canRemove {
                Button(action: removeAction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .black))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.black.opacity(0.28)))
                }
                .buttonStyle(IslandButtonPressStyle())
                .help("Hide \(widget.title)")
                .padding(7)
            }
        }
        .frame(width: tileWidth, height: 66)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isDragging ? 0.18 : 0.105))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(isDragging ? 0.34 : 0.12), lineWidth: 1)
        )
        .scaleEffect(isDragging ? 0.96 : 1)
        .opacity(isDragging ? 0.72 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(IslandMotion.hover, value: isDragging)
    }

    private var tileIconColor: Color {
        switch widget {
        case .appleMusic:
            return Color(red: 1.00, green: 0.48, blue: 0.62).opacity(0.96)
        case .calendar:
            return Color(red: 0.25, green: 0.70, blue: 1.00).opacity(0.96)
        case .nbaScores:
            return Color(red: 0.96, green: 0.42, blue: 0.18).opacity(0.96)
        }
    }

    private var tileWidth: CGFloat {
        switch widget {
        case .appleMusic:
            return 154
        case .calendar:
            return 154
        case .nbaScores:
            return 118
        }
    }
}

struct HomeWidgetToggleChip: View {
    let widget: HomeWidget
    let isSelected: Bool
    let canRemove: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(widget.shortTitle)
                    .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.white.opacity(isSelected ? 0.92 : (isHovered ? 0.76 : 0.54)))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(Color.white.opacity(isSelected ? 0.105 : (isHovered ? 0.075 : 0.045)))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isSelected ? 0.18 : (isHovered ? 0.12 : 0.07)), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.04 : 1)
        }
        .buttonStyle(IslandButtonPressStyle())
        .disabled(isSelected && !canRemove)
        .opacity(isSelected && !canRemove ? 0.62 : 1)
        .help(helpText)
        .onHover { hovering in
            withAnimation(IslandMotion.hover) {
                isHovered = hovering
            }
        }
    }

    private var helpText: String {
        if isSelected && !canRemove {
            return "At least one first-UI widget is required"
        }

        return isSelected ? "Hide \(widget.title)" : "Show \(widget.title)"
    }
}

struct HomeWidgetDropDelegate: DropDelegate {
    let targetWidget: HomeWidget
    let store: IslandStore
    @Binding var draggingWidget: HomeWidget?

    func dropEntered(info: DropInfo) {
        guard let draggingWidget, draggingWidget != targetWidget else { return }

        withAnimation(IslandMotion.rearrange) {
            store.moveHomeWidget(draggingWidget, around: targetWidget)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingWidget = nil
        return true
    }
}
