import SwiftUI

struct EditorView: View {
    @Binding var content: String
    @Binding var hasUnsavedChanges: Bool

    @State private var fontSize: CGFloat = 14
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            TextEditor(text: $content)
                .font(.system(size: fontSize, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding()
                .focused($isFocused)
                .onChange(of: content) { _, _ in
                    hasUnsavedChanges = true
                }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Spacer()

                Button {
                    fontSize = max(10, fontSize - 2)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Decrease font size")

                Text("\(Int(fontSize))pt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)

                Button {
                    fontSize = min(24, fontSize + 2)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Increase font size")
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    EditorView(
        content: .constant("# Journal\n\n---\n\n## 2024-12-19 10:00:00\n\nTest entry content here."),
        hasUnsavedChanges: .constant(false)
    )
}
