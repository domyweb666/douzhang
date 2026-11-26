import SwiftUI
import UIKit

/// 循環的滾輪：系統的滾輪（滾動有系統的輕觸覺），滾過最後一個會接回第一個。
/// 哪一列是哪個值、值從外面被改掉時轉去哪一列，都在 Core/LoopWheelRules.swift。
struct LoopWheel: View {
    var label: String
    var values: [Double]
    @Binding var selection: Double
    var text: (Double) -> String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        LoopPicker(label: label, values: values, selection: $selection, text: text)
            // 列高問過一次就記著：系統字級變了就整個重做
            .id(typeSize)
    }
}

/// 不用 SwiftUI 的滾輪：它的列高是固定的，字放大了上下幾列會疊在一起。
/// 這裡照字級給列高；整個滾輪還是系統的高度，下面的東西不會被擠走，只是看得到的列少一點。
struct LoopPicker: UIViewRepresentable {
    var label: String
    var values: [Double]
    @Binding var selection: Double
    var text: (Double) -> String

    func makeCoordinator() -> Coordinator {
        Coordinator(wheel: self)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let view = UIPickerView()
        view.dataSource = context.coordinator
        view.delegate = context.coordinator
        let index = values.firstIndex(of: selection) ?? 0
        let row = LoopWheelRules.middleRow(index: index, count: values.count)
        view.selectRow(row, inComponent: 0, animated: false)
        return view
    }

    func updateUIView(_ view: UIPickerView, context: Context) {
        context.coordinator.wheel = self
        context.coordinator.follow(view)
    }

    /// 高度照系統的滾輪，寬度給多少用多少。
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UIPickerView,
        context _: Context
    ) -> CGSize? {
        let own = uiView.intrinsicContentSize
        return CGSize(width: proposal.width ?? own.width, height: own.height)
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewAccessibilityDelegate {
        var wheel: LoopPicker
        /// 滾輪停著的值：跟外面的不一樣，才是被別人改的
        private var shown: Double
        private let font = UIFont.preferredFont(forTextStyle: .title1)

        init(wheel: LoopPicker) {
            self.wheel = wheel
            shown = wheel.selection
        }

        /// 值不是滾輪自己改的：轉到最近的那一列。值沒變就不碰，不然會把還在滾的拉回來。
        func follow(_ view: UIPickerView) {
            let value = wheel.selection
            guard value != shown, let target = wheel.values.firstIndex(of: value) else { return }
            shown = value
            let current = view.selectedRow(inComponent: 0)
            let count = wheel.values.count
            let next = LoopWheelRules.nearestRow(toIndex: target, from: current, count: count)
            if next != current {
                view.selectRow(next, inComponent: 0, animated: true)
            }
        }

        private func value(ofRow row: Int) -> Double {
            wheel.values[LoopWheelRules.index(ofRow: row, count: wheel.values.count)]
        }

        func numberOfComponents(in _: UIPickerView) -> Int {
            1
        }

        func pickerView(_: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
            LoopWheelRules.rowCount(wheel.values.count)
        }

        func pickerView(_: UIPickerView, rowHeightForComponent _: Int) -> CGFloat {
            font.lineHeight + Tokens.Layout.tight * 2
        }

        func pickerView(
            _: UIPickerView,
            viewForRow row: Int,
            forComponent _: Int,
            reusing view: UIView?
        ) -> UIView {
            let cell = view as? UILabel ?? UILabel()
            cell.font = font
            cell.textColor = UIColor(Tokens.Colors.textPrimary)
            cell.textAlignment = .center
            cell.text = wheel.text(value(ofRow: row))
            return cell
        }

        func pickerView(_: UIPickerView, didSelectRow row: Int, inComponent _: Int) {
            shown = value(ofRow: row)
            wheel.selection = shown
        }

        func pickerView(_: UIPickerView, accessibilityLabelForComponent _: Int) -> String? {
            wheel.label
        }
    }
}
