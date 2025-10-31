import SwiftUI

struct UPSPreviewPopoverView: View {
    @Binding var preview: [String: Any]

    // Computed property to get sorted keys
    private var sortedKeys: [String] {
        preview.keys.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            if preview.isEmpty {
                Text(LocalizedStringKey("没有可用的预览数据。"))
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(sortedKeys, id: \.self) { key in
                            HStack(alignment: .top) {
                                Text("\(key):")
                                    .frame(width: 180, alignment: .leading)
                                    .foregroundColor(.secondary)
                                Text(String(describing: preview[key]!))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.secondary)
                            }
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
    }
}
