import Foundation
import AppKit

// MARK: - Word Text Objects

struct InnerWordTextObject: VimTextObject {
    let id = "iw"

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        let pos = context.cursorPosition

        guard pos < text.length else {
            return NSRange(location: pos, length: 0)
        }

        var start = pos
        var end = pos

        // Find word boundaries
        while start > 0 && isWordChar(text.character(at: start - 1)) {
            start -= 1
        }
        while end < text.length && isWordChar(text.character(at: end)) {
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        return .handled
    }

    private func isWordChar(_ char: unichar) -> Bool {
        let c = Character(UnicodeScalar(char)!)
        return c.isLetter || c.isNumber || c == "_"
    }
}

struct AWordTextObject: VimTextObject {
    let id = "aw"

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        let pos = context.cursorPosition

        guard pos < text.length else {
            return NSRange(location: pos, length: 0)
        }

        var start = pos
        var end = pos

        // Find word boundaries
        while start > 0 && isWordChar(text.character(at: start - 1)) {
            start -= 1
        }
        while end < text.length && isWordChar(text.character(at: end)) {
            end += 1
        }

        // Include trailing whitespace
        while end < text.length && isWhitespace(text.character(at: end)) {
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        return .handled
    }

    private func isWordChar(_ char: unichar) -> Bool {
        let c = Character(UnicodeScalar(char)!)
        return c.isLetter || c.isNumber || c == "_"
    }

    private func isWhitespace(_ char: unichar) -> Bool {
        return Character(UnicodeScalar(char)!).isWhitespace
    }
}

// MARK: - Quote Text Objects

struct InnerQuoteTextObject: VimTextObject {
    let id: String
    let quoteChar: unichar

    init(quote: Character) {
        self.id = "i\(quote)"
        self.quoteChar = quote.unicodeScalars.first!.value > 0xFFFF ? 0 : unichar(quote.asciiValue ?? 0)
    }

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        let pos = context.cursorPosition

        // Find opening quote
        var start = pos
        while start > 0 && text.character(at: start) != quoteChar {
            start -= 1
        }

        if text.character(at: start) != quoteChar {
            return NSRange(location: pos, length: 0)
        }
        start += 1 // Move past opening quote

        // Find closing quote
        var end = start
        while end < text.length && text.character(at: end) != quoteChar {
            end += 1
        }

        if end >= text.length {
            return NSRange(location: pos, length: 0)
        }

        return NSRange(location: start, length: end - start)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        return .handled
    }
}

struct AQuoteTextObject: VimTextObject {
    let id: String
    let quoteChar: unichar

    init(quote: Character) {
        self.id = "a\(quote)"
        self.quoteChar = quote.unicodeScalars.first!.value > 0xFFFF ? 0 : unichar(quote.asciiValue ?? 0)
    }

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        let pos = context.cursorPosition

        // Find opening quote
        var start = pos
        while start > 0 && text.character(at: start) != quoteChar {
            start -= 1
        }

        if text.character(at: start) != quoteChar {
            return NSRange(location: pos, length: 0)
        }

        // Find closing quote
        var end = start + 1
        while end < text.length && text.character(at: end) != quoteChar {
            end += 1
        }

        if end >= text.length {
            return NSRange(location: pos, length: 0)
        }
        end += 1 // Include closing quote

        return NSRange(location: start, length: end - start)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        return .handled
    }
}

// MARK: - Bracket Text Objects

struct InnerBracketTextObject: VimTextObject {
    let id: String
    let openChar: unichar
    let closeChar: unichar

    init(open: Character, close: Character, key: String) {
        self.id = "i\(key)"
        self.openChar = unichar(open.asciiValue ?? 0)
        self.closeChar = unichar(close.asciiValue ?? 0)
    }

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        let pos = context.cursorPosition

        // Find opening bracket
        var start = pos
        var depth = 0

        while start >= 0 {
            let char = text.character(at: start)
            if char == closeChar { depth += 1 }
            if char == openChar {
                if depth == 0 { break }
                depth -= 1
            }
            if start == 0 { break }
            start -= 1
        }

        if start < 0 || text.character(at: start) != openChar {
            return NSRange(location: pos, length: 0)
        }
        start += 1 // Move past opening bracket

        // Find closing bracket
        var end = pos
        depth = 0

        while end < text.length {
            let char = text.character(at: end)
            if char == openChar { depth += 1 }
            if char == closeChar {
                if depth == 0 { break }
                depth -= 1
            }
            end += 1
        }

        if end >= text.length {
            return NSRange(location: pos, length: 0)
        }

        return NSRange(location: start, length: end - start)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        return .handled
    }
}

struct ABracketTextObject: VimTextObject {
    let id: String
    let openChar: unichar
    let closeChar: unichar

    init(open: Character, close: Character, key: String) {
        self.id = "a\(key)"
        self.openChar = unichar(open.asciiValue ?? 0)
        self.closeChar = unichar(close.asciiValue ?? 0)
    }

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        let pos = context.cursorPosition

        // Find opening bracket
        var start = pos
        var depth = 0

        while start >= 0 {
            let char = text.character(at: start)
            if char == closeChar { depth += 1 }
            if char == openChar {
                if depth == 0 { break }
                depth -= 1
            }
            if start == 0 { break }
            start -= 1
        }

        if start < 0 || text.character(at: start) != openChar {
            return NSRange(location: pos, length: 0)
        }

        // Find closing bracket
        var end = pos
        depth = 0

        while end < text.length {
            let char = text.character(at: end)
            if char == openChar { depth += 1 }
            if char == closeChar {
                if depth == 0 { break }
                depth -= 1
            }
            end += 1
        }

        if end >= text.length {
            return NSRange(location: pos, length: 0)
        }
        end += 1 // Include closing bracket

        return NSRange(location: start, length: end - start)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        return .handled
    }
}

// MARK: - Paragraph Text Object

struct InnerParagraphTextObject: VimTextObject {
    let id = "ip"

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        let pos = context.cursorPosition

        // Find paragraph start (two consecutive newlines or start of document)
        var start = pos
        while start > 1 {
            if text.character(at: start - 1) == 10 && text.character(at: start - 2) == 10 {
                break
            }
            start -= 1
        }

        // Find paragraph end
        var end = pos
        while end < text.length - 1 {
            if text.character(at: end) == 10 && text.character(at: end + 1) == 10 {
                break
            }
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        return .handled
    }
}

// MARK: - Line Text Object

struct InnerLineTextObject: VimTextObject {
    let id = "il"

    func range(in context: VimContext) -> NSRange {
        let text = context.text as NSString
        let pos = context.cursorPosition

        // Find line start
        var start = pos
        while start > 0 && text.character(at: start - 1) != 10 {
            start -= 1
        }

        // Skip leading whitespace
        while start < text.length {
            let char = text.character(at: start)
            if char != 32 && char != 9 { break }
            start += 1
        }

        // Find line end
        var end = pos
        while end < text.length && text.character(at: end) != 10 {
            end += 1
        }

        // Skip trailing whitespace
        while end > start {
            let char = text.character(at: end - 1)
            if char != 32 && char != 9 { break }
            end -= 1
        }

        return NSRange(location: start, length: end - start)
    }

    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        return .handled
    }
}
