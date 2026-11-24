import SwiftUI
import VeggieKit

/// 設定頁最下面：「關於」那一區，加上全家共用的頁尾。
/// 沒有開源授權那列：程式只用自家的 VeggieKit，背景音是 CC0，沒有要附授權全文的東西。
struct SettingsAbout: View {
    @State private var showingFamily = false
    @State private var notice: String?

    private let config = VeggieConfig.douzhang

    var body: some View {
        // VeggieFooter 自己上面留 24，再加這裡的 section，就是 Layout.footerTop
        VStack(spacing: Tokens.Layout.section) {
            rows
            VeggieFooter(config: config, logo: Image("AppLogo")) { text in
                notice = text
            }
            .overlay(alignment: .bottom) { noticeLine }
        }
        .task(id: notice) { await clearNotice() }
        .sheet(isPresented: $showingFamily) { family }
    }

    private var rows: some View {
        SettingsSection(title: VeggieText.about) {
            SettingsRow(icon: "square.grid.2x2", label: VeggieText.family) {
                showingFamily = true
            }
            if let url = config.privacyURL {
                SettingsDivider()
                Link(destination: url) {
                    VeggieRow(icon: "hand.raised", title: VeggieText.privacy, accessory: .external)
                }
                .buttonStyle(FadeStyle())
            }
        }
    }

    /// 下一頁另外開一張、裡面自己一層導覽：推在左右滑的三頁裡，返回的手勢會跟換頁搶。
    private var family: some View {
        NavigationStack {
            VeggieFamilyView(config: config)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(Words.close) { showingFamily = false }
                            .foregroundStyle(Tokens.Colors.accentText)
                    }
                }
        }
        .veggieStyle(.douzhang)
    }

    /// 長按版本號、複製好之後的那一句。疊在頁尾的下緣，不推動版面。
    @ViewBuilder private var noticeLine: some View {
        if let notice {
            Text(notice)
                .font(Tokens.Fonts.caption)
                .foregroundStyle(Tokens.Colors.textSecondary)
        }
    }

    private func clearNotice() async {
        guard notice != nil else { return }
        try? await Task.sleep(for: .milliseconds(Params.noticeMs))
        notice = nil
    }
}
