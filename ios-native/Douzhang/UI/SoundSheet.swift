import SwiftUI

/// 白噪音半頁：選關／雨／柴火，選了聲音才出現音量三段。改了立刻存、立刻生效，「好」只是關。
/// 待機時打開可以邊選邊聽；計時中本來就在播。
struct SoundSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let kinds = AmbienceKind.allCases.map {
        SegmentOption(value: $0, label: Words.ambienceKind($0))
    }

    private let levels = AmbienceLevel.allCases.map {
        SegmentOption(value: $0, label: Words.ambienceLevel($0))
    }

    var body: some View {
        let settings = model.state.settings
        SheetCard(title: Words.ambienceTitle) {
            Segmented(options: kinds, value: settings.ambience) { kind in
                model.update { $0.ambience = kind }
            }
            if settings.ambience != .off {
                caption(Words.ambienceVolumeCap)
                Segmented(options: levels, value: settings.ambienceVolume) { level in
                    model.update { $0.ambienceVolume = level }
                }
                .padding(.top, Tokens.Space.s)
            }
            caption(Words.ambienceSub)
            BigButton(label: Words.confirm) { dismiss() }
                .padding(.top, Tokens.Space.l)
        }
        .onAppear { model.previewAmbience(true) }
        .onDisappear { model.previewAmbience(false) }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Fonts.caption)
            .foregroundStyle(Tokens.Colors.textSecondary)
            .padding(.top, Tokens.Space.l)
    }
}
