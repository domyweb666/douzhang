import SwiftUI

/// 循環的滾輪：系統的滾輪（滾動有系統的輕觸覺），滾過最後一個會接回第一個。
/// 哪一列是哪個值、值從外面被改掉時轉去哪一列，都在 Core/LoopWheelRules.swift。
struct LoopWheel: View {
    var label: String
    var values: [Double]
    @Binding var selection: Double
    var text: (Double) -> String

    /// 滾輪現在停在長條上的第幾列；還沒滾過是 nil，停在中間那一輪
    @State private var row: Int?

    private var selectedIndex: Int {
        values.firstIndex(of: selection) ?? 0
    }

    var body: some View {
        let count = values.count
        let start = LoopWheelRules.middleRow(index: selectedIndex, count: count)
        let rows = Binding(
            get: { row ?? start },
            set: { next in
                row = next
                selection = values[LoopWheelRules.index(ofRow: next, count: count)]
            }
        )
        Picker(label, selection: rows) {
            ForEach(0 ..< LoopWheelRules.rowCount(count), id: \.self) { item in
                Text(text(values[LoopWheelRules.index(ofRow: item, count: count)])).tag(item)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .onChange(of: selection) { _, value in follow(value) }
    }

    /// 值不是滾輪自己改的：轉到最近的那一列。
    private func follow(_ value: Double) {
        guard let current = row, let target = values.firstIndex(of: value) else { return }
        let next = LoopWheelRules.nearestRow(toIndex: target, from: current, count: values.count)
        if next != current {
            row = next
        }
    }
}
