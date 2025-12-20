import SwiftUI
import SwiftData

struct BlockEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: Note
    @Binding var isEditing: Bool
    let onSave: () -> Void

    @State private var focusedBlockId: UUID?

    var sortedBlocks: [NoteBlock] {
        note.rootBlocks.sorted { $0.position < $1.position }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(sortedBlocks) { block in
                BlockRowView(
                    block: block,
                    isFocused: focusedBlockId == block.id,
                    onFocus: { focusedBlockId = block.id },
                    onCreateBlock: { textAfterCursor in
                        createBlock(after: block, withContent: textAfterCursor)
                    },
                    onDeleteBlock: {
                        deleteBlock(block)
                    },
                    onMergeWithPrevious: {
                        mergeWithPrevious(block)
                    },
                    onNavigateUp: {
                        navigateToPreviousBlock(from: block)
                    },
                    onNavigateDown: {
                        navigateToNextBlock(from: block)
                    },
                    onContentChange: {
                        markPending(block)
                    },
                    onEscape: {
                        exitEditing()
                    },
                    onPasteImage: { imageData in
                        createImageBlock(after: block, imageData: imageData)
                    }
                )
                .id(block.id)
            }
        }
        .onAppear {
            if focusedBlockId == nil, let first = sortedBlocks.first {
                focusedBlockId = first.id
            }
        }
    }

    // MARK: - Block Operations

    private func createBlock(after currentBlock: NoteBlock, withContent content: String) {
        let newPosition = currentBlock.position + 1

        // Shift subsequent blocks
        for block in sortedBlocks where block.position >= newPosition {
            block.position += 1
            block.syncStatus = .pending
        }

        // Create new block
        let newBlock = NoteBlock(
            note: note,
            type: .text,
            content: content,
            position: newPosition
        )
        modelContext.insert(newBlock)
        note.blocks.append(newBlock)

        try? modelContext.save()
        focusedBlockId = newBlock.id
    }

    private func deleteBlock(_ block: NoteBlock) {
        guard sortedBlocks.count > 1 else { return } // Keep at least one block

        let prevBlock = sortedBlocks.first { $0.position < block.position }
        let nextBlock = sortedBlocks.first { $0.position > block.position }

        // Remove block
        note.blocks.removeAll { $0.id == block.id }
        modelContext.delete(block)

        // Recalculate positions
        recalculatePositions()
        try? modelContext.save()

        // Focus previous or next block
        focusedBlockId = prevBlock?.id ?? nextBlock?.id
    }

    private func mergeWithPrevious(_ block: NoteBlock) {
        guard let prevBlock = sortedBlocks.first(where: { $0.position < block.position }),
              prevBlock.type == .text && block.type == .text else { return }

        // Merge content
        let mergedContent = (prevBlock.content ?? "") + (block.content ?? "")
        prevBlock.content = mergedContent
        prevBlock.updatedAt = Date()
        prevBlock.syncStatus = .pending

        // Delete current block
        note.blocks.removeAll { $0.id == block.id }
        modelContext.delete(block)

        recalculatePositions()
        try? modelContext.save()

        focusedBlockId = prevBlock.id
    }

    private func navigateToPreviousBlock(from block: NoteBlock) {
        if let prevBlock = sortedBlocks.last(where: { $0.position < block.position }) {
            focusedBlockId = prevBlock.id
        } else {
            // Exit editing mode when at the first block
            isEditing = false
            onSave()
        }
    }

    private func navigateToNextBlock(from block: NoteBlock) {
        if let nextBlock = sortedBlocks.first(where: { $0.position > block.position }) {
            focusedBlockId = nextBlock.id
        }
    }

    private func markPending(_ block: NoteBlock) {
        block.updatedAt = Date()
        block.syncStatus = .pending
        note.updatedAt = Date()
        note.syncStatus = .pending
    }

    private func recalculatePositions() {
        for (index, block) in sortedBlocks.enumerated() {
            if block.position != index {
                block.position = index
                block.syncStatus = .pending
            }
        }
    }

    private func exitEditing() {
        onSave()
        isEditing = false
    }

    private func createImageBlock(after currentBlock: NoteBlock, imageData: Data) {
        print("[Paste] createImageBlock called with \(imageData.count) bytes")

        // Save image to local storage
        let fileName = "\(UUID().uuidString).png"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)

        print("[Paste] Saving to: \(fileURL.path)")

        do {
            try imageData.write(to: fileURL)
            print("[Paste] Image saved successfully")
        } catch {
            print("[Paste] Failed to save image: \(error)")
            return
        }

        let newPosition = currentBlock.position + 1

        // Shift subsequent blocks
        for block in sortedBlocks where block.position >= newPosition {
            block.position += 1
            block.syncStatus = .pending
        }

        // Create new image block
        let imageBlock = NoteBlock(
            note: note,
            type: .image,
            storagePath: "local://\(fileName)",
            position: newPosition
        )
        modelContext.insert(imageBlock)
        note.blocks.append(imageBlock)

        try? modelContext.save()
        focusedBlockId = imageBlock.id
        print("[Paste] Image block created with id: \(imageBlock.id)")
    }
}

// MARK: - Block Row View

struct BlockRowView: View {
    @Bindable var block: NoteBlock
    let isFocused: Bool
    let onFocus: () -> Void
    let onCreateBlock: (String) -> Void
    let onDeleteBlock: () -> Void
    let onMergeWithPrevious: () -> Void
    let onNavigateUp: () -> Void
    let onNavigateDown: () -> Void
    let onContentChange: () -> Void
    let onEscape: () -> Void
    let onPasteImage: (Data) -> Void

    var body: some View {
        Group {
            switch block.type {
            case .text:
                TextBlockView(
                    block: block,
                    isFocused: isFocused,
                    onFocus: onFocus,
                    onCreateBlock: onCreateBlock,
                    onDeleteBlock: onDeleteBlock,
                    onMergeWithPrevious: onMergeWithPrevious,
                    onNavigateUp: onNavigateUp,
                    onNavigateDown: onNavigateDown,
                    onContentChange: onContentChange,
                    onEscape: onEscape,
                    onPasteImage: onPasteImage
                )
            case .image, .audio, .video:
                MediaBlockView(block: block, isFocused: isFocused)
                    .onTapGesture { onFocus() }
            }
        }
    }
}
