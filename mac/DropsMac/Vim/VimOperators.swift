import Foundation
import AppKit

// MARK: - Delete Operator

struct DeleteOperator: VimOperator {
    let id = "d"

    func operate(on range: NSRange, context: VimContext, engine: VimEngine) -> VimActionResult {
        guard range.length > 0 else { return .handled }

        let text = context.text as NSString
        let deletedText = text.substring(with: range)
        engine.setRegister(deletedText)

        context.textView.insertText("", replacementRange: range)
        engine.onContentChange?()

        return .switchMode(.normal)
    }
}

struct DeleteLineOperator: VimOperator {
    let id = "dd"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let range = lineRange(in: context)
        return operate(on: range, context: context, engine: engine)
    }

    func operate(on range: NSRange, context: VimContext, engine: VimEngine) -> VimActionResult {
        let text = context.text as NSString
        let pos = context.cursorPosition

        // Find line boundaries
        var lineStart = pos
        while lineStart > 0 && text.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        var lineEnd = pos
        var linesDeleted = 0
        while lineEnd < text.length && linesDeleted < context.count {
            if text.character(at: lineEnd) == 10 {
                linesDeleted += 1
            }
            lineEnd += 1
            if linesDeleted >= context.count { break }
        }

        let deleteRange = NSRange(location: lineStart, length: lineEnd - lineStart)
        let deletedText = text.substring(with: deleteRange)
        engine.setRegister(deletedText)

        context.textView.insertText("", replacementRange: deleteRange)
        engine.setStatusMessage("\(context.count) line(s) deleted")
        engine.onContentChange?()

        return .switchMode(.normal)
    }

    private func lineRange(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        let pos = context.cursorPosition

        var lineStart = pos
        while lineStart > 0 && text.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        var lineEnd = pos
        while lineEnd < text.length && text.character(at: lineEnd) != 10 {
            lineEnd += 1
        }
        if lineEnd < text.length { lineEnd += 1 } // Include newline

        return NSRange(location: lineStart, length: lineEnd - lineStart)
    }
}

struct DeleteToEndOfLineOperator: VimCommand {
    let id = "D"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let text = context.text as NSString
        let startPos = context.cursorPosition
        var endPos = startPos

        while endPos < text.length && text.character(at: endPos) != 10 {
            endPos += 1
        }

        let range = NSRange(location: startPos, length: endPos - startPos)
        if range.length > 0 {
            let deletedText = text.substring(with: range)
            engine.setRegister(deletedText)
            context.textView.insertText("", replacementRange: range)
            engine.onContentChange?()
        }

        return .handled
    }
}

// MARK: - Yank Operator

struct YankOperator: VimOperator {
    let id = "y"

    func operate(on range: NSRange, context: VimContext, engine: VimEngine) -> VimActionResult {
        guard range.length > 0 else { return .handled }

        let text = context.text as NSString
        let yankedText = text.substring(with: range)
        engine.setRegister(yankedText)
        engine.setStatusMessage("yanked")

        // Move cursor to start of yanked region
        context.textView.setSelectedRange(NSRange(location: range.location, length: 0))

        return .switchMode(.normal)
    }
}

struct YankLineOperator: VimOperator {
    let id = "yy"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let text = context.text as NSString
        let pos = context.cursorPosition

        // Find line boundaries
        var lineStart = pos
        while lineStart > 0 && text.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        var lineEnd = pos
        var linesYanked = 0
        while lineEnd < text.length && linesYanked < context.count {
            if text.character(at: lineEnd) == 10 {
                linesYanked += 1
            }
            lineEnd += 1
            if linesYanked >= context.count { break }
        }

        let range = NSRange(location: lineStart, length: lineEnd - lineStart)
        let yankedText = text.substring(with: range)
        engine.setRegister(yankedText)
        engine.setStatusMessage("\(context.count) line(s) yanked")

