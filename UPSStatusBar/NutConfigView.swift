import SwiftUI

struct NutConfigView: View {
    var onDismiss: () -> Void

    @EnvironmentObject var monitor: UPSMonitor

    // MARK: - State Variables
    @State private var host: String = ""
    @State private var portText: String = "3493"
    @State private var user: String = ""
    @State private var password: String = ""
    @State private var customUPSName: String = ""
    @State private var isTesting: Bool = false
    @State private var testMessage: String = ""
    @State private var discoveredUPS: [String] = []
    @State private var selectedUPS: String? = nil

    // State for displaying details of the selected UPS
    @State private var selectedUPSDetails: [String: Any] = [:]
    @State private var isFetchingDetails: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey("NUT Server 配置"))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                    HStack {
                        Text(LocalizedStringKey("主机：")).frame(width: 120, alignment: .leading)
                        TextField(LocalizedStringKey("例如 192.168.1.10"), text: $host)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    HStack {
                        Text(LocalizedStringKey("端口：")).frame(width: 120, alignment: .leading)
                        TextField(LocalizedStringKey("3493"), text: $portText).textFieldStyle(
                            RoundedBorderTextFieldStyle()
                        ).frame(width: 120)
                    }
                    HStack {
                        Text(LocalizedStringKey("用户名：")).frame(width: 120, alignment: .leading)
                        TextField(LocalizedStringKey("(可选)"), text: $user).textFieldStyle(
                            RoundedBorderTextFieldStyle())
                    }
                    HStack {
                        Text(LocalizedStringKey("密码：")).frame(width: 120, alignment: .leading)
                        SecureField(LocalizedStringKey("(可选)"), text: $password).textFieldStyle(
                            RoundedBorderTextFieldStyle())
                    }
                    HStack {
                        Text(LocalizedStringKey("自定义 UPS 名称：")).frame(
                            width: 120, alignment: .leading)
                        TextField(LocalizedStringKey("(可选)"), text: $customUPSName).textFieldStyle(
                            RoundedBorderTextFieldStyle())
                    }

                    HStack {

                        Button(action: testConnectionAndDiscoverUPS) {
                            Text(

                                isTesting
                                    ? LocalizedStringKey("测试中...") : LocalizedStringKey("测试并发现 UPS")
                            )
                        }.disabled(
                            host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || isTesting)
                        Spacer()
                        if !testMessage.isEmpty {
                            Text(testMessage)
                                .foregroundColor(
                                    testMessage.contains(NSLocalizedString("成功", comment: ""))
                                        || testMessage.contains(
                                            NSLocalizedString("已保存", comment: ""))
                                        ? .green : .red
                                )
                                .fixedSize(horizontal: false, vertical: true)
                            //.padding(.top, 5)
                        }
                    }

                    if !discoveredUPS.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey("在 NUT Server 上发现的 UPS："))
                            Picker("", selection: $selectedUPS) {
                                ForEach(discoveredUPS, id: \.self) { ups in
                                    Text(ups).tag(ups as String?)
                                }
                            }
                            .pickerStyle(RadioGroupPickerStyle())
                            .onChange(of: selectedUPS) { _ in fetchDetailsForSelectedUPS() }
                        }
                        .padding(.top)

                        // Details display area
                        if selectedUPS != nil {
                            //Divider()
                            VStack(alignment: .leading) {
                                Text(LocalizedStringKey("\(selectedUPS!) 的详情：")).font(.headline)
                                if isFetchingDetails {
                                    Text(LocalizedStringKey("加载中..."))
                                        .foregroundColor(.secondary)
                                } else if !selectedUPSDetails.isEmpty {
                                    // Reuse the preview view to show details
                                    UPSPreviewPopoverView(preview: .constant(selectedUPSDetails))
                                } else {
                                    Text(LocalizedStringKey("未能获取此UPS的详细信息。"))
                                        .foregroundColor(.secondary)
                                }
                            }.padding(.top, 5)
                        }
                    }
                }
            }

            HStack {
                Button(LocalizedStringKey("取消")) { onDismiss() }
                Spacer()

                Button(action: saveConfig) { Text(LocalizedStringKey("保存")) }.keyboardShortcut(
                    .defaultAction)
            }
        }
        .padding()
        .onAppear(perform: loadConfig)
    }

    private func loadConfig() {
        host = UserDefaults.standard.string(forKey: "NUTHost") ?? ""
        portText = UserDefaults.standard.string(forKey: "NUTPort") ?? "3493"
        user = UserDefaults.standard.string(forKey: "NUTUser") ?? ""
        password = UserDefaults.standard.string(forKey: "NUTPassword") ?? ""
        customUPSName = UserDefaults.standard.string(forKey: "CustomUPSName") ?? ""
        selectedUPS = UserDefaults.standard.string(forKey: "NUTSelectedUPS")
        testMessage = ""
        // If a UPS was already selected, fetch its details on appear
        if selectedUPS != nil {
            fetchDetailsForSelectedUPS()
        }
    }

    private func saveConfig() {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            testMessage = NSLocalizedString("请填写主机地址", comment: "")
            return
        }
        UserDefaults.standard.setValue(trimmedHost, forKey: "NUTHost")
        UserDefaults.standard.setValue(portText, forKey: "NUTPort")
        UserDefaults.standard.setValue(user, forKey: "NUTUser")
        UserDefaults.standard.setValue(password, forKey: "NUTPassword")
        UserDefaults.standard.setValue(customUPSName, forKey: "CustomUPSName")
        if let ups = selectedUPS {
            UserDefaults.standard.setValue(ups, forKey: "NUTSelectedUPS")
        } else {
            UserDefaults.standard.removeObject(forKey: "NUTSelectedUPS")
        }

        monitor.refresh()
        testMessage = NSLocalizedString("配置已保存", comment: "")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onDismiss() }
    }

    private func testConnectionAndDiscoverUPS() {
        testMessage = ""
        discoveredUPS = []
        isTesting = true
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = Int(portText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 3493

        monitor.discoverUPS(host: trimmedHost, port: port, user: user, password: password) {
            upsList in
            DispatchQueue.main.async {
                self.isTesting = false
                if !upsList.isEmpty {
                    self.discoveredUPS = upsList
                    if self.selectedUPS == nil || !upsList.contains(self.selectedUPS!) {
                        self.selectedUPS = upsList.first
                    }
                    self.testMessage = String(
                        format: NSLocalizedString("成功发现 %d 个 UPS。", comment: ""), upsList.count)
                } else {
                    self.testMessage = NSLocalizedString("连接成功，但未发现任何 UPS。", comment: "")
                }
            }
        }
    }

    private func fetchDetailsForSelectedUPS() {
        guard let upsName = selectedUPS else { return }

        isFetchingDetails = true
        selectedUPSDetails = [:]

        let hostTrim = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let portInt = Int(portText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 3493

        monitor.fetchVarsForUPS(
            upsName: upsName, host: hostTrim, port: portInt, user: user, password: password
        ) { result in
            DispatchQueue.main.async {
                isFetchingDetails = false
                switch result {
                case .success(let dict):
                    self.selectedUPSDetails = dict
                case .failure(let err):
                    print("Failed to fetch details for \(upsName): \(err.localizedDescription)")
                    self.selectedUPSDetails = [:]  // Clear details on failure
                }
            }
        }
    }
}
