import SwiftUI

/// 番茄堆：今天的番茄躺在最下面；收下一顆就從上面掉進來，落地那一幀「啵」＋短觸覺。
/// 傾斜手機番茄跟著滾（設定可關）、點一下彈、碰撞有聲音與觸覺、掉幀就退成靜止版（點了亮一下）。
/// 物理在 Core/JarPhysics.swift，現場在 JarScene；這裡只負責每一幀畫出來。
struct JarView: View {
    /// 今天的番茄（依時間排）：分鐘決定大小，標籤決定顏色
    var beans: [JarBean]
    var sound: Bool
    var tilt: Bool
    /// 殼保管的「番茄堆上次看到幾顆」：鈴響時番茄堆不在畫面上，回來要知道哪顆是新的
    @Binding var seen: Int?

    @Environment(PagerMotion.self) private var pager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 出現時才建、而且只建一次。寫成預設值的話，主畫面每重算一次就多建一個丟掉的現場
    /// （讀五個音檔、切音訊模式），滑到一半換頁那一拍就卡在這裡；
    /// 而且第一次畫可能早於接上 onKnown，「上次看到幾顆」記不到，新的一顆就直接躺在底。
    @State private var scene: JarScene?

    /// 三頁正在滑、或停在別頁：凍著不畫，不跟滑頁搶手。這頁滑走了其實還掛著
    private var frozen: Bool {
        pager.rest != .home
    }

    var body: some View {
        ZStack {
            if let scene {
                JarCanvas(scene: scene, beans: beans, seen: seen, frozen: frozen)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture().onEnded { tap in
                scene?.tap(x: tap.location.x, y: tap.location.y)
            }
        )
        .accessibilityElement()
        .accessibilityLabel(a11yLabel)
        .onAppear(perform: start)
        .onDisappear { scene?.stop() }
        .onChange(of: beans) { _, next in scene?.follow(next, drops: seen != nil) }
        // 殼說整份換過了（同步、匯入）：照現在的躺好，再回報看到幾顆，
        // 不然下次收下的那顆會被當成早就看過，不掉下來
        .onChange(of: seen) { _, next in
            if next == nil {
                scene?.follow(beans, drops: false)
            }
        }
        .onChange(of: sound) { _, next in scene?.soundOn = next }
        .onChange(of: tilt) { _, next in scene?.setTilt(next) }
        .onChange(of: frozen) { _, next in scene?.setFrozen(next) }
        .onChange(of: reduceMotion) { _, next in
            scene?.reduceMotion = next
            scene?.setTilt(tilt)
        }
        .task(id: pager.rest) { await followPager(pager.rest) }
    }

    private var a11yLabel: String {
        beans.isEmpty ? Words.todayBeans : "\(Words.todayBeans) \(beans.count)"
    }

    private func start() {
        let current = scene ?? JarScene()
        current.soundOn = sound
        current.reduceMotion = reduceMotion
        current.active = !frozen
        current.setFrozen(frozen)
        current.onKnown = { count in
            // 番茄堆是在畫的過程中回報的：排到這一幀之後再記，不在畫到一半時改狀態
            Task { @MainActor in seen = count }
        }
        current.setTilt(tilt)
        scene = current
    }

    /// 停穩了再開關感測器：停下那一拍手指可能馬上又滑走。
    private func followPager(_ page: Page?) async {
        guard let page else { return }
        try? await Task.sleep(for: .seconds(Tokens.Motion.pageSettle))
        if !Task.isCancelled {
            scene?.setActive(page == .home, tilt: tilt)
        }
    }
}

/// 番茄堆的每一幀。睡著或凍著時不畫。
private struct JarCanvas: View {
    var scene: JarScene
    var beans: [JarBean]
    var seen: Int?
    var frozen: Bool

    var body: some View {
        let paused = scene.asleep || frozen
        TimelineView(.animation(minimumInterval: JarTuning.redraw, paused: paused)) { timeline in
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
                        fill: fill(body)
                    )
                }
            }
        }
    }

    /// 標籤色；靜止版被點到的那顆往白色靠（調色的算法跟計時中由青轉紅同一個）。
    private func fill(_ body: JarBody) -> Color {
        let base = Tokens.Tomato.body(scene.color(of: body))
        let glow = scene.glow.strength(of: body.id) * Tokens.Opacity.tapGlow
        return Grow.ripeColor(glow, unripe: base, ripe: Tokens.Tomato.shine).color
    }
}