        return .handled
    }

    func operate(on range: NSRange, context: VimContext, engine: VimEngine) -> VimActionResult {
        return execute(context: context, engine: engine)
    }
}

// MARK: - Change Operator

struct ChangeOperator: VimOperator {
    let id = "c"

    func operate(on range: NSRange, context: VimContext, engine: VimEngine) -> VimActionResult {
        guard range.length > 0 else { return .switchMode(.insert) }

        let text = context.text as NSString
        let deletedText = text.substring(with: range)
        engine.setRegister(deletedText)

        context.textView.insertText("", replacementRange: range)
        engine.onContentChange?()

        return .switchMode(.insert)
    }
}

struct ChangeLineOperator: VimCommand {
    let id = "cc"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let text = context.text as NSString
        let pos = context.cursorPosition

        // Find line content (not including leading whitespace and newline)
        var lineStart = pos
        while lineStart > 0 && text.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        // Skip leading whitespace
        var contentStart = lineStart
        while contentStart < text.length {
            let char = text.character(at: contentStart)
            if char != 32 && char != 9 { break }
            contentStart += 1
        }

        var lineEnd = pos
        while lineEnd < text.length && text.character(at: lineEnd) != 10 {
            lineEnd += 1
        }

        let range = NSRange(location: contentStart, length: lineEnd - contentStart)
        if range.length > 0 {
            let deletedText = text.substring(with: range)
            engine.setRegister(deletedText)
            context.textView.insertText("", replacementRange: range)
            engine.onContentChange?()
        }

        return .switchMode(.insert)
    }
}

struct ChangeToEndOfLineOperator: VimCommand {
    let id = "C"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let text = context.text as NSString
        let startPos = context.cursorPosition
        var endPos = startPos

        while endPos < text.length && text.character(at: endPos) != 10 {
            endPos += 1
        }

        let range = NSRange(location: startPos, length: endPos - startPos)
        if range.length > 0 {
            let deletedText = text.substring(with: range)
            engine.setRegister(deletedText)
            context.textView.insertText("", replacementRange: range)
            engine.onContentChange?()
        }

        return .switchMode(.insert)
    }
}

// MARK: - Put (Paste) Commands

struct PutAfterCommand: VimCommand {
    let id = "p"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        guard let registerContent = engine.getRegister(), !registerContent.isEmpty else {
            return .handled
        }

        let pos = context.cursorPosition
        let newPos = min(pos + 1, context.textLength)
        context.textView.setSelectedRange(NSRange(location: newPos, length: 0))
        context.textView.insertText(registerContent, replacementRange: context.textView.selectedRange())
        engine.onContentChange?()

        return .handled
    }
}

struct PutBeforeCommand: VimCommand {
    let id = "P"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        guard let registerContent = engine.getRegister(), !registerContent.isEmpty else {
            return .handled
        }

        context.textView.insertText(registerContent, replacementRange: context.selectedRange)
        engine.onContentChange?()

        return .handled
    }
}

// MARK: - Delete Character

struct DeleteCharCommand: VimCommand {
    let id = "x"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let range = NSRange(
            location: context.cursorPosition,
            length: min(context.count, context.textLength - context.cursorPosition)
        )

        if range.length > 0 {
            let text = context.text as NSString
            let deletedText = text.substring(with: range)
            engine.setRegister(deletedText)
            context.textView.insertText("", replacementRange: range)
            engine.onContentChange?()
        }

        return .handled
    }
}

struct SubstituteCharCommand: VimCommand {
    let id = "s"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let range = NSRange(location: context.cursorPosition, length: 1)

        if range.location < context.textLength {
            let text = context.text as NSString
            let deletedText = text.substring(with: range)
            engine.setRegister(deletedText)
            context.textView.insertText("", replacementRange: range)
            engine.onContentChange?()
        }

        return .switchMode(.insert)
    }
}

struct SubstituteLineCommand: VimCommand {
    let id = "S"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        // Same as cc
        return ChangeLineOperator().execute(context: context, engine: engine)
    }
}
