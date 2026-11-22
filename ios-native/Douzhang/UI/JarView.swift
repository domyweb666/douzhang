import SwiftUI

/// 番茄堆：今天的番茄躺在最下面；收下一顆就從上面掉進來，落地那一幀「啵」＋短觸覺。
/// 傾斜手機番茄跟著滾（設定可關）、點一下彈、碰撞有聲音與觸覺、掉幀就退成靜止版。
/// 物理在 Core/JarPhysics.swift，現場在 JarScene；這裡只負責每一幀畫出來。
struct JarView: View {
    /// 今天的番茄（依時間排）：分鐘決定大小，標籤決定顏色
    var beans: [JarBean]
    var sound: Bool
    var tilt: Bool
    /// 看得到才動：滑到番茄架或設定時，這頁其實還掛著，要停下來，不然一直跟滑頁搶手
    var active: Bool
    /// 殼保管的「番茄堆上次看到幾顆」：鈴響時番茄堆不在畫面上，回來要知道哪顆是新的
    @Binding var seen: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene = JarScene()

    var body: some View {
        TimelineView(.animation(paused: scene.asleep || !active)) { timeline in
            Canvas { context, size in
                scene.layout(
                    width: size.width,
                    height: size.height,
                    beans: beans,
                    seen: seen
                )
                scene.advance(now: timeline.date.timeIntervalSinceReferenceDate)
                for body in scene.world.bodies {
                    TomatoArt.draw(
                        &context,
                        center: CGPoint(x: body.x, y: body.y),
                        radius: body.radius,
                        angle: body.angle,
                        fill: Tokens.Tomato.body(scene.color(of: body)).color
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture().onEnded { tap in
                scene.tap(x: tap.location.x, y: tap.location.y)
            }
        )
        .accessibilityElement()
        .accessibilityLabel(a11yLabel)
        .onAppear(perform: start)
        .onDisappear { scene.stop() }
        .onChange(of: beans) { _, next in scene.follow(next) }
        .onChange(of: sound) { _, next in scene.soundOn = next }
        .onChange(of: tilt) { _, next in scene.setTilt(next) }
        .onChange(of: active) { _, next in scene.setActive(next, tilt: tilt) }
        .onChange(of: reduceMotion) { _, next in
            scene.reduceMotion = next
            scene.setTilt(tilt)
        }
    }

    private var a11yLabel: String {
        beans.isEmpty ? Words.todayBeans : "\(Words.todayBeans) \(beans.count)"
    }

    private func start() {
        scene.soundOn = sound
        scene.reduceMotion = reduceMotion
        scene.active = active
        scene.onKnown = { count in
            // 番茄堆是在畫的過程中回報的：排到這一幀之後再記，不在畫到一半時改狀態
            Task { @MainActor in seen = count }
        }
        scene.setTilt(tilt)
    }
}
