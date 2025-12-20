import SwiftUI
import AppKit

struct MediaBlockView: View {
    @Bindable var block: NoteBlock
    let isFocused: Bool

    var body: some View {
        Group {
            switch block.type {
            case .image:
                ImageBlockContent(block: block)
            case .audio:
                AudioBlockContent(block: block)
            case .video:
                VideoBlockContent(block: block)
            default:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Image Block

struct ImageBlockContent: View {
    let block: NoteBlock

    var body: some View {
        Group {
            if let url = block.localMediaURL, let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
            } else {
                PlaceholderView(
                    icon: "photo",
                    text: "Image",
                    storagePath: block.storagePath
                )
            }
        }
    }
}

// MARK: - Audio Block

struct AudioBlockContent: View {
    let block: NoteBlock
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Audio")
                    .font(.caption.weight(.medium))
                if let path = block.storagePath {
                    Text(URL(string: path)?.lastPathComponent ?? "audio.m4a")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Waveform placeholder
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2, height: CGFloat.random(in: 8...24))
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private func togglePlayback() {
        isPlaying.toggle()
        // TODO: Implement actual audio playback
    }
}

// MARK: - Video Block

struct VideoBlockContent: View {
    let block: NoteBlock

    var body: some View {
        ZStack {
            // Thumbnail placeholder
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .aspectRatio(16/9, contentMode: .fit)
                .frame(maxHeight: 200)

            // Play button overlay
            Image(systemName: "play.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.8))

            // Duration badge
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("0:00")
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.6))
                        .foregroundStyle(.white)
                        .cornerRadius(4)
                        .padding(8)
                }
            }
        }
        .cornerRadius(8)
    }
}

// MARK: - Placeholder View

struct PlaceholderView: View {
    let icon: String
    let text: String
    let storagePath: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let path = storagePath {
                Text(URL(string: path)?.lastPathComponent ?? "")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
