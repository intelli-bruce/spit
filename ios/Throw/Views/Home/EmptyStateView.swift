import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .padding(24)
                .background(.ultraThinMaterial, in: Circle())

            VStack(spacing: 8) {
                Text("메모가 없습니다")
                    .font(.title2.weight(.semibold))

                Text("아래 버튼을 눌러 첫 번째 음성 메모를 만들어보세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    EmptyStateView()
}
