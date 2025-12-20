import Foundation
import AppKit
import Combine

@MainActor
class VimEngine: ObservableObject {
    // MARK: - Published State

    @Published private(set) var mode: VimMode = .normal
    @Published private(set) var commandBuffer: String = ""
    @Published private(set) var statusMessage: String = ""

    // MARK: - Internal State

    private var countBuffer: String = ""
    private var pendingOperator: VimOperator?
    private var pendingKeys: String = ""
    private var register: String = ""
    private var lastSearch: String = ""
    private var visualAnchor: Int = 0

    // MARK: - Keymap

    private let keymap = VimKeymap()

    // MARK: - External References

    weak var textView: NSTextView?
    var onSave: (() -> Void)?
    var onContentChange: (() -> Void)?
    var onEscapeInNormalMode: (() -> Void)?

    // MARK: - Initialization

    init() {
        registerDefaultBindings()
    }

    // MARK: - Public API

    /// Register a custom binding
    func bind(_ keys: String, to action: VimAction, in mode: VimMode) {
        keymap.bind(keys, to: action, in: mode)
    }

    /// Register a binding for multiple modes
    func bind(_ keys: String, to action: VimAction, in modes: [VimMode]) {
        keymap.bind(keys, to: action, in: modes)
    }

    /// Remove a binding
    func unbind(_ keys: String, in mode: VimMode) {
        keymap.unbind(keys, in: mode)
    }

    // MARK: - Key Handling

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard let textView = textView else { return false }

        let key = translateKey(event)
        let modifiers = event.modifierFlags

        // Handle Escape specially
        if event.keyCode == 53 {
            return handleEscape()
        }

        // Command mode input
        if mode == .command {
            return handleCommandModeInput(event: event, key: key)
        }

        // Insert mode - only handle escape
        if mode == .insert {
            return false
        }

        // Build key sequence
        pendingKeys += key

        // Check for count prefix (but not if we already have pending keys)
        if pendingKeys.count == 1, let digit = key.first, digit.isNumber {
            if countBuffer.isEmpty && digit == "0" {
                // 0 is line start motion, not count
            } else {
                countBuffer += key
                pendingKeys = ""
                return true
            }
        }

        // Look for matching action
        let currentMode = pendingOperator != nil ? .operatorPending : mode

        // Check if pending keys could match a longer sequence FIRST
        if keymap.hasPrefix(pendingKeys, in: currentMode) {
            // Wait for more keys
            return true
        }

        if let action = keymap.action(for: pendingKeys, in: currentMode) {
            let count = Int(countBuffer) ?? 1
            countBuffer = ""
            pendingKeys = ""

            let context = VimContext(textView: textView, count: count, register: register)
            let result = executeAction(action, context: context)
            handleResult(result)
            return true
        }

