import SwiftUI

struct CompactIslandView: View {
    @ObservedObject var store: IslandStore
    @Environment(\.islandTextColor) private var islandTextColor
    @State private var chargingFillFraction: CGFloat = 0
    @State private var systemControlLevel: CGFloat = 0

    private var showsChargingPulse: Bool {
        !store.isDragTargeted && !showsSystemControlFeedback && store.chargingBannerID != nil
    }

    private var showsAirPodsIcon: Bool {
        !store.isDragTargeted && !showsSystemControlFeedback && !showsChargingPulse && store.airPodsBannerName != nil
    }

    private var showsSystemControlFeedback: Bool {
        !store.isDragTargeted && store.systemControlFeedback != nil
    }

    var body: some View {
        Group {
            if store.isDragTargeted {
                dragTargetContent
            } else {
                ZStack {
                    normalCompactContent
                        .opacity(showsChargingPulse || showsAirPodsIcon || showsSystemControlFeedback ? 0 : 1)

                    // Each banner's two ends pop out as the surface widens to show
                    // them, and are gone before it has finished narrowing again.
                    airPodsCompactContent
                        .islandMaterialize(showsAirPodsIcon, hiddenScale: 0.7, hiddenBlur: 4, anchor: .center)
                        .animation(bannerAnimation(showsAirPodsIcon), value: showsAirPodsIcon)

                    chargingCompactContent
                        .islandMaterialize(showsChargingPulse, hiddenScale: 0.7, hiddenBlur: 4, anchor: .center)
                        .animation(bannerAnimation(showsChargingPulse), value: showsChargingPulse)

                    systemControlCompactContent
                        .islandMaterialize(showsSystemControlFeedback, hiddenScale: 0.7, hiddenBlur: 4, anchor: .center)
                        .animation(bannerAnimation(showsSystemControlFeedback), value: showsSystemControlFeedback)
                }
            }
        }
        .foregroundStyle(islandTextColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: store.chargingBannerID) { _ in
            handleChargingBannerChange()
        }
        .onChange(of: store.systemControlFeedback) { _ in
            handleSystemControlFeedbackChange()
        }
        .onAppear {
            handleChargingBannerChange()
            handleSystemControlFeedbackChange()
        }
    }

    private func bannerAnimation(_ isShowing: Bool) -> Animation {
        isShowing ? IslandMotion.pop.delay(0.06) : IslandMotion.contentOut
    }

    private var dragTargetContent: some View {
        HStack(spacing: 0) {
            VStack(spacing: 5) {
                Image(systemName: store.isClipboardPaused ? "pause.circle.fill" : "doc.on.clipboard.fill")
                    .font(.system(size: 21, weight: .semibold))

                Text("Clipboard")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                Text("\(store.clipboardEntries.count)/5")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(islandTextColor.opacity(0.48))
                    .lineLimit(1)
            }
            .frame(width: 96)
            .frame(maxHeight: .infinity)

            Rectangle()
                .fill(islandTextColor.opacity(0.11))
                .frame(width: 1)
                .padding(.vertical, 10)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(islandTextColor.opacity(0.075))
                        .frame(width: 40, height: 40)

                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 22, weight: .semibold))
                }
                .frame(width: 52, height: 64)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Drop anywhere")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(1)

                    Text("Files land in the shelf")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(islandTextColor.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                MiniIslandSignal(systemName: "doc", count: store.files.count)
            }
            .padding(.leading, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var normalCompactContent: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var airPodsCompactContent: some View {
        HStack(spacing: 0) {
            Image(systemName: "airpodspro")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 35, height: 20, alignment: .leading)

            Spacer(minLength: IslandMetrics.notchCoreWidth)

            Color.clear
                .frame(width: 35, height: 20)
        }
    }

    private var chargingCompactContent: some View {
        let green = Color(red: 0.300, green: 1.000, blue: 0.420)
        let targetWidth = max(3, chargingFillFraction * 54)

        return HStack(spacing: 0) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.90),
                            green,
                            Color(red: 0.080, green: 0.850, blue: 0.290)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: green.opacity(0.72), radius: 5, x: 0, y: 0)
                .shadow(color: green.opacity(0.26), radius: 10, x: 0, y: 0)
                .frame(width: 46, height: 20, alignment: .leading)
                .offset(y: -2)

            Spacer(minLength: IslandMetrics.notchCoreWidth)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(green.opacity(0.14))
                    .frame(width: 54, height: 6)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                green.opacity(0.45),
                                green,
                                Color.white.opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: targetWidth, height: 6)
                    .shadow(color: green.opacity(0.58), radius: 6)
            }
            .frame(width: 54, height: 20, alignment: .leading)
        }
    }

    @ViewBuilder
    private var systemControlCompactContent: some View {
        if let feedback = store.systemControlFeedback {
            let tint = feedback.kind.tint
            let iconSize: CGFloat = feedback.kind == .brightness ? 11.5 : 13
            let barWidth: CGFloat = 64
            let targetWidth = max(3, systemControlLevel * barWidth)

            HStack(spacing: 0) {
                Image(systemName: feedback.kind.systemName(level: feedback.level))
                    .font(.system(size: iconSize, weight: .black))
                    .contentTransition(.opacity)
                    .animation(IslandMotion.contentOut, value: feedback.kind.systemName(level: feedback.level))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.94),
                            tint,
                            tint.opacity(0.70)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: tint.opacity(0.55), radius: 6, x: 0, y: 0)
                .frame(width: 46, height: 22, alignment: .leading)
                .offset(y: -1)

                Spacer(minLength: IslandMetrics.notchCoreWidth)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.14))
                        .frame(width: barWidth, height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.52),
                                    tint,
                                    Color.white.opacity(0.82)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: targetWidth, height: 6)
                        .shadow(color: tint.opacity(0.48), radius: 5)
                }
                .frame(width: barWidth, height: 22, alignment: .leading)
            }
        }
    }

    private func handleChargingBannerChange() {
        guard store.chargingBannerID != nil else {
            chargingFillFraction = 0
            return
        }

        chargingFillFraction = 0
        let targetPercent = store.chargingBatteryPercent ?? 100
        let targetFraction = CGFloat(min(max(targetPercent, 0), 100)) / 100

        withAnimation(.easeOut(duration: 0.95)) {
            chargingFillFraction = targetFraction
        }
    }

    private func handleSystemControlFeedbackChange() {
        guard let feedback = store.systemControlFeedback else { return }

        withAnimation(IslandMotion.rearrange) {
            systemControlLevel = feedback.level
        }
    }
}

struct MiniIslandSignal: View {
    let systemName: String
    let count: Int
    @Environment(\.islandTextColor) private var islandTextColor

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(islandTextColor.opacity(0.86))
        .frame(minWidth: 35, minHeight: 20)
        .background(
            Capsule()
                .fill(Color.clear)
        )
    }
}
