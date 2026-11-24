import SwiftUI
import VeggieKit

/// 設定頁的「支援」那一區：意見回饋、評分（有 Apple ID 才出現）、分享給朋友。
/// 意見回饋只開寫信畫面，寄不寄由使用者自己按；信末只帶版本、iOS、機型、語言，不帶任何紀錄。
struct SettingsSupport: View {
    @Environment(\.openURL) private var openURL
    @State private var writingMail = false
    @State private var mailFailed = false

    private let config = VeggieConfig.douzhang

    var body: some View {
        SettingsSection(
            title: VeggieText.support,
            footer: mailFailed ? Words.noMailApp : nil
        ) {
            if let address = config.supportEmail {
                feedbackRow(address)
                SettingsDivider()
            }
            if let url = config.writeReviewURL {
                Link(destination: url) {
                    VeggieRow(icon: "star", title: VeggieText.rate, accessory: .external)
                }
                .buttonStyle(FadeStyle())
                SettingsDivider()
            }
            ShareLink(item: config.shareText) {
                VeggieRow(
                    icon: "square.and.arrow.up",
                    title: VeggieText.share,
                    accessory: .external
                )
            }
            .buttonStyle(FadeStyle())
        }
    }

    private func feedbackRow(_ address: String) -> some View {
        SettingsRow(icon: "envelope", label: VeggieText.feedback) { writeMail(to: address) }
            .sheet(isPresented: $writingMail) {
                FeedbackMailView(recipient: address, feedback: Feedback(config: config)) {
                    writingMail = false
                }
                .ignoresSafeArea()
            }
    }

    /// 手機設了郵件帳號就開系統寫信畫面；沒有就交給別的寄信 app，連那也沒有才說寄不出去。
    private func writeMail(to address: String) {
        mailFailed = false
        if Feedback.canUseMailSheet {
            writingMail = true
            return
        }
        guard let url = Feedback(config: config).mailtoURL(to: address) else {
            mailFailed = true
            return
        }
        openURL(url) { accepted in
            mailFailed = !accepted
        }
    }
}
