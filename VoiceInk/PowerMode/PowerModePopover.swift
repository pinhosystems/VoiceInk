import SwiftUI

struct PowerModePopover: View {
    @ObservedObject var powerModeManager = PowerModeManager.shared
    @State private var selectedConfig: PowerModeConfig?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Power Mode")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal)
                .padding(.top, 8)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            ScrollView {
                let enabledConfigs = powerModeManager.configurations
                VStack(alignment: .leading, spacing: 4) {
                    // Explicit "None" entry that lets the user clear an
                    // active Power Mode session. With Power Mode cleared
                    // the individual LLM + transcription model pickers in
                    // the AudioPlayer footer become available again.
                    PowerModeNoneRow(
                        isSelected: selectedConfig == nil,
                        action: {
                            powerModeManager.setActiveConfiguration(nil)
                            selectedConfig = nil
                            Task {
                                await PowerModeSessionManager.shared.endSession()
                            }
                        }
                    )

                    if enabledConfigs.isEmpty {
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: 16))
                            Text("No Power Modes Available")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 13))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(enabledConfigs) { config in
                            PowerModeRow(
                                config: config,
                                isSelected: selectedConfig?.id == config.id,
                                action: {
                                    powerModeManager.setActiveConfiguration(config)
                                    selectedConfig = config
                                    applySelectedConfiguration()
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(width: 180)
        .frame(maxHeight: 340)
        .padding(.vertical, 8)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .onAppear {
            selectedConfig = powerModeManager.activeConfiguration
        }
        .onChange(of: powerModeManager.activeConfiguration) { newValue in
            selectedConfig = newValue
        }
    }
    
    private func applySelectedConfiguration() {
        Task {
            if let config = selectedConfig {
                await PowerModeSessionManager.shared.beginSession(with: config)
            }
        }
    }
}

private struct PowerModeNoneRow: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "circle.slash")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 12))

                Text("None — clear Power Mode")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.system(size: 13))
                    .lineLimit(1)

                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.white.opacity(0.10) : Color.clear)
        )
    }
}

struct PowerModeRow: View {
    let config: PowerModeConfig
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(config.emoji)
                    .font(.system(size: 14))

                Text(config.name)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.system(size: 13))
                    .lineLimit(1)

                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
} 
