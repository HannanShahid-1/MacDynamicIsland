import SwiftUI

struct NBAScoresSettingView: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "basketball.fill")
                .font(.system(size: 17, weight: .bold))
                .frame(width: 42, height: 42)
                .foregroundStyle(Color(red: 0.96, green: 0.42, blue: 0.18), Color.white.opacity(0.62))
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("NBA scores")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.86))
                Text(store.nbaOptionsStatusText)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $store.nbaScoresEnabled)
                .labelsHidden()
                .toggleStyle(GreenSwitchToggleStyle())
                .fixedSize()
                .help("Enable NBA scores")
        }
        .padding(16)
        .frame(minHeight: 76)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }
}
