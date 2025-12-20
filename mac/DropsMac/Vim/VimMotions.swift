import Foundation
import AppKit

// MARK: - Character Motions

struct LeftMotion: VimMotion {
    let id = "h"

    func range(in context: VimContext) -> NSRange {
        let pos = context.cursorPosition
        let newPos = max(0, pos - context.count)
        return NSRange(location: newPos, length: pos - newPos)
    }
}

struct RightMotion: VimMotion {
    let id = "l"

    func range(in context: VimContext) -> NSRange {
        let pos = context.cursorPosition
        let newPos = min(context.textLength, pos + context.count)
        return NSRange(location: pos, length: newPos - pos)
    }
}

struct UpMotion: VimMotion {
    let id = "k"

    func range(in context: VimContext) -> NSRange {
        // Simplified: just move up by count lines
        let textView = context.textView
        for _ in 0..<context.count {
            textView.moveUp(nil)
        }
        return NSRange(location: textView.selectedRange().location, length: 0)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        for _ in 0..<context.count {
            context.textView.moveUp(nil)
        }
        return .handled
    }
}

struct DownMotion: VimMotion {
    let id = "j"

    func range(in context: VimContext) -> NSRange {
        let textView = context.textView
        for _ in 0..<context.count {
            textView.moveDown(nil)
        }
        return NSRange(location: textView.selectedRange().location, length: 0)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        for _ in 0..<context.count {
            context.textView.moveDown(nil)
        }
        return .handled
    }
}

// MARK: - Word Motions

struct WordForwardMotion: VimMotion {
    let id = "w"

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        var pos = context.cursorPosition

        for _ in 0..<context.count {
            // Skip current word
            while pos < text.length && !isWordBoundary(text.character(at: pos)) {
                pos += 1
            }
            // Skip whitespace
            while pos < text.length && isWhitespace(text.character(at: pos)) {
                pos += 1
            }
        }

        return NSRange(location: context.cursorPosition, length: pos - context.cursorPosition)
    }

    private func isWordBoundary(_ char: unichar) -> Bool {
        let c = Character(UnicodeScalar(char)!)
        return c.isWhitespace || c.isPunctuation
    }

    private func isWhitespace(_ char: unichar) -> Bool {
        return Character(UnicodeScalar(char)!).isWhitespace
    }
}

struct WordBackwardMotion: VimMotion {
    let id = "b"

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        var pos = context.cursorPosition

        for _ in 0..<context.count {
            // Move back one if not at start
            if pos > 0 { pos -= 1 }

            // Skip whitespace
            while pos > 0 && isWhitespace(text.character(at: pos)) {
                pos -= 1
            }
            // Skip to start of word
            while pos > 0 && !isWordBoundary(text.character(at: pos - 1)) {
                pos -= 1
            }
        }

        return NSRange(location: pos, length: context.cursorPosition - pos)
    }

    private func isWordBoundary(_ char: unichar) -> Bool {
        let c = Character(UnicodeScalar(char)!)
        return c.isWhitespace || c.isPunctuation
    }

    private func isWhitespace(_ char: unichar) -> Bool {
        return Character(UnicodeScalar(char)!).isWhitespace
    }
}

struct WordEndMotion: VimMotion {
    let id = "e"

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        var pos = context.cursorPosition

        for _ in 0..<context.count {
            if pos < text.length { pos += 1 }

            // Skip whitespace
            while pos < text.length && isWhitespace(text.character(at: pos)) {
                pos += 1
            }
            // Move to end of word
            while pos < text.length - 1 && !isWordBoundary(text.character(at: pos + 1)) {
                pos += 1
            }
        }

        return NSRange(location: context.cursorPosition, length: pos - context.cursorPosition)
    }

    private func isWordBoundary(_ char: unichar) -> Bool {
        let c = Character(UnicodeScalar(char)!)
        return c.isWhitespace || c.isPunctuation
    }

    private func isWhitespace(_ char: unichar) -> Bool {
        return Character(UnicodeScalar(char)!).isWhitespace
    }
}

