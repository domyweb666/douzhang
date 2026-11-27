import SwiftUI
import UIKit

/// 每種顏色的番茄先畫成一張圖：一週一百顆時，每格每顆都畫十幾筆太重，先畫好每格只剩位移、旋轉、縮放。
/// 畫成最大那顆的大小，畫面上只縮不放，縮小比放大清楚。螢幕倍率變了就重畫。
@MainActor
final class JarSprites {
    private static let size = JarTuning.standard.radius * JarTuning.standard.sizeMax * 2
    private var images: [TomatoColor: Image] = [:]
    private var madeAt: CGFloat = 0

    /// 畫不出來（沒有圖）回 nil，呼叫端照原本一筆一筆畫。
    func image(_ color: TomatoColor, displayScale: CGFloat) -> Image? {
        if displayScale != madeAt {
            images = [:]
            madeAt = displayScale
        }
        if let made = images[color] {
            return made
        }
        let renderer = ImageRenderer(content: TomatoView(color: color, size: JarSprites.size))
        renderer.scale = displayScale
        guard let picture = renderer.uiImage else { return nil }
        let made = Image(uiImage: picture).interpolation(.high)
        images[color] = made
        return made
    }
}
