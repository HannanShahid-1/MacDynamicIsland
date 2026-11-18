import SwiftUI

struct WeatherLocationSettingView: View {
    @ObservedObject var store: IslandStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 17, weight: .bold))
                .frame(width: 42, height: 42)
                .foregroundStyle(Color.yellow.opacity(0.92), Color.white.opacity(0.62))
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("City or ZIP", text: $store.weatherLocationInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.black.opacity(0.24))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .onSubmit {
                            store.applyWeatherLocationFromInput()
                        }

                    OptionsInlineIconButton(
                        systemName: store.weatherStatus == .loading ? "arrow.clockwise" : "checkmark",
                        iconSize: 12,
                        baseOpacity: 0.10,
                        title: "Save weather city",
                        isEnabled: store.canApplyWeatherLocation
                    ) {
                        store.applyWeatherLocationFromInput()
                    }

                    OptionsInlineIconButton(
                        systemName: "xmark",
                        iconSize: 11,
                        baseOpacity: 0.07,
                        title: "Clear weather city",
                        isEnabled: !(store.weatherLocationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.weatherInfo == nil)
                    ) {
                        store.clearWeatherLocation()
                    }
                }

                Text(store.weatherOptionsStatusText)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(Color.white.opacity(0.48))
            }
        }
        .padding(16)
        .frame(minHeight: 86)
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
