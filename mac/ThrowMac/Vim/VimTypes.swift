import Foundation
import AppKit

// MARK: - Vim Mode

enum VimMode: String {
    case normal = "NORMAL"
    case insert = "INSERT"
    case visual = "VISUAL"
    case visualLine = "V-LINE"
    case command = "COMMAND"
    case operatorPending = "OP-PENDING"
}

// MARK: - Vim Context

/// Context passed to all vim actions
struct VimContext {
    let textView: NSTextView
    let count: Int
    let register: String

    var text: String { textView.string }
    var selectedRange: NSRange { textView.selectedRange() }
    var cursorPosition: Int { selectedRange.location }
    var textLength: Int { text.count }

    func setText(_ newText: String, range: NSRange) {
        textView.insertText(newText, replacementRange: range)
    }
}

// MARK: - Vim Action Result

enum VimActionResult {
    case handled
    case switchMode(VimMode)
    case operatorPending(VimOperator)
    case none
}

// MARK: - Protocols

/// Base protocol for all vim actions
@MainActor
protocol VimAction {
    var id: String { get }
    func execute(context: VimContext, engine: VimEngine) -> VimActionResult
}

/// Motion - moves cursor, can be used with operators
@MainActor
protocol VimMotion: VimAction {
    /// Returns the range that this motion covers from current position
    func range(in context: VimContext) -> NSRange
}

extension VimMotion {
    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        let range = range(in: context)
        context.textView.setSelectedRange(NSRange(location: range.location + range.length, length: 0))
        context.textView.scrollRangeToVisible(context.textView.selectedRange())
        return .handled
    }
}

/// Operator - operates on text (d, y, c, etc.)
@MainActor
protocol VimOperator: VimAction {
    func operate(on range: NSRange, context: VimContext, engine: VimEngine) -> VimActionResult
}

extension VimOperator {
    func execute(context: VimContext, engine: VimEngine) -> VimActionResult {
        return .operatorPending(self)
    }
}

/// Text Object - defines a region of text (iw, aw, i", etc.)
@MainActor
protocol VimTextObject: VimAction {
    func range(in context: VimContext) -> NSRange
}

/// Simple command - executes immediately
@MainActor
protocol VimCommand: VimAction {}

// MARK: - Key Sequence

struct KeySequence: Hashable {
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }
}

// MARK: - Keymap

class VimKeymap {
    private var bindings: [VimMode: [String: VimAction]] = [:]
    private var pendingKeys: String = ""

    init() {
        for mode in [VimMode.normal, .insert, .visual, .visualLine, .command, .operatorPending] {
            bindings[mode] = [:]
        }
    }

    func bind(_ keys: String, to action: VimAction, in mode: VimMode) {
        bindings[mode]?[keys] = action
    }

    func bind(_ keys: String, to action: VimAction, in modes: [VimMode]) {
        for mode in modes {
            bind(keys, to: action, in: mode)
        }
    }

    func unbind(_ keys: String, in mode: VimMode) {
        bindings[mode]?[keys] = nil
    }

    func action(for keys: String, in mode: VimMode) -> VimAction? {
        return bindings[mode]?[keys]
    }

    func hasPrefix(_ keys: String, in mode: VimMode) -> Bool {
        guard let modeBindings = bindings[mode] else { return false }
        return modeBindings.keys.contains { $0.hasPrefix(keys) && $0 != keys }
    }

    func allBindings(in mode: VimMode) -> [String: VimAction] {
        return bindings[mode] ?? [:]
    }
}
