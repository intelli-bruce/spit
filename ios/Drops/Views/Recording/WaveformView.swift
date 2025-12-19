import SwiftUI

struct WaveformView: View {
    let levels: [Float]
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 2
    var minHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(displayLevels(for: geometry.size.width), id: \.offset) { item in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(Color.accentColor)
                        .frame(
                            width: barWidth,
                            height: max(minHeight, CGFloat(item.level) * geometry.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func displayLevels(for width: CGFloat) -> [(offset: Int, level: Float)] {
        let maxBars = Int(width / (barWidth + spacing))
        let displayCount = min(levels.count, maxBars)

        if levels.isEmpty {
            return (0..<maxBars).map { ($0, 0.1) }
        }

        let startIndex = max(0, levels.count - displayCount)
        return levels.suffix(displayCount).enumerated().map { ($0.offset, $0.element) }
    }
}

struct StaticWaveformView: View {
    let audioURL: URL?
    var barWidth: CGFloat = 2
    var spacing: CGFloat = 1
    var barCount: Int = 30

    @State private var levels: [Float] = []

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(
                            width: barWidth,
                            height: barHeight(for: index, maxHeight: geometry.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            generateRandomLevels()
        }
    }

    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        guard index < levels.count else {
            return maxHeight * 0.3
        }
        return max(4, CGFloat(levels[index]) * maxHeight)
    }

    private func generateRandomLevels() {
        levels = (0..<barCount).map { _ in Float.random(in: 0.2...1.0) }
    }
}

#Preview {
    VStack(spacing: 20) {
        WaveformView(levels: (0..<20).map { _ in Float.random(in: 0.1...1.0) })
            .frame(height: 50)
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

        StaticWaveformView(audioURL: nil)
            .frame(height: 30)
            .padding()
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding()
}
