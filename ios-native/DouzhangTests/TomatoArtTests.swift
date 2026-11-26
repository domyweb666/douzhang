@testable import Douzhang
import SwiftUI
import XCTest

/// 番茄的形狀與顏色改成先建好共用（效能審查甲5）：要跟原本每格現建的一模一樣。
/// 下面的「原本」照改之前 TomatoArt 每格現建的寫法逐行抄來，數字是那張 100×100 的畫布。
final class TomatoArtTests: XCTestCase {
    private let sides: [CGFloat] = [-1, 1]

    private func originalLeaf(side: CGFloat) -> Path {
        let centerX = 50 + side * 13
        let rect = CGRect(x: centerX - 24 / 2, y: 10 - 11 / 2, width: 24, height: 11)
        let turn = CGAffineTransform(translationX: centerX, y: 10)
            .rotated(by: side * 14 * .pi / 180)
            .translatedBy(x: -centerX, y: -10)
        return Path(ellipseIn: rect).applying(turn)
    }

    private func originalEye(side: CGFloat) -> Path {
        let eyeX = 50 + side * 13
        return Path(ellipseIn: CGRect(x: eyeX - 3.8, y: 55 - 3.8, width: 3.8 * 2, height: 3.8 * 2))
    }

    private func originalCheek(side: CGFloat) -> Path {
        let cheekX = 50 + side * 23
        return Path(ellipseIn: CGRect(x: cheekX - 11 / 2, y: 64 - 6.4 / 2, width: 11, height: 6.4))
    }

    private func assertSame(_ built: Path, _ original: Path, _ name: String) {
        XCTAssertEqual(built.description, original.description, name)
        XCTAssertEqual(built.boundingRect, original.boundingRect, name)
    }

    func test先建好的形狀跟原本每格現建的一樣() {
        let body = Path(ellipseIn: CGRect(x: 6, y: 9, width: 88, height: 88))
        assertSame(TomatoArt.bodyPath, body, "身體")
        var shine = Path()
        shine.move(to: CGPoint(x: 19, y: 44))
        shine.addCurve(
            to: CGPoint(x: 38, y: 21),
            control1: CGPoint(x: 21, y: 33),
            control2: CGPoint(x: 28, y: 25)
        )
        assertSame(TomatoArt.shinePath, shine, "反光")
        var stem = Path()
        stem.move(to: CGPoint(x: 50, y: 11))
        stem.addLine(to: CGPoint(x: 50, y: 3.5))
        assertSame(TomatoArt.stemPath, stem, "蒂頭")
        var mouth = Path()
        mouth.move(to: CGPoint(x: 43.5, y: 63))
        mouth.addQuadCurve(to: CGPoint(x: 56.5, y: 63), control: CGPoint(x: 50, y: 69.5))
        assertSame(TomatoArt.mouthPath, mouth, "嘴")
        XCTAssertEqual(TomatoArt.leafPaths.count, 2)
        XCTAssertEqual(TomatoArt.eyePaths.count, 2)
        XCTAssertEqual(TomatoArt.cheekPaths.count, 2)
        for (index, side) in sides.enumerated() {
            assertSame(TomatoArt.leafPaths[index], originalLeaf(side: side), "葉子 \(side)")
            assertSame(TomatoArt.eyePaths[index], originalEye(side: side), "眼睛 \(side)")
            assertSame(TomatoArt.cheekPaths[index], originalCheek(side: side), "臉頰 \(side)")
        }
    }

    func test先建好的身體色跟標籤色一樣() {
        for color in TomatoColor.allCases {
            let original = Tokens.Tomato.body(color).color
            XCTAssertEqual(TomatoArt.bodyColor(color), original, color.rawValue)
        }
    }
}
