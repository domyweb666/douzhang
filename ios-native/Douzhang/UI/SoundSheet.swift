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
                Text(Words.ambienceVolumeCap)
                    .font(Tokens.Fonts.caption)
                    .foregroundStyle(Tokens.Colors.textSecondary)
                    .padding(.top, Tokens.Layout.section)
                Segmented(options: levels, value: settings.ambienceVolume) { level in
                    model.update { $0.ambienceVolume = level }
                }
                .padding(.top, Tokens.Layout.item)
            }
            BigButton(label: Words.confirm) { dismiss() }
                .padding(.top, Tokens.Layout.section)
        }
        .onAppear { model.previewAmbience(true) }
        .onDisappear { model.previewAmbience(false) }
    }
}
