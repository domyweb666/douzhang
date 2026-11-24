import SwiftUI
import VeggieKit

/// 清除所有資料要問的框：問兩次、兩次的按鈕字不一樣、第一次附匯出（準則 3-3）；
/// iCloud 可能有一份的，中間多問一次留不留（準則 5-26）。
/// 下一個框、分享選單等這個框收掉那一拍過了再開：同一拍開，系統會吞掉。
struct WipeAsk: ViewModifier {
    @Binding var isAsking: Bool
    @Environment(AppModel.self) private var model
    @State private var askingCloud = false
    @State private var askingAgain = false
    @State private var erasesCloud = false

    func body(content: Content) -> some View {
        content
            .alert(Words.wipeTitle, isPresented: $isAsking) {
                Button(Words.wipeExportFirst, action: exportFirst)
                Button(VeggieText.eraseAll, role: .destructive, action: askNext)
                Button(Words.cancel, role: .cancel) {}
            }
            .alert(Words.cloudEraseTitle, isPresented: $askingCloud) {
                Button(Words.cloudKeep) { askLast(erasing: false) }
                Button(Words.cloudErase, role: .destructive) { askLast(erasing: true) }
                Button(Words.cancel, role: .cancel) {}
            } message: {
                Text(Words.cloudEraseNote)
            }
            .alert(Words.wipeAgainTitle, isPresented: $askingAgain) {
                Button(Words.wipeAgainOk, role: .destructive) {
                    model.wipeAll(erasingCloud: erasesCloud)
                }
                Button(Words.cancel, role: .cancel) {}
            }
    }

    private func exportFirst() {
        Task { model.exportBackup() }
    }

    private func askNext() {
        Task {
            erasesCloud = false
            if model.cloud.hasCopy {
                askingCloud = true
            } else {
                askingAgain = true
            }
        }
    }

    /// 雲端那份先記著答案，最後一個框按了才真的刪。
    private func askLast(erasing: Bool) {
        Task {
            erasesCloud = erasing
            askingAgain = true
        }
    }
}
