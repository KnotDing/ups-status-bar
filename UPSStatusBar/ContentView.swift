import Foundation
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var monitor: UPSMonitor

    // UI State
    @State private var showingNutConfig: Bool = false
    @State private var showingSettings: Bool = false
    @State private var showingDetails: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showingDetails {
                // Detail View
                HStack {
                    Text("详情").font(.headline)
                    Spacer()
                    Button("返回") { showingDetails = false }.buttonStyle(BorderlessButtonStyle())
                }
                UPSPreviewPopoverView(preview: $monitor.upsInfo)

            } else if showingSettings {
                // Settings View
                NotificationSettingsView(onDismiss: { showingSettings = false })

            } else if showingNutConfig {
                // NUT Config View
                NutConfigView(onDismiss: { showingNutConfig = false })

            } else {
                // Summary View (Original Content)
                HStack {
                    Spacer()
                    Button(action: { showingNutConfig = true }) {
                        Text("配置 NUT")
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.leading, 4)
                }

                if monitor.upsInfo.isEmpty {
                    Text("未检测到 UPS")
                        .font(.headline)
                    Text("请确保 UPS 已连接并且 macOS 能识别它（例如通过 USB），或配置 NUT Server。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(getUPSDisplayName())
                        .font(.headline)

                    HStack {
                        Text("当前状态:")
                            .bold()
                            .frame(width: 90, alignment: .leading)
                        Text(monitor.upsInfo["NUTStatus"] as? String ?? "未知")
                    }

                    HStack {
                        Text("电池电量:")
                            .bold()
                            .frame(width: 90, alignment: .leading)
                        if let charge = monitor.upsInfo["NUTCharge"] as? Int {
                            Text("\(charge)%")
                        } else {
                            Text("-")
                        }
                    }

                    HStack {
                        Text("剩余时间:")
                            .bold()
                            .frame(width: 90, alignment: .leading)
                        if let timeInSeconds = monitor.upsInfo["NUTTimeRemaining"] as? Int {
                            Text(formatSecondsToHMS(timeInSeconds))
                        } else {
                            Text("-")
                        }
                    }

                    HStack {
                        Text("实时负载:")
                            .bold()
                            .frame(width: 90, alignment: .leading)
                        if let load = monitor.upsInfo["NUTLoadPercent"] as? Int {
                            let powerText: String = {
                                if let nominalPowerString = monitor.upsInfo["NUT.ups.power.nominal"]
                                    as? String,
                                    let nominalPower = Double(nominalPowerString)
                                {
                                    let powerInWatts = nominalPower * (Double(load) / 100.0) * 0.8
                                    return String(format: " (%.0fW)", powerInWatts)
                                }
                                return ""
                            }()
                            Text("\(load)%\(powerText)")
                        } else {
                            Text("-")
                        }
                    }

                    Spacer()

                    HStack {
                        // This invisible view pushes the buttons to align with the values above.
                        Color.clear.frame(width: 90)

                        Button("刷新") { monitor.refresh() }

                        Button("详情") { showingDetails = true }
                            .disabled(monitor.upsInfo.isEmpty)
                            .padding(.leading, 8)  // Add some space between buttons

                        Spacer()
                    }
                }
            }
        }
        .padding()
        .frame(
            width: showingDetails ? 450 : (showingSettings ? 450 : (showingNutConfig ? 450 : 250)),
            height: showingDetails ? 400 : (showingSettings ? 500 : (showingNutConfig ? 500 : 220)))
    }

    private func getUPSDisplayName() -> String {
        if let customName = UserDefaults.standard.string(forKey: "CustomUPSName"),
            !customName.isEmpty
        {
            return customName
        } else if let nutName = monitor.upsInfo["NUTName"] as? String {
            return nutName
        } else {
            return monitor.upsInfo[kIOPSNameKey as String] as? String ?? "UPS"
        }
    }

    private func formatSecondsToHMS(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d时%02d分%02d秒", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d分%02d秒", minutes, seconds)
        } else {
            return String(format: "%d秒", seconds)
        }
    }
}
