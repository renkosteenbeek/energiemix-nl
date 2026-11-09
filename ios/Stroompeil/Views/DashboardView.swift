import SwiftUI

struct DashboardView: View {
    let model: DashboardModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content(screenWidth: proxy.size.width)
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 64)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await model.refresh() }
            .overlay(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: Palette.background, location: 0),
                        .init(color: Palette.background, location: 0.55),
                        .init(color: Palette.background.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: proxy.safeAreaInsets.top + 8)
                .offset(y: -proxy.safeAreaInsets.top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .task { model.start() }
        .task { await tickEveryHour() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.sceneBecameActive() }
        }
        .onOpenURL { url in
            if url.scheme == AppConfig.nowDeepLink.scheme { model.jumpToNow() }
        }
    }

    @ViewBuilder
    private func content(screenWidth: CGFloat) -> some View {
        if let mix = model.displayedMix {
            heroSection(mix: mix, screenWidth: screenWidth)
                .padding(.top, 24)
                .padding(.bottom, 16)

            RhythmView(model: model)
                .padding(.top, 32)
                .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("Duiding")
                StoryView(text: model.story, phase: model.storyPhase, onRetry: model.retryStory)
            }
            .padding(.vertical, 16)

            if model.mixError == nil, mix.hasData {
                let topSources = mix.sources.filter { $0.percentage >= 1 }.prefix(3)
                if !topSources.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel("Grootste bronnen")
                        TopSourcesView(sources: Array(topSources))
                    }
                    .padding(.vertical, 16)
                }

                AllSourcesView(sources: mix.sources)
            }
        } else if let error = model.mixError {
            StatusCard(
                title: "Geen gegevens",
                message: error,
                retry: model.retry
            )
            .padding(.top, 24)
        } else {
            LoadingSkeleton()
                .padding(.top, 24)
        }
    }

    @ViewBuilder
    private func heroSection(mix: Mix, screenWidth: CGFloat) -> some View {
        if let error = model.mixError {
            StatusCard(
                title: "\(DutchFormat.compact(model.focusHour)) kon niet worden geladen",
                message: error,
                retry: model.retry
            )
        } else if !mix.hasData {
            StatusCard(
                title: "Geen data voor \(DutchFormat.compact(mix.focusTime))",
                message: "Het Nationaal Energie Dashboard heeft voor dit uur nog geen cijfers.",
                retry: nil
            )
        } else {
            HeroCard(
                mix: mix,
                nowHour: model.nowHour,
                isLoading: model.isLoadingMix,
                screenWidth: screenWidth
            )
        }
    }

    private func tickEveryHour() async {
        while !Task.isCancelled {
            let next = Date().flooredToHour.addingHours(1).addingTimeInterval(20)
            try? await Task.sleep(for: .seconds(max(1, next.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            model.clockTick()
        }
    }
}
