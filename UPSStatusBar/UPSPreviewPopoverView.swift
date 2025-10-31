import SwiftUI

struct UPSPreviewPopoverView: View {
    @Binding var preview: [String: Any]

    // Computed property to get sorted keys
    private var sortedKeys: [String] {
        preview.keys.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Text("详情").font(.headline)
            //     .padding(.bottom, 5)

            if preview.isEmpty {
                Text("没有可用的预览数据。")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(sortedKeys, id: \.self) { key in
                            HStack(alignment: .top) {
                                Text("\(key):")
                                    .fontWeight(.bold)
                                    .frame(width: 180, alignment: .leading)
                                Text(String(describing: preview[key]!))
                                    .frame(maxWidth: .infinity, alignment: .leading)
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