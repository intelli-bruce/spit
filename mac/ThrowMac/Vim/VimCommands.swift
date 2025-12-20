import Foundation
import AppKit

// MARK: - Mode Switching Commands

struct EnterInsertModeCommand: VimCommand {
    let id = "i"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        return .switchMode(.insert)
    }
}

struct EnterInsertModeStartCommand: VimCommand {
    let id = "I"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        // Move to first non-blank
        context.textView.moveToBeginningOfLine(nil)
        let text = context.text as NSString
        var pos = context.textView.selectedRange().location
        while pos < text.length {
            let char = text.character(at: pos)
            if char != 32 && char != 9 { break }
            pos += 1
        }
        context.textView.setSelectedRange(NSRange(location: pos, length: 0))

        return .switchMode(.insert)
    }
}

struct AppendCommand: VimCommand {
    let id = "a"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let pos = context.cursorPosition
        let newPos = min(pos + 1, context.textLength)
        context.textView.setSelectedRange(NSRange(location: newPos, length: 0))
        return .switchMode(.insert)
    }
}

struct AppendEndCommand: VimCommand {
    let id = "A"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        context.textView.moveToEndOfLine(nil)
        return .switchMode(.insert)
    }
}

struct OpenLineBelowCommand: VimCommand {
    let id = "o"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        context.textView.moveToEndOfLine(nil)
        context.textView.insertText("\n", replacementRange: context.textView.selectedRange())
        engine.onContentChange?()
        return .switchMode(.insert)
    }
}

struct OpenLineAboveCommand: VimCommand {
    let id = "O"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        context.textView.moveToBeginningOfLine(nil)
        context.textView.insertText("\n", replacementRange: context.textView.selectedRange())
        context.textView.moveUp(nil)
        engine.onContentChange?()
        return .switchMode(.insert)
    }
}

struct EnterVisualModeCommand: VimCommand {
    let id = "v"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        engine.setVisualAnchor(context.cursorPosition)
        return .switchMode(.visual)
    }
}

struct EnterVisualLineModeCommand: VimCommand {
    let id = "V"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        engine.setVisualAnchor(context.cursorPosition)
        return .switchMode(.visualLine)
    }
}

struct EnterCommandModeCommand: VimCommand {
    let id = ":"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        engine.setCommandBuffer(":")
        return .switchMode(.command)
    }
}

struct EscapeCommand: VimCommand {
    let id = "<Esc>"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        engine.clearCommandBuffer()
        engine.clearStatusMessage()

        // Move cursor back one in insert mode
        if engine.mode == .insert {
            let pos = context.cursorPosition
            if pos > 0 {
                context.textView.setSelectedRange(NSRange(location: pos - 1, length: 0))
            }
        }

        return .switchMode(.normal)
    }
}

// MARK: - Undo/Redo Commands

struct UndoCommand: VimCommand {
    let id = "u"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        context.textView.undoManager?.undo()
        return .handled
    }
}

struct RedoCommand: VimCommand {
    let id = "ctrl-r"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        context.textView.undoManager?.redo()
        return .handled
    }
}

// MARK: - Search Commands

struct SearchForwardCommand: VimCommand {
    let id = "/"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        engine.setCommandBuffer("/")
        return .switchMode(.command)
    }
}

struct SearchBackwardCommand: VimCommand {
    let id = "?"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        engine.setCommandBuffer("?")
        return .switchMode(.command)
    }
}

struct SearchNextCommand: VimCommand {
    let id = "n"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        guard let pattern = engine.getLastSearch(), !pattern.isEmpty else {
            return .handled
        }

        let text = context.text as NSString
        let currentPos = context.cursorPosition

        let searchRange = NSRange(location: currentPos + 1, length: text.length - currentPos - 1)
        if searchRange.length > 0 {
            let foundRange = text.range(of: pattern, options: [], range: searchRange)
            if foundRange.location != NSNotFound {
                context.textView.setSelectedRange(NSRange(location: foundRange.location, length: 0))
                context.textView.scrollRangeToVisible(foundRange)
            }
        }

        return .handled
    }
}

struct SearchPrevCommand: VimCommand {
    let id = "N"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        guard let pattern = engine.getLastSearch(), !pattern.isEmpty else {
            return .handled
        }

        let text = context.text as NSString
        let currentPos = context.cursorPosition

        let searchRange = NSRange(location: 0, length: currentPos)
        if searchRange.length > 0 {
            let foundRange = text.range(of: pattern, options: .backwards, range: searchRange)
            if foundRange.location != NSNotFound {
                context.textView.setSelectedRange(NSRange(location: foundRange.location, length: 0))
                context.textView.scrollRangeToVisible(foundRange)
            }
        }

        return .handled
    }
}

// MARK: - Visual Mode Commands

struct VisualDeleteCommand: VimCommand {
    let id = "v_d"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let range = context.selectedRange
        if range.length > 0 {
            let text = context.text as NSString
            let deletedText = text.substring(with: range)
            engine.setRegister(deletedText)
            context.textView.insertText("", replacementRange: range)
            engine.onContentChange?()
        }
        return .switchMode(.normal)
    }
}

struct VisualYankCommand: VimCommand {
    let id = "v_y"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let range = context.selectedRange
        if range.length > 0 {
            let text = context.text as NSString
            let yankedText = text.substring(with: range)
            engine.setRegister(yankedText)
            engine.setStatusMessage("yanked")
            context.textView.setSelectedRange(NSRange(location: range.location, length: 0))
        }
        return .switchMode(.normal)
    }
}

struct VisualChangeCommand: VimCommand {
    let id = "v_c"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let range = context.selectedRange
        if range.length > 0 {
            let text = context.text as NSString
            let deletedText = text.substring(with: range)
            engine.setRegister(deletedText)
            context.textView.insertText("", replacementRange: range)
            engine.onContentChange?()
        }
        return .switchMode(.insert)
    }
}

// MARK: - Repeat Command

struct RepeatLastChangeCommand: VimCommand {
    let id = "."

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        // TODO: Implement repeat last change
        engine.setStatusMessage("repeat not yet implemented")
        return .handled
    }
}

// MARK: - Join Lines

struct JoinLinesCommand: VimCommand {
    let id = "J"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let text = context.text as NSString
        var lineEnd = context.cursorPosition

        // Find end of current line
        while lineEnd < text.length && text.character(at: lineEnd) != 10 {
            lineEnd += 1
        }

        if lineEnd < text.length {
            // Replace newline with space
            let range = NSRange(location: lineEnd, length: 1)
            context.textView.insertText(" ", replacementRange: range)
            engine.onContentChange?()
        }

        return .handled
    }
}

// MARK: - Replace Character

struct ReplaceCharCommand: VimCommand {
    let id = "r"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        // This needs special handling - wait for next character
        engine.setStatusMessage("replace...")
        // TODO: Implement waiting for next char
        return .handled
    }
}

// MARK: - Marks (placeholder)

struct SetMarkCommand: VimCommand {
    let id = "m"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        engine.setStatusMessage("marks not yet implemented")
        return .handled
    }
}

struct GotoMarkCommand: VimCommand {
    let id = "'"

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        engine.setStatusMessage("marks not yet implemented")
        return .handled
    }
}
