import Foundation
import AppKit

enum VimMode: String {
    case normal = "NORMAL"
    case insert = "INSERT"
    case visual = "VISUAL"
    case command = "COMMAND"
}

@MainActor
class VimEngine: ObservableObject {
    @Published var mode: VimMode = .normal
    @Published var commandBuffer: String = ""
    @Published var statusMessage: String = ""

    private var countBuffer: String = ""
    private var operatorPending: String? = nil
    private var lastSearch: String = ""
    private var registerContent: String = ""

    weak var textView: NSTextView?
    var onSave: (() -> Void)?

    // MARK: - Key Handling

    func handleKeyDown(_ event: NSEvent) -> Bool {
        let key = event.charactersIgnoringModifiers ?? ""
        let modifiers = event.modifierFlags

        switch mode {
        case .normal:
            return handleNormalMode(key: key, modifiers: modifiers, event: event)
        case .insert:
            return handleInsertMode(key: key, modifiers: modifiers, event: event)
        case .visual:
            return handleVisualMode(key: key, modifiers: modifiers, event: event)
        case .command:
            return handleCommandMode(key: key, modifiers: modifiers, event: event)
        }
    }

    // MARK: - Normal Mode

    private func handleNormalMode(key: String, modifiers: NSEvent.ModifierFlags, event: NSEvent) -> Bool {
        guard let textView = textView else { return false }

        // Handle Ctrl key combinations first
        if modifiers.contains(.control) {
            switch key {
            case "d":
                scrollHalfPageDown(textView)
                return true
            case "u":
                scrollHalfPageUp(textView)
                return true
            case "f":
                scrollPageDown(textView)
                return true
            case "b":
                scrollPageUp(textView)
                return true
            case "r":
                textView.undoManager?.redo()
                return true
            default:
                break
            }
        }

        // Handle pending operator combinations (gg, dd, yy, etc.)
        if let pending = operatorPending {
            switch (pending, key) {
            case ("g", "g"):
                moveToStart(textView)
                operatorPending = nil
                return true
            case ("d", "d"):
                let count = Int(countBuffer) ?? 1
                countBuffer = ""
                deleteLine(textView, count: count)
                operatorPending = nil
                return true
            case ("y", "y"):
                let count = Int(countBuffer) ?? 1
                countBuffer = ""
                yankLine(textView, count: count)
                operatorPending = nil
                return true
            case ("d", "w"):
                deleteWord(textView)
                operatorPending = nil
                return true
            case ("d", "$"):
                deleteToEndOfLine(textView)
                operatorPending = nil
                return true
            case ("c", "w"):
                deleteWord(textView)
                operatorPending = nil
                enterInsertMode()
                return true
            case ("c", "c"):
                let count = Int(countBuffer) ?? 1
                countBuffer = ""
                deleteLine(textView, count: count)
                operatorPending = nil
                enterInsertMode()
                return true
            default:
                operatorPending = nil
            }
        }

        // Count prefix
        if let digit = key.first, digit.isNumber && (countBuffer.isEmpty ? digit != "0" : true) {
            countBuffer += key
            return true
        }

        let count = Int(countBuffer) ?? 1
        countBuffer = ""

        switch key {
        // Mode switching
        case "i":
            enterInsertMode()
            return true
        case "I":
            moveToLineStart(textView)
            enterInsertMode()
            return true
        case "a":
            moveRight(textView, count: 1)
            enterInsertMode()
            return true
        case "A":
            moveToLineEnd(textView)
            enterInsertMode()
            return true
        case "o":
            insertLineBelow(textView)
            enterInsertMode()
            return true
        case "O":
            insertLineAbove(textView)
            enterInsertMode()
            return true
        case "v":
            enterVisualMode()
            return true
        case ":":
            enterCommandMode()
            return true

        // Navigation
        case "h":
            moveLeft(textView, count: count)
            return true
        case "j":
            moveDown(textView, count: count)
            return true
        case "k":
            moveUp(textView, count: count)
            return true
        case "l":
            moveRight(textView, count: count)
            return true
        case "w":
            moveWordForward(textView, count: count)
            return true
        case "b":
            moveWordBackward(textView, count: count)
            return true
        case "e":
            moveToEndOfWord(textView, count: count)
            return true
        case "0":
            moveToLineStart(textView)
            return true
        case "$":
            moveToLineEnd(textView)
            return true
        case "^":
            moveToFirstNonBlank(textView)
            return true
        case "G":
            if count > 1 || !countBuffer.isEmpty {
                goToLine(textView, line: count)
            } else {
                moveToEnd(textView)
            }
            return true
        case "g":
            operatorPending = "g"
            return true

        // Editing
        case "x":
            deleteCharacter(textView, count: count)
            return true
        case "d":
            operatorPending = "d"
            return true
        case "y":
            operatorPending = "y"
            return true
        case "c":
            operatorPending = "c"
            return true
        case "s":
            deleteCharacter(textView, count: 1)
            enterInsertMode()
            return true
        case "S":
            deleteLine(textView, count: 1)
            enterInsertMode()
            return true
        case "C":
            deleteToEndOfLine(textView)
            enterInsertMode()
            return true
        case "D":
            deleteToEndOfLine(textView)
            return true
        case "p":
            paste(textView, after: true)
            return true
        case "P":
            paste(textView, after: false)
            return true
        case "u":
            textView.undoManager?.undo()
            return true
        case "r":
            if modifiers.contains(.control) {
                textView.undoManager?.redo()
            }
            return true

        // Search
        case "/":
            enterCommandMode()
            commandBuffer = "/"
            return true
        case "n":
            searchNext(textView, forward: true)
            return true
        case "N":
            searchNext(textView, forward: false)
            return true

        default:
            operatorPending = nil
            return false
        }
    }

