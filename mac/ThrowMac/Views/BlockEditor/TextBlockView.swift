import SwiftUI
import AppKit

struct TextBlockView: NSViewRepresentable {
    @Bindable var block: NoteBlock
    let isFocused: Bool
    let onFocus: () -> Void
    let onCreateBlock: (String) -> Void
    let onDeleteBlock: () -> Void
    let onMergeWithPrevious: () -> Void
    let onNavigateUp: () -> Void
    let onNavigateDown: () -> Void
    let onContentChange: () -> Void
    let onEscape: () -> Void
    let onPasteImage: (Data) -> Void

    func makeNSView(context: Context) -> BlockTextView {
        let textView = BlockTextView()
        textView.delegate = context.coordinator
        textView.coordinator = context.coordinator
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 14)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = .textColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 4)

        textView.string = block.content ?? ""

        return textView
    }

    func updateNSView(_ nsView: BlockTextView, context: Context) {
        // Update content if changed externally
        if nsView.string != (block.content ?? "") && !context.coordinator.isEditing {
            nsView.string = block.content ?? ""
        }

        // Focus handling
        if isFocused && nsView.window?.firstResponder != nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TextBlockView
        var isEditing = false

        init(_ parent: TextBlockView) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
            parent.onFocus()
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.block.content = textView.string
            parent.onContentChange()
        }

        // Handle Enter key - create new block
        func handleEnter(in textView: NSTextView) {
            let cursorPosition = textView.selectedRange().location
            let text = textView.string

            // Split text at cursor position
            let beforeCursor = String(text.prefix(cursorPosition))
            let afterCursor = String(text.suffix(text.count - cursorPosition))

            // Update current block with text before cursor
            parent.block.content = beforeCursor
            textView.string = beforeCursor

            // Create new block with text after cursor
            parent.onCreateBlock(afterCursor)
        }

        // Handle Backspace at start of block
        func handleBackspaceAtStart(in textView: NSTextView) {
            let text = textView.string

            if text.isEmpty {
                // Delete empty block
                parent.onDeleteBlock()
            } else {
                // Merge with previous block
                parent.onMergeWithPrevious()
            }
        }

        // Handle arrow up at first line
        func handleArrowUp(in textView: NSTextView) -> Bool {
            let cursorPosition = textView.selectedRange().location
            let text = textView.string

            // Check if cursor is on the first line
            let textBeforeCursor = String(text.prefix(cursorPosition))
            if !textBeforeCursor.contains("\n") {
                parent.onNavigateUp()
                return true
            }
            return false
        }

        // Handle arrow down at last line
        func handleArrowDown(in textView: NSTextView) -> Bool {
            let cursorPosition = textView.selectedRange().location
            let text = textView.string

            // Check if cursor is on the last line
            let textAfterCursor = String(text.suffix(text.count - cursorPosition))
            if !textAfterCursor.contains("\n") {
                parent.onNavigateDown()
                return true
            }
            return false
        }

        // Handle image paste
        func handlePasteImage(_ imageData: Data) {
            print("[Paste] handlePasteImage called with \(imageData.count) bytes")
            parent.onPasteImage(imageData)
        }
    }
}

// MARK: - Custom NSTextView for Block Editing

class BlockTextView: NSTextView {
    weak var coordinator: TextBlockView.Coordinator?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            print("[Paste] Cmd+V detected via performKeyEquivalent")
            paste(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        print("[Paste] Available types: \(pasteboard.types ?? [])")

        // Check for image data first
        if let imageData = pasteboard.data(forType: .png) {
            print("[Paste] Found PNG data: \(imageData.count) bytes")
            coordinator?.handlePasteImage(imageData)
            return
        }

        if let imageData = pasteboard.data(forType: .tiff) {
            print("[Paste] Found TIFF data: \(imageData.count) bytes")
            // Convert TIFF to PNG
            if let image = NSImage(data: imageData),
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                print("[Paste] Converted to PNG: \(pngData.count) bytes")
                coordinator?.handlePasteImage(pngData)
                return
            }
        }

        // Check for file URLs (images)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            print("[Paste] Found URLs: \(urls)")
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "gif", "webp", "heic"].contains(ext) {
                    if let imageData = try? Data(contentsOf: url) {
                        print("[Paste] Loaded image from URL: \(imageData.count) bytes")
                        coordinator?.handlePasteImage(imageData)
                        return
                    }
                }
            }
        }

        print("[Paste] No image found, falling back to text paste")
        // Default text paste
        super.paste(sender)
    }

    override func keyDown(with event: NSEvent) {
        guard let coordinator = coordinator else {
            super.keyDown(with: event)
            return
        }

        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ESC key - exit editing
        if keyCode == 53 {
            coordinator.parent.onEscape()
            return
        }

        // Enter key (without modifiers) - create new block
        if keyCode == 36 && modifiers.isEmpty {
            coordinator.handleEnter(in: self)
            return
        }

        // Shift+Enter - insert newline within block
        if keyCode == 36 && modifiers == .shift {
            super.keyDown(with: event)
            return
        }

        // Backspace at position 0
        if keyCode == 51 && selectedRange().location == 0 && selectedRange().length == 0 {
            coordinator.handleBackspaceAtStart(in: self)
            return
        }

        // Arrow Up
        if keyCode == 126 && modifiers.isEmpty {
            if coordinator.handleArrowUp(in: self) {
                return
            }
        }

        // Arrow Down
        if keyCode == 125 && modifiers.isEmpty {
            if coordinator.handleArrowDown(in: self) {
                return
            }
        }

        super.keyDown(with: event)
    }

    // Auto-resize based on content
    override var intrinsicContentSize: NSSize {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            return super.intrinsicContentSize
        }

        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)

        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: max(usedRect.height + textContainerInset.height * 2, 24)
        )
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }
}
