import SwiftUI
import AppKit

struct VimTextView: NSViewRepresentable {
    @Binding var text: String
    var onSave: () -> Void
    var onEscape: () -> Void

    @State private var vimEngine = VimEngine()

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.string = text

        context.coordinator.textView = textView
        context.coordinator.setupVimEngine()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            // Restore cursor position if valid
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: VimTextView
        weak var textView: NSTextView?
        var vimEngine: VimEngine?

        init(_ parent: VimTextView) {
            self.parent = parent
        }

        @MainActor
        func setupVimEngine() {
            vimEngine = VimEngine()
            vimEngine?.textView = textView
            vimEngine?.onSave = { [weak self] in
                self?.parent.onSave()
            }
            vimEngine?.onEscapeInNormalMode = { [weak self] in
                self?.saveAndExit()
            }
            vimEngine?.onContentChange = { [weak self] in
                guard let textView = self?.textView else { return }
                self?.parent.text = textView.string
            }
        }

        func saveAndExit() {
            guard let textView = textView else { return }
            parent.text = textView.string
            parent.onSave()
            parent.onEscape()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            return false
        }

        // Intercept key events for Vim
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // In insert mode, allow text changes
            if vimEngine?.mode == .insert {
                return true
            }
            // In normal mode, block direct text input
            return replacementString == nil || replacementString?.isEmpty == true
        }
    }
}

// MARK: - Vim-aware NSTextView

class VimNSTextView: NSTextView {
    var vimEngine: VimEngine?

    override func keyDown(with event: NSEvent) {
        if let engine = vimEngine, engine.handleKeyDown(event) {
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Better VimTextView with custom NSTextView

struct VimEditorView: NSViewRepresentable {
    @Binding var text: String
    let vimEngine: VimEngine
    var onSave: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = VimNSTextView()
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.string = text
        textView.delegate = context.coordinator
        textView.vimEngine = vimEngine

        vimEngine.textView = textView
        vimEngine.onSave = onSave
        vimEngine.onEscapeInNormalMode = {
            context.coordinator.saveAndExit()
        }

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        // Focus the text view
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? VimNSTextView else { return }

        if textView.string != text && vimEngine.mode != .insert {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: VimEditorView

        init(_ parent: VimEditorView) {
            self.parent = parent
        }

        func saveAndExit() {
            parent.onSave()
            parent.onEscape()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