    // MARK: - Insert Mode

    private func handleInsertMode(key: String, modifiers: NSEvent.ModifierFlags, event: NSEvent) -> Bool {
        // Escape to normal mode
        if event.keyCode == 53 { // Escape key
            enterNormalMode()
            return true
        }

        // Ctrl+[ also exits insert mode
        if modifiers.contains(.control) && key == "[" {
            enterNormalMode()
            return true
        }

        // Let normal text input pass through
        return false
    }

    // MARK: - Visual Mode

    private func handleVisualMode(key: String, modifiers: NSEvent.ModifierFlags, event: NSEvent) -> Bool {
        guard let textView = textView else { return false }

        if event.keyCode == 53 { // Escape
            enterNormalMode()
            return true
        }

        switch key {
        case "h", "j", "k", "l", "w", "b", "e", "0", "$":
            extendSelection(textView, direction: key)
            return true
        case "d", "x":
            deleteSelection(textView)
            enterNormalMode()
            return true
        case "y":
            yankSelection(textView)
            enterNormalMode()
            return true
        default:
            return false
        }
    }

    // MARK: - Command Mode

    private func handleCommandMode(key: String, modifiers: NSEvent.ModifierFlags, event: NSEvent) -> Bool {
        if event.keyCode == 53 { // Escape
            commandBuffer = ""
            enterNormalMode()
            return true
        }

        if event.keyCode == 36 { // Return
            executeCommand()
            return true
        }

        if event.keyCode == 51 { // Delete
            if !commandBuffer.isEmpty {
                commandBuffer.removeLast()
                if commandBuffer.isEmpty {
                    enterNormalMode()
                }
            }
            return true
        }

        // Add character to command buffer
        commandBuffer += key
        return true
    }

    // MARK: - Mode Transitions

    private func enterNormalMode() {
        mode = .normal
        commandBuffer = ""
        statusMessage = ""
        // Move cursor back one position when leaving insert mode
        if let textView = textView {
            let pos = textView.selectedRange().location
            if pos > 0 {
                textView.setSelectedRange(NSRange(location: pos - 1, length: 0))
            }
        }
    }

    private func enterInsertMode() {
        mode = .insert
        statusMessage = ""
    }

    private func enterVisualMode() {
        mode = .visual
        statusMessage = ""
    }

    private func enterCommandMode() {
        mode = .command
        commandBuffer = ":"
        statusMessage = ""
    }

    // MARK: - Navigation Helpers

    private func moveLeft(_ textView: NSTextView, count: Int) {
        let pos = textView.selectedRange().location
        let newPos = max(0, pos - count)
        textView.setSelectedRange(NSRange(location: newPos, length: 0))
    }

    private func moveRight(_ textView: NSTextView, count: Int) {
        let pos = textView.selectedRange().location
        let length = textView.string.count
        let newPos = min(length, pos + count)
        textView.setSelectedRange(NSRange(location: newPos, length: 0))
    }

