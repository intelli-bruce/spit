import SwiftUI
import AppKit
import Combine

struct VimTextView: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var vimEngine: VimEngine
    var font: NSFont
    var onTextChange: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.string = text
        textView.font = font
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        textView.insertionPointColor = NSColor.systemGreen

        // Enable line wrapping
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        // Set up vim engine
        context.coordinator.textView = textView
        vimEngine.textView = textView

        // Subscribe to mode changes
        context.coordinator.setupModeObserver(vimEngine: vimEngine)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            // Restore selection if possible
            let newLocation = min(selectedRange.location, text.count)
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))
        }

        textView.font = font

        // Update cursor style based on mode
        context.coordinator.updateCursorStyle(for: vimEngine.mode)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: VimTextView
        weak var textView: NSTextView?
        private var modeCancellable: AnyCancellable?
        private var blockCursorView: NSView?

        init(_ parent: VimTextView) {
            self.parent = parent
            super.init()

            // Monitor for key events
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self,
                      let textView = self.textView,
                      textView.window?.firstResponder == textView else {
                    return event
                }

                var handled = false
                let vimEngine = self.parent.vimEngine

                // Use MainActor to call vim engine
                DispatchQueue.main.sync {
                    handled = vimEngine.handleKeyDown(event)
                    if handled {
                        self.updateCursorStyle(for: vimEngine.mode)
                    }
                }

                return handled ? nil : event
            }
        }

        @MainActor
        func setupModeObserver(vimEngine: VimEngine) {
            modeCancellable = vimEngine.$mode
                .receive(on: DispatchQueue.main)
                .sink { [weak self] mode in
                    self?.updateCursorStyle(for: mode)
                }
        }

        func updateCursorStyle(for mode: VimMode) {
            guard let textView = textView else { return }

            // Remove existing block cursor
            blockCursorView?.removeFromSuperview()
            blockCursorView = nil

            if mode == .normal || mode == .visual {
                // Create block cursor for normal/visual mode
                let cursorRect = getCursorRect(textView: textView)
                let blockView = NSView(frame: cursorRect)
                blockView.wantsLayer = true
                blockView.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.7).cgColor
                textView.addSubview(blockView)
                blockCursorView = blockView

                // Hide the default insertion point
                textView.insertionPointColor = NSColor.clear
            } else {
                // Show default insertion point for insert mode
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

            // Adjust for text container inset
            rect.origin.x += textView.textContainerInset.width
            rect.origin.y += textView.textContainerInset.height

            // Ensure minimum width for block cursor
            if rect.width < 8 {
                rect.size.width = 8
            }

            return rect
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onTextChange?()
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Only allow text changes in insert mode
            return parent.vimEngine.mode == .insert
        }
    }
}
