import SwiftUI

enum ViewMode {
    case editor
    case preview
    case split
}

enum EditorType {
    case neovim    // 실제 Neovim 임베드
    case builtin   // 기존 VimEngine (fallback)
}

struct EditorView: View {
    @Binding var content: String
    @Binding var hasUnsavedChanges: Bool
    var filePath: String?
    var onSave: (() -> Void)?

    // Editor type - 기본은 builtin, Neovim은 선택적으로 사용
    @State private var editorType: EditorType = .builtin
    @State private var nvimMode: String = "n"

    // Fallback vim engine
    @StateObject private var vimEngine = VimEngine()
    @State private var fontSize: CGFloat = 14
    @State private var viewMode: ViewMode = .editor

    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            switch viewMode {
            case .editor:
                editorPane
            case .preview:
                previewPane
            case .split:
                HSplitView {
                    editorPane
                    previewPane
                }
            }

            // Vim status bar
            statusBar
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // View mode toggle
                Picker("View", selection: $viewMode) {
                    Image(systemName: "doc.text").tag(ViewMode.editor)
                    Image(systemName: "rectangle.split.2x1").tag(ViewMode.split)
                    Image(systemName: "eye").tag(ViewMode.preview)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                .help("Toggle view mode (⌘1/2/3)")

                Spacer()

                // Editor type toggle
                Picker("Engine", selection: $editorType) {
                    Text("Neovim").tag(EditorType.neovim)
                    Text("Built-in").tag(EditorType.builtin)
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                .help("Vim engine")

                Spacer()

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
        .keyboardShortcut("1", modifiers: .command)
    }

    private func checkNeovimAvailable() {
        let paths = ["/opt/homebrew/bin/nvim", "/usr/local/bin/nvim", "/usr/bin/nvim"]
        let nvimExists = paths.contains { FileManager.default.fileExists(atPath: $0) }
        if !nvimExists {
            editorType = .builtin
        }
    }

    @ViewBuilder
    private var editorPane: some View {
        switch editorType {
        case .neovim:
            NeovimView(
                filePath: filePath,
                mode: $nvimMode,
                onSave: onSave
            )
        case .builtin:
            VimTextView(
                text: $content,
                vimEngine: vimEngine,
                font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                onTextChange: {
                    hasUnsavedChanges = true
                }
            )
        }
    }

    private var previewPane: some View {
        MarkdownPreviewView(markdown: content)
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            // Vim mode indicator
            Text(currentModeLabel)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(modeColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(modeColor.opacity(0.2))
                .cornerRadius(4)

            // Command buffer or status message (builtin only)
            if editorType == .builtin {
                if vimEngine.mode == .command {
                    Text(vimEngine.commandBuffer)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                } else if !vimEngine.statusMessage.isEmpty {
                    Text(vimEngine.statusMessage)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            // Editor engine indicator
            Text(editorType == .neovim ? "nvim" : "vim")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(3)

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

            // View mode indicator
            Text(viewModeLabel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var currentModeLabel: String {
        if editorType == .neovim {
            return nvimModeLabel
        } else {
            return vimEngine.mode.rawValue
        }
    }

    private var nvimModeLabel: String {
        switch nvimMode {
        case "n", "normal": return "NORMAL"
        case "i", "insert": return "INSERT"
        case "v", "visual": return "VISUAL"
        case "V": return "V-LINE"
        case "\u{16}": return "V-BLOCK"  // Ctrl+V
        case "c", "cmdline": return "COMMAND"
        case "R", "replace": return "REPLACE"
        case "t", "terminal": return "TERMINAL"
        default: return nvimMode.uppercased()
        }
    }

    private var modeColor: Color {
        if editorType == .neovim {
            switch nvimMode {
            case "n", "normal": return .blue
            case "i", "insert": return .green
            case "v", "visual", "V", "\u{16}": return .purple
            case "c", "cmdline": return .orange
            case "R", "replace": return .red
            default: return .gray
            }
        } else {
            switch vimEngine.mode {
            case .normal: return .blue
            case .insert: return .green
            case .visual: return .purple
            case .command: return .orange
            }
        }
    }

    private var viewModeLabel: String {
        switch viewMode {
        case .editor:
            return "Editor"
        case .preview:
            return "Preview"
        case .split:
            return "Split"
        }
    }
}

#Preview {
    EditorView(
        content: .constant("# Journal\n\n---\n\n## 2024-12-19 10:00:00\n\nTest entry content here."),
        hasUnsavedChanges: .constant(false)
    )
}