    private func moveUp(_ textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveUp(nil)
        }
    }

    private func moveDown(_ textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveDown(nil)
        }
    }

    private func moveWordForward(_ textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveWordForward(nil)
        }
    }

    private func moveWordBackward(_ textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveWordBackward(nil)
        }
    }

    private func moveToEndOfWord(_ textView: NSTextView, count: Int) {
        for _ in 0..<count {
            textView.moveWordForward(nil)
            textView.moveLeft(nil)
        }
    }

    private func moveToLineStart(_ textView: NSTextView) {
        textView.moveToBeginningOfLine(nil)
    }

    private func moveToLineEnd(_ textView: NSTextView) {
        textView.moveToEndOfLine(nil)
    }

    private func moveToFirstNonBlank(_ textView: NSTextView) {
        textView.moveToBeginningOfLine(nil)
        // Skip whitespace
        let string = textView.string as NSString
        var pos = textView.selectedRange().location
        while pos < string.length {
            let char = string.character(at: pos)
            if char != 32 && char != 9 { // space and tab
                break
            }
            pos += 1
        }
        textView.setSelectedRange(NSRange(location: pos, length: 0))
    }

    private func moveToStart(_ textView: NSTextView) {
        textView.setSelectedRange(NSRange(location: 0, length: 0))
    }

    private func moveToEnd(_ textView: NSTextView) {
        let length = textView.string.count
        textView.setSelectedRange(NSRange(location: length, length: 0))
    }

    private func goToLine(_ textView: NSTextView, line: Int) {
        let string = textView.string as NSString
        var currentLine = 1
        var pos = 0

        while pos < string.length && currentLine < line {
            if string.character(at: pos) == 10 { // newline
                currentLine += 1
            }
            pos += 1
        }

        textView.setSelectedRange(NSRange(location: pos, length: 0))
    }

    // MARK: - Scrolling

    private func scrollHalfPageDown(_ textView: NSTextView) {
        guard let scrollView = textView.enclosingScrollView else { return }
        let visibleHeight = scrollView.contentView.bounds.height
        let lineHeight = textView.font?.pointSize ?? 14
        let linesToScroll = Int(visibleHeight / lineHeight / 2)

        for _ in 0..<linesToScroll {
            textView.moveDown(nil)
        }
        textView.scrollRangeToVisible(textView.selectedRange())
    }

    private func scrollHalfPageUp(_ textView: NSTextView) {
        guard let scrollView = textView.enclosingScrollView else { return }
        let visibleHeight = scrollView.contentView.bounds.height
        let lineHeight = textView.font?.pointSize ?? 14
        let linesToScroll = Int(visibleHeight / lineHeight / 2)

        for _ in 0..<linesToScroll {
            textView.moveUp(nil)
        }
        textView.scrollRangeToVisible(textView.selectedRange())
    }

    private func scrollPageDown(_ textView: NSTextView) {
        textView.pageDown(nil)
    }

    private func scrollPageUp(_ textView: NSTextView) {
        textView.pageUp(nil)
    }

    // MARK: - Editing Helpers

    private func deleteCharacter(_ textView: NSTextView, count: Int) {
        let range = NSRange(location: textView.selectedRange().location, length: min(count, textView.string.count - textView.selectedRange().location))
        if range.length > 0 {
            registerContent = (textView.string as NSString).substring(with: range)
            textView.insertText("", replacementRange: range)
        }
    }

    private func deleteWord(_ textView: NSTextView) {
        let startPos = textView.selectedRange().location
        textView.moveWordForward(nil)
        let endPos = textView.selectedRange().location
        let range = NSRange(location: startPos, length: endPos - startPos)
        if range.length > 0 {
            registerContent = (textView.string as NSString).substring(with: range)
            textView.insertText("", replacementRange: range)
        }
    }

    private func deleteToEndOfLine(_ textView: NSTextView) {
        let string = textView.string as NSString
        let startPos = textView.selectedRange().location
        var endPos = startPos
        while endPos < string.length && string.character(at: endPos) != 10 {
            endPos += 1
        }
        let range = NSRange(location: startPos, length: endPos - startPos)
        if range.length > 0 {
            registerContent = (textView.string as NSString).substring(with: range)
            textView.insertText("", replacementRange: range)
        }
    }

    private func deleteLine(_ textView: NSTextView, count: Int) {
        let string = textView.string as NSString
        let pos = textView.selectedRange().location

        // Find line start
        var lineStart = pos
        while lineStart > 0 && string.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        // Find line end (including newline)
        var lineEnd = pos
        var linesDeleted = 0
        while lineEnd < string.length && linesDeleted < count {
            if string.character(at: lineEnd) == 10 {
                linesDeleted += 1
            }
            lineEnd += 1
            if linesDeleted >= count {
                break
            }
        }

        let range = NSRange(location: lineStart, length: lineEnd - lineStart)
        registerContent = string.substring(with: range)
        textView.insertText("", replacementRange: range)
        statusMessage = "\(count) line(s) deleted"
    }

    private func yankLine(_ textView: NSTextView, count: Int) {
        let string = textView.string as NSString
        let pos = textView.selectedRange().location

        // Find line start
        var lineStart = pos
        while lineStart > 0 && string.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        // Find line end
        var lineEnd = pos
        var linesYanked = 0
        while lineEnd < string.length && linesYanked < count {
            if string.character(at: lineEnd) == 10 {
                linesYanked += 1
            }
            lineEnd += 1
            if linesYanked >= count {
                break
            }
        }

        let range = NSRange(location: lineStart, length: lineEnd - lineStart)
        registerContent = string.substring(with: range)
        statusMessage = "\(count) line(s) yanked"
    }

    private func paste(_ textView: NSTextView, after: Bool) {
        guard !registerContent.isEmpty else { return }

        if after {
            moveRight(textView, count: 1)
        }
        textView.insertText(registerContent, replacementRange: textView.selectedRange())
    }

    private func insertLineBelow(_ textView: NSTextView) {
        textView.moveToEndOfLine(nil)
        textView.insertText("\n", replacementRange: textView.selectedRange())
    }

    private func insertLineAbove(_ textView: NSTextView) {
        textView.moveToBeginningOfLine(nil)
        textView.insertText("\n", replacementRange: textView.selectedRange())
        textView.moveUp(nil)
    }

    // MARK: - Visual Mode Helpers

    private func extendSelection(_ textView: NSTextView, direction: String) {
        switch direction {
        case "h":
            textView.moveLeftAndModifySelection(nil)
        case "j":
            textView.moveDownAndModifySelection(nil)
        case "k":
            textView.moveUpAndModifySelection(nil)
        case "l":
            textView.moveRightAndModifySelection(nil)
        case "w":
            textView.moveWordForwardAndModifySelection(nil)
        case "b":
            textView.moveWordBackwardAndModifySelection(nil)
        case "0":
            textView.moveToBeginningOfLineAndModifySelection(nil)
        case "$":
            textView.moveToEndOfLineAndModifySelection(nil)
        default:
            break
        }
    }

    private func deleteSelection(_ textView: NSTextView) {
        let range = textView.selectedRange()
        if range.length > 0 {
            registerContent = (textView.string as NSString).substring(with: range)
            textView.insertText("", replacementRange: range)
        }
    }

    private func yankSelection(_ textView: NSTextView) {
        let range = textView.selectedRange()
        if range.length > 0 {
            registerContent = (textView.string as NSString).substring(with: range)
            statusMessage = "yanked"
            textView.setSelectedRange(NSRange(location: range.location, length: 0))
        }
    }

    // MARK: - Search

    private func searchNext(_ textView: NSTextView, forward: Bool) {
        guard !lastSearch.isEmpty else { return }

        let string = textView.string as NSString
        let currentPos = textView.selectedRange().location

        if forward {
            let searchRange = NSRange(location: currentPos + 1, length: string.length - currentPos - 1)
            let foundRange = string.range(of: lastSearch, options: [], range: searchRange)
            if foundRange.location != NSNotFound {
                textView.setSelectedRange(NSRange(location: foundRange.location, length: 0))
                textView.scrollRangeToVisible(foundRange)
            }
        } else {
            let searchRange = NSRange(location: 0, length: currentPos)
            let foundRange = string.range(of: lastSearch, options: .backwards, range: searchRange)
            if foundRange.location != NSNotFound {
                textView.setSelectedRange(NSRange(location: foundRange.location, length: 0))
                textView.scrollRangeToVisible(foundRange)
            }
        }
    }

    // MARK: - Command Execution

    private func executeCommand() {
        let cmd = commandBuffer.dropFirst() // Remove ':'

        if cmd.hasPrefix("/") {
            // Search
            lastSearch = String(cmd.dropFirst())
            if let textView = textView {
                searchNext(textView, forward: true)
            }
        } else {
            switch cmd {
            case "w":
                onSave?()
                statusMessage = "saved"
            case "q":
                NSApp.terminate(nil)
            case "wq":
                onSave?()
                NSApp.terminate(nil)
            case "q!":
                NSApp.terminate(nil)
            default:
                statusMessage = "Unknown command: \(cmd)"
            }
        }

        commandBuffer = ""
        enterNormalMode()
    }
}
