import SwiftUI

struct EditorView: View {
    @Binding var content: String
    @Binding var hasUnsavedChanges: Bool
    var filePath: String?
    var onSave: (() -> Void)?

    @StateObject private var vimEngine = VimEngine()
    @State private var fontSize: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            // WYSIWYG Markdown Editor
            MarkdownTextView(
                text: $content,
                vimEngine: vimEngine,
                fontSize: fontSize,
                onTextChange: {
                    hasUnsavedChanges = true
                }
            )

            // Status bar
            statusBar
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Font size controls
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
            vimEngine.onSave = onSave
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            // Vim mode indicator
            Text(vimEngine.mode.rawValue)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(modeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(modeColor.opacity(0.2))
                .cornerRadius(4)

            // Command buffer or status message
            if vimEngine.mode == .command {
                Text(vimEngine.commandBuffer)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
            } else if !vimEngine.statusMessage.isEmpty {
                Text(vimEngine.statusMessage)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Unsaved indicator
            if hasUnsavedChanges {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                    Text("Modified")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Editor type
            Text("WYSIWYG")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var modeColor: Color {
        switch vimEngine.mode {
        case .normal: return .blue
        case .insert: return .green
        case .visual, .visualLine: return .purple
        case .command: return .orange
        case .operatorPending: return .yellow
        }
    }
}

#Preview {
    EditorView(
        content: .constant("# Journal\n\n---\n\n## 2024-12-19 10:00:00\n\nTest entry with **bold** and *italic* text.\n\n- List item 1\n- List item 2\n\n`inline code`"),
        hasUnsavedChanges: .constant(false)
    )
}
