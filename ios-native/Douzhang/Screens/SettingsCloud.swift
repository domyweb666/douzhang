import SwiftUI

/// 設定頁「資料」區第一列：iCloud 同步的開關（買了完整版才列，由 SettingsData 決定）。
/// 平常什麼都不說；出狀況那一句是下面的 SettingsCloudLine。
struct SettingsCloud: View {
    @Environment(AppModel.self) private var model
    @State private var askingErase = false

    var body: some View {
        SettingsToggle(
            icon: "icloud",
            label: Words.cloudRow,
            isOn: model.cloud.isOn,
            onChange: turn
        )
        // 正在刪雲端那份：刪完才准再打開
        .disabled(model.cloud.isErasing)
        .alert(Words.cloudEraseTitle, isPresented: $askingErase) {
            Button(Words.cloudErase, role: .destructive) {
                Task { await model.cloud.eraseCloud() }
            }
            Button(Words.cloudKeep, role: .cancel) {}
        } message: {
            Text(Words.cloudEraseOffNote)
        }
    }

    /// 關掉是馬上關，雲端那份再問。雲端沒有這支手機放的就不問。
    private func turn(_ isOn: Bool) {
        if isOn {
            model.cloud.turnOn()
        } else {
            model.cloud.turnOff()
            askingErase = model.cloud.hasCopy
        }
    }
}

/// 出狀況才有的那一句，在「資料」卡片下面。沒刪成的那兩句點了再刪一次；
/// 那兩句沒買也要看得到：他要刪的東西還在雲端。
struct SettingsCloudLine: View {
    @Environment(AppModel.self) private var model
    @Environment(Purchases.self) private var shop

    var body: some View {
        if let problem = shown {
            if isErase(problem) {
                Button {
                    Task { await model.cloud.eraseCloud() }
                } label: {
                    line(problem)
                        .frame(minHeight: Tokens.Shape.tapMin)
                        .contentShape(Rectangle())
                }
                .buttonStyle(FadeStyle())
            } else {
                line(problem)
            }
        }
    }

    private var shown: CloudProblem? {
        guard let problem = model.cloud.problem else { return nil }
        return shop.allows(.cloud) || isErase(problem) ? problem : nil
    }

    private func isErase(_ problem: CloudProblem) -> Bool {
        problem == .eraseFailed || problem == .eraseOther
    }

    /// 沒連上、自己選了先不要是狀態，灰字；做不成的才是紅字。
    private func line(_ problem: CloudProblem) -> some View {
        let isStatus = problem == .off || problem == .paused
        return Text(Words.cloudLine(problem))
            .font(Tokens.Fonts.sub)
            .foregroundStyle(isStatus ? Tokens.Colors.textSecondary : Tokens.Colors.danger)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Tokens.Layout.cardPad)
    }
}
