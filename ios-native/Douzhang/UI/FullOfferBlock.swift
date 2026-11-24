import Accessibility
import SwiftUI
import VeggieKit

/// 完整版要決定的那一塊：訊息、付一次與價格、主按鈕、先不用、恢復購買（準則 6-20，只寫這一份）。
/// 什麼時候講什麼、主按鈕是哪一顆由 Core/FullOffer.swift 決定，這裡照著畫。
struct FullOfferBlock: View {
    /// 剛做完的那一次。不放在這一頁：買到一半關掉頁，結果才有地方講
    @Binding var note: FullNote?
    var onClose: () -> Void

    @Environment(Purchases.self) private var shop

    var body: some View {
        let offer = FullOffer.now(shop.shelf, note: note)
        VStack(spacing: .zero) {
            if let line = offer.line {
                told(line, isProblem: offer.isProblem)
            }
            if offer.showsPrice {
                price
                    .padding(.bottom, Tokens.Layout.group)
            }
            BigButton(label: Words.fullMain(offer.main), waiting: offer.isWaiting) {
                press(offer.main)
            }
            .minimumScaleFactor(Tokens.Full.shrink)
            choices(offer)
                .padding(.top, Tokens.Layout.item)
        }
        .padding(.horizontal, Tokens.Layout.screenMargin)
        .padding(.top, Tokens.Layout.group)
        .modifier(FullEffects(note: note, line: offer.line))
    }

    /// 高度最後才分到它：字放到最大時只有這句自己捲，價格與購買鈕不會被擠掉（沒看到價格不准付錢）。
    private func told(_ line: String, isProblem: Bool) -> some View {
        let words = FullLine(text: line, isProblem: isProblem)
            .frame(maxWidth: .infinity, alignment: .leading)
        return ViewThatFits(in: .vertical) {
            words
            ScrollView { words }
        }
        .padding(.bottom, Tokens.Layout.group)
        .layoutPriority(-1)
    }

    /// 價格跟旁邊的字一樣大。還沒讀到就空著，不寫任何數字。不放進會捲的地方。
    private var price: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: .zero) {
                Text(Words.fullOnce)
                Spacer(minLength: Tokens.Layout.group)
                amount
            }
            VStack(alignment: .leading, spacing: Tokens.Layout.tight) {
                Text(Words.fullOnce)
                amount
            }
        }
        .font(Tokens.Fonts.body)
        .foregroundStyle(Tokens.Colors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var amount: some View {
        if let price = shop.price {
            Text(price).monospacedDigit()
        }
    }

    /// 兩顆分在左右兩端；字放大到一排放不下就上下排。沒有的時候位子留著，主按鈕不會跳。
    private func choices(_ offer: FullOffer) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: .zero) {
                decline(offer)
                Spacer(minLength: Tokens.Layout.group)
                restoring(offer)
            }
            VStack(alignment: .leading, spacing: .zero) {
                decline(offer)
                restoring(offer)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Tokens.Shape.tapMin, alignment: .leading)
    }

    @ViewBuilder
    private func decline(_ offer: FullOffer) -> some View {
        if offer.showsDecline {
            TextButton(label: Words.fullDecline, tone: .plain, flush: true, action: onClose)
        }
    }

    @ViewBuilder
    private func restoring(_ offer: FullOffer) -> some View {
        if offer.showsRestore {
            TextButton(
                label: VeggieText.restore,
                tone: shop.isBusy ? .secondary : .plain,
                flush: true,
                action: restore
            )
            .disabled(shop.isBusy)
        }
    }

    private func press(_ main: FullOffer.Main) {
        switch main {
        case .buy: buy()
        case .restore: restore()
        case .done: onClose()
        case .readPrice:
            note = nil
            Task { await shop.loadPrice() }
        case .readingPrice, .buying, .restoring: break
        }
    }

    private func buy() {
        note = nil
        Task {
            let result = await shop.buy()
            note = FullNote(result: .bought(result))
        }
    }

    private func restore() {
        note = note?.kept(shop.status)
        Task {
            let result = await shop.restore()
            note = FullNote.after(note, .restored(result))
        }
    }
}

/// 買與恢復的那一句：告知用灰字，出了問題才用紅字（準則 6-18）。
struct FullLine: View {
    var text: String
    var isProblem: Bool

    var body: some View {
        Text(text)
            .font(Tokens.Fonts.sub)
            .foregroundStyle(isProblem ? Tokens.Colors.danger : Tokens.Colors.textSecondary)
    }
}

/// 有結果的那一刻：震一下，讀屏念那一句。
/// isOn 是這一處正看得到：付費頁蓋著的時候，底下設定頁不重複震、不重複念。
struct FullEffects: ViewModifier {
    var note: FullNote?
    var line: String?
    var isOn = true

    private struct Heard: Equatable {
        var id: UUID?
        var line: String?
    }

    func body(content: Content) -> some View {
        content
            .haptic(.success, trigger: note) { isOn && $0?.saysOwned == true }
            .haptic(.error, trigger: note) { isOn && $0?.isProblem == true }
            .onChange(of: Heard(id: note?.id, line: line)) { _, next in
                guard isOn, let said = next.line else { return }
                speak(said)
            }
    }

    /// 按鈕的字同時也換了：不排前面的話，讀屏念到一半就被按鈕的新名字蓋掉。
    private func speak(_ text: String) {
        var words = AttributedString(text)
        words.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(words).post()
    }
}
