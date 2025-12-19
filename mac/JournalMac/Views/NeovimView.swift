import SwiftUI
import AppKit
import MessagePack

/// Neovim을 임베드한 NSView
class NeovimNSView: NSView {
    private var nvim: NeovimProcess?
    private var grid: [[Cell]] = []
    private var cursorRow: Int = 0
    private var cursorCol: Int = 0
    private var gridWidth: Int = 80
    private var gridHeight: Int = 24
    private var cellWidth: CGFloat = 8
    private var cellHeight: CGFloat = 16
    private var defaultFg: NSColor = .textColor
    private var defaultBg: NSColor = .textBackgroundColor
    private var hlAttrs: [Int: HighlightAttr] = [:]
    private var currentHlId: Int = 0
    private var mode: String = "n"

    var font: NSFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular) {
        didSet {
            updateCellSize()
            needsDisplay = true
        }
    }

    var onModeChange: ((String) -> Void)?
    var onFileChange: ((String) -> Void)?

    struct Cell {
        var char: String = " "
        var hlId: Int = 0
    }

    struct HighlightAttr {
        var foreground: NSColor?
        var background: NSColor?
        var bold: Bool = false
        var italic: Bool = false
        var underline: Bool = false
        var reverse: Bool = false
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        updateCellSize()
        initGrid()
    }

    private func updateCellSize() {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let size = "M".size(withAttributes: attrs)
        cellWidth = ceil(size.width)
        cellHeight = ceil(size.height * 1.2)
    }

    private func initGrid() {
        grid = Array(repeating: Array(repeating: Cell(), count: gridWidth), count: gridHeight)
    }

    // MARK: - Neovim Connection

    func connect() async throws {
        let nvim = NeovimProcess()
        self.nvim = nvim

        await nvim.setRedrawHandler { [weak self] events in
            Task { @MainActor in
                self?.handleRedraw(events)
            }
        }

        try await nvim.start()

        // Resize to current view size
        let cols = Int(bounds.width / cellWidth)
        let rows = Int(bounds.height / cellHeight)
        if cols > 0 && rows > 0 {
            gridWidth = cols
            gridHeight = rows
            initGrid()
            try await nvim.resizeUI(width: cols, height: rows)
        }
    }

    func disconnect() {
        Task {
            await nvim?.stop()
        }
        nvim = nil
    }

    // MARK: - File Operations

    func openFile(_ path: String) async throws {
        try await nvim?.openFile(path)
    }

    func saveFile() async throws {
        try await nvim?.saveFile()
    }

    // MARK: - Redraw Handling

    private func handleRedraw(_ events: [[MessagePackValue]]) {
        for event in events {
            guard !event.isEmpty,
                  case let .string(name) = event[0] else { continue }

            let args = Array(event.dropFirst())

            switch name {
            case "grid_resize":
                handleGridResize(args)
            case "grid_clear":
                handleGridClear()
            case "grid_line":
                handleGridLine(args)
            case "grid_cursor_goto":
                handleCursorGoto(args)
            case "hl_attr_define":
                handleHlAttrDefine(args)
            case "default_colors_set":
                handleDefaultColors(args)
            case "mode_change":
                handleModeChange(args)
            case "flush":
                needsDisplay = true
            default:
                break
            }
        }
    }

    private func handleGridResize(_ args: [MessagePackValue]) {
        for arg in args {
            guard case let .array(arr) = arg,
                  arr.count >= 3,
                  case let .int(width) = arr[1],
                  case let .int(height) = arr[2] else { continue }

            gridWidth = Int(width)
            gridHeight = Int(height)
            initGrid()
        }
    }

    private func handleGridClear() {
        for row in 0..<gridHeight {
            for col in 0..<gridWidth {
                grid[row][col] = Cell()
            }
        }
    }

    private func handleGridLine(_ args: [MessagePackValue]) {
        for arg in args {
            guard case let .array(arr) = arg,
                  arr.count >= 4,
                  case let .int(row) = arr[1],
                  case let .int(colStart) = arr[2],
                  case let .array(cells) = arr[3] else { continue }

            var col = Int(colStart)
            let rowIdx = Int(row)

            guard rowIdx >= 0 && rowIdx < gridHeight else { continue }

            for cellData in cells {
                guard case let .array(cellArr) = cellData,
                      !cellArr.isEmpty,
                      case let .string(char) = cellArr[0] else { continue }

                // Update highlight if provided
                if cellArr.count >= 2, case let .int(hlId) = cellArr[1] {
                    currentHlId = Int(hlId)
                }

                // Repeat count
                var repeat_ = 1
                if cellArr.count >= 3, case let .int(rep) = cellArr[2] {
                    repeat_ = Int(rep)
                }

                for _ in 0..<repeat_ {
                    if col < gridWidth {
                        grid[rowIdx][col] = Cell(char: char, hlId: currentHlId)
                        col += 1
                    }
                }
            }
        }
    }

    private func handleCursorGoto(_ args: [MessagePackValue]) {
        for arg in args {
            guard case let .array(arr) = arg,
                  arr.count >= 3,
                  case let .int(row) = arr[1],
                  case let .int(col) = arr[2] else { continue }

            cursorRow = Int(row)
            cursorCol = Int(col)
        }
    }

    private func handleHlAttrDefine(_ args: [MessagePackValue]) {
        for arg in args {
            guard case let .array(arr) = arg,
                  arr.count >= 2,
                  case let .int(id) = arr[0],
                  case let .map(attrs) = arr[1] else { continue }

            var hlAttr = HighlightAttr()

            if let fg = attrs[.string("foreground")], case let .int(val) = fg {
                hlAttr.foreground = colorFromInt(Int(val))
            }
            if let bg = attrs[.string("background")], case let .int(val) = bg {
                hlAttr.background = colorFromInt(Int(val))
            }
            if let bold = attrs[.string("bold")], case .bool(true) = bold {
                hlAttr.bold = true
            }
            if let italic = attrs[.string("italic")], case .bool(true) = italic {
                hlAttr.italic = true
            }
            if let underline = attrs[.string("underline")], case .bool(true) = underline {
                hlAttr.underline = true
            }
            if let reverse = attrs[.string("reverse")], case .bool(true) = reverse {
                hlAttr.reverse = true
            }

            hlAttrs[Int(id)] = hlAttr
        }
    }

    private func handleDefaultColors(_ args: [MessagePackValue]) {
        for arg in args {
            guard case let .array(arr) = arg,
                  arr.count >= 3,
                  case let .int(fg) = arr[0],
                  case let .int(bg) = arr[1] else { continue }

            defaultFg = colorFromInt(Int(fg))
            defaultBg = colorFromInt(Int(bg))
            layer?.backgroundColor = defaultBg.cgColor
        }
    }

    private func handleModeChange(_ args: [MessagePackValue]) {
        for arg in args {
            guard case let .array(arr) = arg,
                  !arr.isEmpty,
                  case let .string(modeName) = arr[0] else { continue }

            mode = modeName
            onModeChange?(modeName)
        }
    }

    private func colorFromInt(_ val: Int) -> NSColor {
        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw background
        context.setFillColor(defaultBg.cgColor)
        context.fill(bounds)

        // Draw cells
        for row in 0..<min(gridHeight, grid.count) {
            for col in 0..<min(gridWidth, grid[row].count) {
                let cell = grid[row][col]
                let rect = cellRect(row: row, col: col)

                // Get highlight attributes
                let hlAttr = hlAttrs[cell.hlId]
                var fg = hlAttr?.foreground ?? defaultFg
                var bg = hlAttr?.background ?? defaultBg

                if hlAttr?.reverse == true {
                    swap(&fg, &bg)
                }

                // Draw background
                if bg != defaultBg {
                    context.setFillColor(bg.cgColor)
                    context.fill(rect)
                }

                // Draw character
                if cell.char != " " {
                    var fontToUse = font
                    if hlAttr?.bold == true {
                        fontToUse = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)
                    }
                    if hlAttr?.italic == true {
                        // Use italic variant if available
                        if let italicFont = NSFont(descriptor: fontToUse.fontDescriptor.withSymbolicTraits(.italic), size: font.pointSize) {
                            fontToUse = italicFont
                        }
                    }

                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: fontToUse,
                        .foregroundColor: fg
                    ]

                    let str = NSAttributedString(string: cell.char, attributes: attrs)
                    str.draw(at: NSPoint(x: rect.minX, y: rect.minY + (cellHeight - font.pointSize) / 2))
                }

                // Draw underline
                if hlAttr?.underline == true {
                    context.setStrokeColor(fg.cgColor)
                    context.setLineWidth(1)
                    context.move(to: CGPoint(x: rect.minX, y: rect.minY + 1))
                    context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 1))
                    context.strokePath()
                }
            }
        }

        // Draw cursor
        let cursorRect = cellRect(row: cursorRow, col: cursorCol)
        if mode == "n" || mode == "normal" {
            // Block cursor for normal mode
            context.setFillColor(NSColor.systemGreen.withAlphaComponent(0.7).cgColor)
            context.fill(cursorRect)

            // Redraw character on cursor
            if cursorRow < grid.count && cursorCol < grid[cursorRow].count {
                let cell = grid[cursorRow][cursorCol]
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: defaultBg
                ]
                let str = NSAttributedString(string: cell.char, attributes: attrs)
                str.draw(at: NSPoint(x: cursorRect.minX, y: cursorRect.minY + (cellHeight - font.pointSize) / 2))
            }
        } else {
            // Bar cursor for insert mode
            context.setFillColor(NSColor.systemGreen.cgColor)
            context.fill(CGRect(x: cursorRect.minX, y: cursorRect.minY, width: 2, height: cellHeight))
        }
    }

    private func cellRect(row: Int, col: Int) -> CGRect {
        let y = bounds.height - CGFloat(row + 1) * cellHeight
        return CGRect(x: CGFloat(col) * cellWidth, y: y, width: cellWidth, height: cellHeight)
    }

    // MARK: - Input Handling

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let key = translateKey(event)
        Task {
            try? await nvim?.input(key)
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
        case 115: key = "<Home>"
        case 119: key = "<End>"
        case 116: key = "<PageUp>"
        case 121: key = "<PageDown>"
        case 117: key = "<Del>"
        default: break
        }

        // Add modifiers
        var prefix = ""
        if modifiers.contains(.control) {
            prefix += "C-"
        }
        if modifiers.contains(.option) {
            prefix += "M-"
        }
        if modifiers.contains(.shift) && key.count == 1 && key.first?.isLetter == true {
            key = key.uppercased()
        } else if modifiers.contains(.shift) && !key.hasPrefix("<") {
            prefix += "S-"
        }

        if !prefix.isEmpty && !key.hasPrefix("<") {
            key = "<\(prefix)\(key)>"
        } else if !prefix.isEmpty && key.hasPrefix("<") {
            key = "<\(prefix)\(key.dropFirst().dropLast())>"
        }

        return key
    }

    override func flagsChanged(with event: NSEvent) {
        // Handle modifier key changes if needed
    }

    // MARK: - Resize

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)

        let cols = Int(newSize.width / cellWidth)
        let rows = Int(newSize.height / cellHeight)

        if cols > 0 && rows > 0 && (cols != gridWidth || rows != gridHeight) {
            gridWidth = cols
            gridHeight = rows
            initGrid()

            Task {
                try? await nvim?.resizeUI(width: cols, height: rows)
            }
        }
    }
}

// MARK: - SwiftUI Wrapper

struct NeovimView: NSViewRepresentable {
    let filePath: String?
    @Binding var mode: String
    var onSave: (() -> Void)?

    func makeNSView(context: Context) -> NeovimNSView {
        let view = NeovimNSView()
        view.onModeChange = { newMode in
            DispatchQueue.main.async {
                self.mode = newMode
            }
        }

        Task {
            do {
                try await view.connect()
                if let path = filePath {
                    try await view.openFile(path)
                }
            } catch {
                print("Neovim connection error: \(error)")
            }
        }

        return view
    }

    func updateNSView(_ nsView: NeovimNSView, context: Context) {
        // Handle updates if needed
    }

    static func dismantleNSView(_ nsView: NeovimNSView, coordinator: ()) {
        nsView.disconnect()
    }
}
