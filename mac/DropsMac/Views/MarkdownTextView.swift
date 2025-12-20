import SwiftUI
import AppKit
import Combine

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var vimEngine: VimEngine
    var fontSize: CGFloat
    var startInInsertMode: Bool = false
    var onTextChange: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = true
        textView.usesFontPanel = false
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        textView.insertionPointColor = NSColor.systemGreen

        // Line wrapping
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        // Allow image drag & drop
        textView.registerForDraggedTypes([.fileURL, .png, .tiff])

        // Setup Vim
        context.coordinator.textView = textView
        vimEngine.textView = textView
        vimEngine.onContentChange = { [weak coordinator = context.coordinator] in
            coordinator?.syncTextToBinding()
        }

        // Initial render
        context.coordinator.applyMarkdownStyling()

        // Start in insert mode if requested
        if startInInsertMode {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                // Move cursor to end
                textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
            }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update text if changed externally
        let currentPlainText = context.coordinator.getPlainText()
        if currentPlainText != text {
            context.coordinator.setText(text)
            context.coordinator.applyMarkdownStyling()
        }

        // Update cursor style
        context.coordinator.updateCursorStyle(for: vimEngine.mode)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: NSTextView?
        private var blockCursorView: NSView?
        private var isUpdating = false
        private var keyMonitor: Any?

        init(_ parent: MarkdownTextView) {
            self.parent = parent
            super.init()

            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self,
                      let textView = self.textView,
                      textView.window?.firstResponder == textView else {
                    return event
                }

                let handled = self.parent.vimEngine.handleKeyDown(event)
                if handled {
                    self.updateCursorStyle(for: self.parent.vimEngine.mode)
                }

                return handled ? nil : event
            }
        }

        deinit {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func getPlainText() -> String {
            guard let textView = textView else { return "" }
            return extractPlainMarkdown(from: textView.attributedString())
        }

        func setText(_ text: String) {
            guard let textView = textView, !isUpdating else { return }
            isUpdating = true
            let selectedRange = textView.selectedRange()
            textView.string = text
            let newLocation = min(selectedRange.location, text.count)
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))
            isUpdating = false
        }

        func syncTextToBinding() {
            guard !isUpdating else { return }
            let plainText = getPlainText()
            if plainText != parent.text {
                parent.text = plainText
                parent.onTextChange?()
            }
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isUpdating else { return }
            applyMarkdownStyling()
            syncTextToBinding()
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Always allow programmatic changes (from Vim commands)
            // VimEngine handles blocking keyboard input in normal mode
            return true
        }

        // MARK: - Markdown Styling

        func applyMarkdownStyling() {
            guard let textView = textView else { return }
            isUpdating = true

            let text = textView.string
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            let selectedRange = textView.selectedRange()

            // Base attributes
            let baseFont = NSFont.systemFont(ofSize: parent.fontSize)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: NSColor.textColor
            ]

            textView.textStorage?.beginEditing()
            textView.textStorage?.setAttributes(baseAttributes, range: fullRange)

            // Apply styles
            applyHeaderStyles(to: textView.textStorage!, in: text)
            applyBoldStyles(to: textView.textStorage!, in: text)
            applyItalicStyles(to: textView.textStorage!, in: text)
            applyCodeStyles(to: textView.textStorage!, in: text)
            applyLinkStyles(to: textView.textStorage!, in: text)
            applyListStyles(to: textView.textStorage!, in: text)
            applyHorizontalRuleStyles(to: textView.textStorage!, in: text)
            applyImageStyles(to: textView.textStorage!, in: text, textView: textView)

            textView.textStorage?.endEditing()

            // Restore selection
            let newLocation = min(selectedRange.location, text.count)
            textView.setSelectedRange(NSRange(location: newLocation, length: selectedRange.length))

            isUpdating = false
        }

        private func applyHeaderStyles(to storage: NSTextStorage, in text: String) {
            let patterns: [(String, CGFloat, NSColor)] = [
                ("(?m)^# (.+)$", parent.fontSize * 2.0, NSColor.labelColor),
                ("(?m)^## (.+)$", parent.fontSize * 1.5, NSColor.secondaryLabelColor),
                ("(?m)^### (.+)$", parent.fontSize * 1.25, NSColor.secondaryLabelColor)
            ]

            for (pattern, size, color) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(location: 0, length: (text as NSString).length)

                regex.enumerateMatches(in: text, range: range) { match, _, _ in
                    guard let match = match else { return }
                    let headerRange = match.range(at: 1)
                    let fullRange = match.range

                    // Hide the # symbols
                    let prefixLength = fullRange.length - headerRange.length - 1
                    if prefixLength > 0 {
                        let prefixRange = NSRange(location: fullRange.location, length: prefixLength)
                        storage.addAttribute(.foregroundColor, value: NSColor.clear, range: prefixRange)
                        storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 1), range: prefixRange)
                    }

                    // Style the header text
                    storage.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: size), range: headerRange)
                    storage.addAttribute(.foregroundColor, value: color, range: headerRange)
                }
            }
        }

        private func applyBoldStyles(to storage: NSTextStorage, in text: String) {
            guard let regex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*") else { return }
            let range = NSRange(location: 0, length: (text as NSString).length)

            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let match = match else { return }
                let contentRange = match.range(at: 1)
                let fullRange = match.range

                // Hide **
                let startRange = NSRange(location: fullRange.location, length: 2)
                let endRange = NSRange(location: fullRange.location + fullRange.length - 2, length: 2)
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: startRange)
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: endRange)

                // Bold the content
                let currentFont = storage.attribute(.font, at: contentRange.location, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: parent.fontSize)
                let boldFont = NSFont.boldSystemFont(ofSize: currentFont.pointSize)
                storage.addAttribute(.font, value: boldFont, range: contentRange)
            }
        }

        private func applyItalicStyles(to storage: NSTextStorage, in text: String) {
            guard let regex = try? NSRegularExpression(pattern: "(?<!\\*)\\*([^*]+)\\*(?!\\*)") else { return }
            let range = NSRange(location: 0, length: (text as NSString).length)

            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let match = match else { return }
                let contentRange = match.range(at: 1)
                let fullRange = match.range

                // Hide *
                let startRange = NSRange(location: fullRange.location, length: 1)
                let endRange = NSRange(location: fullRange.location + fullRange.length - 1, length: 1)
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: startRange)
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: endRange)

                // Italic the content
                let currentFont = storage.attribute(.font, at: contentRange.location, effectiveRange: nil) as? NSFont ?? NSFont.systemFont(ofSize: parent.fontSize)
                if let italicFont = NSFont(descriptor: currentFont.fontDescriptor.withSymbolicTraits(.italic), size: currentFont.pointSize) {
                    storage.addAttribute(.font, value: italicFont, range: contentRange)
                }
            }
        }

        private func applyCodeStyles(to storage: NSTextStorage, in text: String) {
            // Inline code
            guard let regex = try? NSRegularExpression(pattern: "`([^`]+)`") else { return }
            let range = NSRange(location: 0, length: (text as NSString).length)

            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let match = match else { return }
                let contentRange = match.range(at: 1)
                let fullRange = match.range

                // Hide backticks
                let startRange = NSRange(location: fullRange.location, length: 1)
                let endRange = NSRange(location: fullRange.location + fullRange.length - 1, length: 1)
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: startRange)
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: endRange)

                // Style code
                let codeFont = NSFont.monospacedSystemFont(ofSize: parent.fontSize * 0.9, weight: .regular)
                storage.addAttribute(.font, value: codeFont, range: contentRange)
                storage.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: contentRange)
            }
        }

        private func applyLinkStyles(to storage: NSTextStorage, in text: String) {
            guard let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)") else { return }
            let range = NSRange(location: 0, length: (text as NSString).length)

            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let match = match else { return }
                let titleRange = match.range(at: 1)
                let urlRange = match.range(at: 2)
                let fullRange = match.range

                // Hide [, ](url)
                let startBracket = NSRange(location: fullRange.location, length: 1)
                let middlePart = NSRange(location: titleRange.location + titleRange.length, length: urlRange.length + 3)

                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: startBracket)
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 1), range: startBracket)
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: middlePart)
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 1), range: middlePart)

                // Style link text
                storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: titleRange)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: titleRange)

                let urlString = (text as NSString).substring(with: urlRange)
                if let url = URL(string: urlString) {
                    storage.addAttribute(.link, value: url, range: titleRange)
                }
            }
        }

        private func applyListStyles(to storage: NSTextStorage, in text: String) {
            // Unordered lists
            guard let ulRegex = try? NSRegularExpression(pattern: "(?m)^- (.+)$") else { return }
            let range = NSRange(location: 0, length: (text as NSString).length)

            ulRegex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let match = match else { return }
                let bulletRange = NSRange(location: match.range.location, length: 2)

                // Replace - with bullet
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: bulletRange)
            }

            // Checkboxes
            if let checkRegex = try? NSRegularExpression(pattern: "(?m)^- \\[([ xX])\\] (.+)$") {
                checkRegex.enumerateMatches(in: text, range: range) { match, _, _ in
                    guard let match = match else { return }
                    let checkRange = match.range(at: 1)
                    let checkChar = (text as NSString).substring(with: checkRange)

                    let prefixRange = NSRange(location: match.range.location, length: 6)
                    storage.addAttribute(.foregroundColor, value: NSColor.clear, range: prefixRange)

                    // Add checkbox symbol
                    let symbol = checkChar == " " ? "☐ " : "☑ "
                    // Note: For real checkbox replacement, would need more complex logic
                    storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: prefixRange)
                }
            }
        }

        private func applyHorizontalRuleStyles(to storage: NSTextStorage, in text: String) {
            guard let regex = try? NSRegularExpression(pattern: "(?m)^---+$") else { return }
            let range = NSRange(location: 0, length: (text as NSString).length)

            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let match = match else { return }
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                storage.addAttribute(.strikethroughColor, value: NSColor.separatorColor, range: match.range)
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: match.range)
            }
        }

        private func applyImageStyles(to storage: NSTextStorage, in text: String, textView: NSTextView) {
            guard let regex = try? NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\(([^)]+)\\)") else { return }
            let range = NSRange(location: 0, length: (text as NSString).length)

            regex.enumerateMatches(in: text, range: range) { match, _, _ in
                guard let match = match else { return }
                let pathRange = match.range(at: 2)
                let pathString = (text as NSString).substring(with: pathRange)

                // Try to load image
                var image: NSImage?

                if pathString.hasPrefix("http://") || pathString.hasPrefix("https://") {
                    // URL image - async load would be better
                    if let url = URL(string: pathString), let data = try? Data(contentsOf: url) {
                        image = NSImage(data: data)
                    }
                } else {
                    // Local file
                    let expandedPath = (pathString as NSString).expandingTildeInPath
                    image = NSImage(contentsOfFile: expandedPath)
                }

                if let image = image {
                    // Resize if too large
                    let maxWidth: CGFloat = 400
                    if image.size.width > maxWidth {
                        let ratio = maxWidth / image.size.width
                        image.size = NSSize(width: maxWidth, height: image.size.height * ratio)
                    }

                    let attachment = NSTextAttachment()
                    attachment.image = image

                    // Hide the markdown syntax
                    storage.addAttribute(.foregroundColor, value: NSColor.clear, range: match.range)
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: 1), range: match.range)

                    // Note: For proper image insertion, would need to replace range with attachment
                    // This is a simplified version that just hides the syntax
                }
            }
        }

        private func extractPlainMarkdown(from attributed: NSAttributedString) -> String {
            // For now, just return the plain string
            // In a full implementation, would reconstruct markdown from styled text
            return attributed.string
        }

        // MARK: - Cursor Style

        func updateCursorStyle(for mode: VimMode) {
            guard let textView = textView else { return }

            blockCursorView?.removeFromSuperview()
            blockCursorView = nil

            if mode == .normal || mode == .visual {
                let cursorRect = getCursorRect(textView: textView)
                let blockView = NSView(frame: cursorRect)
                blockView.wantsLayer = true
                blockView.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.7).cgColor
                textView.addSubview(blockView)
                blockCursorView = blockView
                textView.insertionPointColor = NSColor.clear
            } else {
                textView.insertionPointColor = NSColor.systemGreen
            }
        }

        private func getCursorRect(textView: NSTextView) -> NSRect {
            let location = textView.selectedRange().location
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                return .zero
            }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: location, length: 1), actualCharacterRange: nil)
            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            rect.origin.x += textView.textContainerInset.width
            rect.origin.y += textView.textContainerInset.height

            if rect.width < 8 {
                rect.size.width = 8
            }

            return rect
        }
    }
}
