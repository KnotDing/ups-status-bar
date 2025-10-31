import SwiftUI

struct NotificationSettingsView: View {
    var onDismiss: () -> Void

    // MARK: - State Variables
    @State private var launchAtLoginEnabled: Bool = false
    @State private var notifyOnStatusChange: Bool = false
    @State private var notifyOnLowBattery: Bool = false
    @State private var lowBatteryThreshold: String = "20"
    @State private var notifyOnFullyCharged: Bool = false
    @State private var notifyOnHighLoad: Bool = false
    @State private var highLoadThreshold: String = "90"
    @State private var autoShutdownEnabled: Bool = false
    @State private var shutdownConditionIndex: Int = 0
    @State private var shutdownValue: String = "10"

    @State private var saveMessage: String = ""

    private let shutdownConditions = ["电源断开后", "电量剩余", "剩余时间"]
    private var shutdownUnit: String {
        switch shutdownConditionIndex {
        case 0: return "分钟后"
        case 1: return "%"
        case 2: return "分钟"
        default: return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(.title2)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // General Settings
                    VStack(alignment: .leading) {
                        Text("通用").font(.headline)
                        Toggle("开机启动", isOn: $launchAtLoginEnabled)
                            .onChange(of: launchAtLoginEnabled) { newValue in
                                LaunchAtLogin.setEnabled(newValue)
                            }
                    }

                    Divider()

                    // Notification Settings
                    VStack(alignment: .leading) {
                        Text("通知").font(.headline)
                        Toggle("UPS 状态变化时通知", isOn: $notifyOnStatusChange)
                        Toggle("电量充满时通知", isOn: $notifyOnFullyCharged)
                        HStack {
                            Toggle("电量低于设定值时通知", isOn: $notifyOnLowBattery)
                            Spacer()
                            TextField("", text: $lowBatteryThreshold).frame(width: 40)
                                .multilineTextAlignment(.trailing).textFieldStyle(
                                    RoundedBorderTextFieldStyle())
                            Text("%")
                        }
                        HStack {
                            Toggle("负载高于设定值时通知", isOn: $notifyOnHighLoad)
                            Spacer()
                            TextField("", text: $highLoadThreshold).frame(width: 40)
                                .multilineTextAlignment(
                                    .trailing
                                ).textFieldStyle(RoundedBorderTextFieldStyle())
                            Text("%")
                        }
                    }

                    Divider()

                    // Auto Shutdown Settings
                    VStack(alignment: .leading) {
                        Text("自动关机").font(.headline)
                        Toggle("启用自动关机", isOn: $autoShutdownEnabled)
                        HStack {
                            Picker("关机条件", selection: $shutdownConditionIndex) {
                                ForEach(0..<shutdownConditions.count, id: \.self) { index in
                                    Text(self.shutdownConditions[index])
                                }
                            }
                            .disabled(!autoShutdownEnabled)

                            TextField("值", text: $shutdownValue)
                                .frame(width: 50)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(!autoShutdownEnabled)
                            Text(shutdownUnit)
                        }
                        Text("警告：这是一个危险操作，它会触发系统关机。请谨慎使用。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if !saveMessage.isEmpty {
                Text(saveMessage).foregroundColor(.green)
            }

            HStack {
                Button("退出应用") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)

                Spacer()
                Button("关闭") { onDismiss() }
                Button("保存设置") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .onAppear(perform: loadConfig)
    }

    private func loadConfig() {
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        notifyOnStatusChange = UserDefaults.standard.bool(forKey: "notifyOnStatusChange")
        notifyOnLowBattery = UserDefaults.standard.bool(forKey: "notifyOnLowBattery")
        lowBatteryThreshold = UserDefaults.standard.string(forKey: "lowBatteryThreshold") ?? "20"
        notifyOnFullyCharged = UserDefaults.standard.bool(forKey: "notifyOnFullyCharged")
        notifyOnHighLoad = UserDefaults.standard.bool(forKey: "notifyOnHighLoad")
        highLoadThreshold = UserDefaults.standard.string(forKey: "highLoadThreshold") ?? "90"
        autoShutdownEnabled = UserDefaults.standard.bool(forKey: "autoShutdownEnabled")
        shutdownConditionIndex = UserDefaults.standard.integer(forKey: "shutdownConditionIndex")
        shutdownValue = UserDefaults.standard.string(forKey: "shutdownValue") ?? "10"
        saveMessage = ""
    }

    private func saveSettings() {
        UserDefaults.standard.set(notifyOnStatusChange, forKey: "notifyOnStatusChange")
        UserDefaults.standard.set(notifyOnLowBattery, forKey: "notifyOnLowBattery")
        UserDefaults.standard.set(lowBatteryThreshold, forKey: "lowBatteryThreshold")
        UserDefaults.standard.set(notifyOnFullyCharged, forKey: "notifyOnFullyCharged")
        UserDefaults.standard.set(notifyOnHighLoad, forKey: "notifyOnHighLoad")
        UserDefaults.standard.set(highLoadThreshold, forKey: "highLoadThreshold")
        UserDefaults.standard.set(autoShutdownEnabled, forKey: "autoShutdownEnabled")
        UserDefaults.standard.set(shutdownConditionIndex, forKey: "shutdownConditionIndex")
        UserDefaults.standard.set(shutdownValue, forKey: "shutdownValue")

        saveMessage = "设置已保存"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onDismiss()
        }
    }
}