// MARK: - Line Motions

struct LineStartMotion: VimMotion {
    let id = "0"

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        var lineStart = context.cursorPosition

        while lineStart > 0 && text.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        return NSRange(location: lineStart, length: context.cursorPosition - lineStart)
    }
}

struct LineEndMotion: VimMotion {
    let id = "$"

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        var lineEnd = context.cursorPosition

        while lineEnd < text.length && text.character(at: lineEnd) != 10 {
            lineEnd += 1
        }

        return NSRange(location: context.cursorPosition, length: lineEnd - context.cursorPosition)
    }
}

struct FirstNonBlankMotion: VimMotion {
    let id = "^"

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        var lineStart = context.cursorPosition

        // Find line start
        while lineStart > 0 && text.character(at: lineStart - 1) != 10 {
            lineStart -= 1
        }

        // Skip whitespace
        var pos = lineStart
        while pos < text.length {
            let char = text.character(at: pos)
            if char != 32 && char != 9 { break }
            pos += 1
        }

        return NSRange(location: min(pos, context.cursorPosition), length: abs(pos - context.cursorPosition))
    }
}

// MARK: - Document Motions

struct DocumentStartMotion: VimMotion {
    let id = "gg"

    func range(in context: VimContext) -> NSRange {
        return NSRange(location: 0, length: context.cursorPosition)
    }
}

struct DocumentEndMotion: VimMotion {
    let id = "G"

    func range(in context: VimContext) -> NSRange {
        return NSRange(location: context.cursorPosition, length: context.textLength - context.cursorPosition)
    }
}

struct GoToLineMotion: VimMotion {
    let id = "G_line"
    let line: Int

    init(line: Int) {
        self.line = line
    }

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        var currentLine = 1
        var pos = 0

        while pos < text.length && currentLine < line {
            if text.character(at: pos) == 10 {
                currentLine += 1
            }
            pos += 1
        }

        return NSRange(location: min(pos, context.cursorPosition), length: abs(pos - context.cursorPosition))
    }
}

// MARK: - Scroll Motions

struct HalfPageDownMotion: VimMotion {
    let id = "ctrl-d"

    func range(in context: VimContext) -> NSRange {
        return NSRange(location: context.cursorPosition, length: 0)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        guard let scrollView = context.textView.enclosingScrollView else { return .handled }
        let visibleHeight = scrollView.contentView.bounds.height
        let lineHeight = context.textView.font?.pointSize ?? 14
        let linesToScroll = Int(visibleHeight / lineHeight / 2)

        for _ in 0..<linesToScroll {
            context.textView.moveDown(nil)
        }
        context.textView.scrollRangeToVisible(context.textView.selectedRange())
        return .handled
    }
}

struct HalfPageUpMotion: VimMotion {
    let id = "ctrl-u"

    func range(in context: VimContext) -> NSRange {
        return NSRange(location: context.cursorPosition, length: 0)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        guard let scrollView = context.textView.enclosingScrollView else { return .handled }
        let visibleHeight = scrollView.contentView.bounds.height
        let lineHeight = context.textView.font?.pointSize ?? 14
        let linesToScroll = Int(visibleHeight / lineHeight / 2)

        for _ in 0..<linesToScroll {
            context.textView.moveUp(nil)
        }
        context.textView.scrollRangeToVisible(context.textView.selectedRange())
        return .handled
    }
}

struct PageDownMotion: VimMotion {
    let id = "ctrl-f"

    func range(in context: VimContext) -> NSRange {
        return NSRange(location: context.cursorPosition, length: 0)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        context.textView.pageDown(nil)
        return .handled
    }
}

struct PageUpMotion: VimMotion {
    let id = "ctrl-b"

    func range(in context: VimContext) -> NSRange {
        return NSRange(location: context.cursorPosition, length: 0)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        context.textView.pageUp(nil)
        return .handled
    }
}
