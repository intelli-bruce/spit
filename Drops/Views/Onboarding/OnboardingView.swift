import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentPage = 0
    @State private var permissionGranted = false
    @State private var showPermissionDeniedAlert = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage
                    .tag(0)

                permissionPage
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            pageIndicator
                .padding(.bottom, 20)

            actionButton
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
        .alert("마이크 권한 필요", isPresented: $showPermissionDeniedAlert) {
            Button("설정으로 이동") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("나중에", role: .cancel) {
                completeOnboarding()
            }
        } message: {
            Text("음성 메모를 녹음하려면 마이크 권한이 필요합니다. 설정에서 권한을 허용해주세요.")
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse)
                .padding(30)
                .glassEffect(.regular.tint(.accentColor))

            VStack(spacing: 12) {
                Text("Drops")
                    .font(.largeTitle.weight(.bold))

                Text("생각을 뱉어내세요")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("떠오르는 생각을 바로 녹음하고,\n자동으로 텍스트로 변환됩니다.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var permissionPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .padding(30)
                .glassEffect(.regular.tint(.accentColor))

            VStack(spacing: 12) {
                Text("마이크 권한")
                    .font(.title.weight(.bold))

                Text("음성 메모를 녹음하려면\n마이크 접근 권한이 필요합니다.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "lock.shield", text: "녹음은 기기에만 저장됩니다")
                featureRow(icon: "waveform", text: "텍스트 변환만을 위해 사용됩니다")
                featureRow(icon: "hand.raised", text: "언제든 설정에서 변경 가능합니다")
            }
            .padding()
            .glassEffect()
            .padding(.top, 20)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var actionButton: some View {
        Button {
            handleAction()
        } label: {
            Text(currentPage == 0 ? "다음" : "시작하기")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .glassEffect(.regular.tint(.accentColor))
        }
    }

    private func handleAction() {
        if currentPage == 0 {
            withAnimation {
                currentPage = 1
            }
        } else {
            requestPermission()
        }
    }

    private func requestPermission() {
        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            await MainActor.run {
                if granted {
                    completeOnboarding()
                } else {
                    showPermissionDeniedAlert = true
                }
            }
        }
    }

    private func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

#Preview {
    OnboardingView()
}