        // No match - reset
        pendingKeys = ""
        countBuffer = ""
        return false
    }

    private func executeAction(_ action: VimAction, context: VimContext) -> VimActionResult {
        // If we have a pending operator and this is a motion or text object
        if let op = pendingOperator {
            if let motion = action as? VimMotion {
                let range = motion.range(in: context)
                pendingOperator = nil
                return op.operate(on: range, context: context, engine: self)
            }
            if let textObj = action as? VimTextObject {
                let range = textObj.range(in: context)
                pendingOperator = nil
                return op.operate(on: range, context: context, engine: self)
            }
            // If same operator key pressed again (like dd, yy)
            if let newOp = action as? VimOperator, newOp.id == op.id {
                pendingOperator = nil
                // Execute line-wise operation
                return (action as! VimOperator).execute(context: context, engine: self)
            }
            pendingOperator = nil
        }

        return action.execute(context: context, engine: self)
    }

    private func handleResult(_ result: VimActionResult) {
        switch result {
        case .handled:
            break
        case .switchMode(let newMode):
            mode = newMode
            if newMode == .normal {
                pendingOperator = nil
            }
        case .operatorPending(let op):
            pendingOperator = op
            mode = .operatorPending
        case .none:
            break
        }

        updateVisualSelection()
    }

    private func handleEscape() -> Bool {
        // If already in normal mode, notify to exit editing
        if mode == .normal {
            onEscapeInNormalMode?()
            return true
        }

        if mode == .insert {
            if let textView = textView {
                let pos = textView.selectedRange().location
                if pos > 0 {
                    textView.setSelectedRange(NSRange(location: pos - 1, length: 0))
                }
            }
        }

        mode = .normal
        pendingOperator = nil
        pendingKeys = ""
        countBuffer = ""
        commandBuffer = ""
        statusMessage = ""
        return true
    }

    private func handleCommandModeInput(event: NSEvent, key: String) -> Bool {
        // Return - execute command
        if event.keyCode == 36 {
            executeExCommand()
            return true
        }

        // Backspace
        if event.keyCode == 51 {
            if commandBuffer.count > 1 {
                commandBuffer.removeLast()
            } else {
                mode = .normal
                commandBuffer = ""
            }
            return true
        }

        // Escape handled above

        // Add character
        commandBuffer += key
        return true
    }

    private func executeExCommand() {
        let cmd = String(commandBuffer.dropFirst())
        commandBuffer = ""

        if cmd.hasPrefix("/") {
            // Search forward
            lastSearch = String(cmd.dropFirst())
            searchNext(forward: true)
        } else if cmd.hasPrefix("?") {
            // Search backward
            lastSearch = String(cmd.dropFirst())
            searchNext(forward: false)
        } else {
            switch cmd {
            case "w":
                onSave?()
                statusMessage = "saved"
            case "q":
                NSApp.terminate(nil)
            case "wq", "x":
                onSave?()
                NSApp.terminate(nil)
            case "q!":
                NSApp.terminate(nil)
            default:
                if let lineNum = Int(cmd) {
                    goToLine(lineNum)
                } else {
                    statusMessage = "Unknown command: \(cmd)"
                }
            }
        }

        mode = .normal
    }

    private func searchNext(forward: Bool) {
        guard let textView = textView, !lastSearch.isEmpty else { return }

        let text = textView.string as NSString
        let currentPos = textView.selectedRange().location

        if forward {
            let searchRange = NSRange(location: currentPos + 1, length: text.length - currentPos - 1)
            if searchRange.length > 0 {
                let foundRange = text.range(of: lastSearch, options: [], range: searchRange)
                if foundRange.location != NSNotFound {
                    textView.setSelectedRange(NSRange(location: foundRange.location, length: 0))
                    textView.scrollRangeToVisible(foundRange)
                }
            }
        } else {
            let searchRange = NSRange(location: 0, length: currentPos)
            if searchRange.length > 0 {
                let foundRange = text.range(of: lastSearch, options: .backwards, range: searchRange)
                if foundRange.location != NSNotFound {
                    textView.setSelectedRange(NSRange(location: foundRange.location, length: 0))
                    textView.scrollRangeToVisible(foundRange)
                }
            }
        }
    }

    private func goToLine(_ line: Int) {
        guard let textView = textView else { return }
        let text = textView.string as NSString
        var currentLine = 1
        var pos = 0

        while pos < text.length && currentLine < line {
            if text.character(at: pos) == 10 {
                currentLine += 1
            }
            pos += 1
        }

        textView.setSelectedRange(NSRange(location: pos, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
    }

    private func updateVisualSelection() {
        guard let textView = textView else { return }

        if mode == .visual || mode == .visualLine {
            let currentPos = textView.selectedRange().location
            let start = min(visualAnchor, currentPos)
            let end = max(visualAnchor, currentPos)
            var length = end - start

            if mode == .visualLine {
                // Extend to full lines
                // TODO: Implement line-wise selection
            } else {
                length = max(1, length)
            }

            textView.setSelectedRange(NSRange(location: start, length: length))
        }
    }

    private func translateKey(_ event: NSEvent) -> String {
        let modifiers = event.modifierFlags
        var key = event.charactersIgnoringModifiers ?? ""

        // Special keys
        switch event.keyCode {
        case 36: key = "<CR>"
        case 48: key = "<Tab>"
        case 51: key = "<BS>"
        case 53: key = "<Esc>"
        case 123: key = "<Left>"
        case 124: key = "<Right>"
        case 125: key = "<Down>"
        case 126: key = "<Up>"
        default: break
        }

        // Control key combinations
        if modifiers.contains(.control) && !key.hasPrefix("<") {
            key = "ctrl-\(key.lowercased())"
        }

        return key
    }

    // MARK: - State Accessors (for actions)

    func setRegister(_ content: String) {
        register = content
    }

    func getRegister() -> String? {
        return register.isEmpty ? nil : register
    }

    func setStatusMessage(_ message: String) {
        statusMessage = message
    }

    func clearStatusMessage() {
        statusMessage = ""
    }

    func setCommandBuffer(_ buffer: String) {
        commandBuffer = buffer
    }

    func clearCommandBuffer() {
        commandBuffer = ""
    }

    func setVisualAnchor(_ position: Int) {
        visualAnchor = position
    }

    func getLastSearch() -> String? {
        return lastSearch.isEmpty ? nil : lastSearch
    }

    func enterInsertMode() {
        mode = .insert
        pendingOperator = nil
        pendingKeys = ""
        countBuffer = ""
    }

    // MARK: - Default Bindings

    private func registerDefaultBindings() {
        // Mode switching
        keymap.bind("i", to: EnterInsertModeCommand(), in: .normal)
        keymap.bind("I", to: EnterInsertModeStartCommand(), in: .normal)
        keymap.bind("a", to: AppendCommand(), in: .normal)
        keymap.bind("A", to: AppendEndCommand(), in: .normal)
        keymap.bind("o", to: OpenLineBelowCommand(), in: .normal)
        keymap.bind("O", to: OpenLineAboveCommand(), in: .normal)
        keymap.bind("v", to: EnterVisualModeCommand(), in: .normal)
        keymap.bind("V", to: EnterVisualLineModeCommand(), in: .normal)
        keymap.bind(":", to: EnterCommandModeCommand(), in: .normal)

        // Motions (normal and visual)
        let motionModes: [VimMode] = [.normal, .visual, .visualLine, .operatorPending]
        keymap.bind("h", to: LeftMotion(), in: motionModes)
        keymap.bind("j", to: DownMotion(), in: motionModes)
        keymap.bind("k", to: UpMotion(), in: motionModes)
        keymap.bind("l", to: RightMotion(), in: motionModes)
        keymap.bind("w", to: WordForwardMotion(), in: motionModes)
        keymap.bind("b", to: WordBackwardMotion(), in: motionModes)
        keymap.bind("e", to: WordEndMotion(), in: motionModes)
        keymap.bind("0", to: LineStartMotion(), in: motionModes)
        keymap.bind("$", to: LineEndMotion(), in: motionModes)
        keymap.bind("^", to: FirstNonBlankMotion(), in: motionModes)
        keymap.bind("gg", to: DocumentStartMotion(), in: motionModes)
        keymap.bind("G", to: DocumentEndMotion(), in: motionModes)

        // Scroll
        keymap.bind("ctrl-d", to: HalfPageDownMotion(), in: .normal)
        keymap.bind("ctrl-u", to: HalfPageUpMotion(), in: .normal)
        keymap.bind("ctrl-f", to: PageDownMotion(), in: .normal)
        keymap.bind("ctrl-b", to: PageUpMotion(), in: .normal)

        // Operators
        keymap.bind("d", to: DeleteOperator(), in: .normal)
        keymap.bind("dd", to: DeleteLineOperator(), in: .normal)
        keymap.bind("D", to: DeleteToEndOfLineOperator(), in: .normal)
        keymap.bind("y", to: YankOperator(), in: .normal)
        keymap.bind("yy", to: YankLineOperator(), in: .normal)
        keymap.bind("c", to: ChangeOperator(), in: .normal)
        keymap.bind("cc", to: ChangeLineOperator(), in: .normal)
        keymap.bind("C", to: ChangeToEndOfLineOperator(), in: .normal)

        // Simple edits
        keymap.bind("x", to: DeleteCharCommand(), in: .normal)
        keymap.bind("s", to: SubstituteCharCommand(), in: .normal)
        keymap.bind("S", to: SubstituteLineCommand(), in: .normal)
        keymap.bind("p", to: PutAfterCommand(), in: .normal)
        keymap.bind("P", to: PutBeforeCommand(), in: .normal)
        keymap.bind("J", to: JoinLinesCommand(), in: .normal)

        // Undo/Redo
        keymap.bind("u", to: UndoCommand(), in: .normal)
        keymap.bind("ctrl-r", to: RedoCommand(), in: .normal)

        // Search
        keymap.bind("/", to: SearchForwardCommand(), in: .normal)
        keymap.bind("?", to: SearchBackwardCommand(), in: .normal)
        keymap.bind("n", to: SearchNextCommand(), in: .normal)
        keymap.bind("N", to: SearchPrevCommand(), in: .normal)

        // Text objects (operator pending mode)
        keymap.bind("iw", to: InnerWordTextObject(), in: .operatorPending)
        keymap.bind("aw", to: AWordTextObject(), in: .operatorPending)
        keymap.bind("i\"", to: InnerQuoteTextObject(quote: "\""), in: .operatorPending)
        keymap.bind("a\"", to: AQuoteTextObject(quote: "\""), in: .operatorPending)
        keymap.bind("i'", to: InnerQuoteTextObject(quote: "'"), in: .operatorPending)
        keymap.bind("a'", to: AQuoteTextObject(quote: "'"), in: .operatorPending)
        keymap.bind("i(", to: InnerBracketTextObject(open: "(", close: ")", key: "("), in: .operatorPending)
        keymap.bind("a(", to: ABracketTextObject(open: "(", close: ")", key: "("), in: .operatorPending)
        keymap.bind("i)", to: InnerBracketTextObject(open: "(", close: ")", key: ")"), in: .operatorPending)
        keymap.bind("a)", to: ABracketTextObject(open: "(", close: ")", key: ")"), in: .operatorPending)
        keymap.bind("i[", to: InnerBracketTextObject(open: "[", close: "]", key: "["), in: .operatorPending)
        keymap.bind("a[", to: ABracketTextObject(open: "[", close: "]", key: "["), in: .operatorPending)
        keymap.bind("i{", to: InnerBracketTextObject(open: "{", close: "}", key: "{"), in: .operatorPending)
        keymap.bind("a{", to: ABracketTextObject(open: "{", close: "}", key: "{"), in: .operatorPending)

        // Visual mode
        keymap.bind("d", to: VisualDeleteCommand(), in: [.visual, .visualLine])
        keymap.bind("x", to: VisualDeleteCommand(), in: [.visual, .visualLine])
        keymap.bind("y", to: VisualYankCommand(), in: [.visual, .visualLine])
        keymap.bind("c", to: VisualChangeCommand(), in: [.visual, .visualLine])
    }
}
