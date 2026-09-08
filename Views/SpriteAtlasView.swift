import SwiftUI
import AppKit
import QuartzCore

/// 雪碧图渲染视图。
/// 只订阅 model 中与渲染相关的字段（语义/朝向/贴边/帧），
/// 避免整个 PetModel 的任何 @Published（CPU、心情等）变化都触发重绘导致抖动。
struct SpriteAtlasView: View {
    @ObservedObject var model: PetModel
    var bundle: PetBundle?

    var body: some View {
        Group {
            if let atlas = bundle?.atlas {
                AtlasLayerView(atlas: atlas, semantic: model.semantic, facing: model.facingDirection,
                               row: model.atlasRow, col: model.atlasCol)
                    .frame(width: 60, height: 60)
            } else {
                Color.clear.frame(width: 60, height: 60)
            }
        }
        .scaleEffect(x: model.facingDirection.scale, y: 1.0)
        .scaleEffect(model.isDocked ? 0.75 : 1.0)
        .opacity(model.isDocked ? 0.9 : 1.0)
    }
}

/// 帧通过 CALayer.contentsRect 展示。
/// 每次更新都在禁用隐式动画的事务里完成；内容相同则完全跳过。
private struct AtlasLayerView: NSViewRepresentable {
    let atlas: SpriteAtlas
    let semantic: PetAnimSemantic
    let facing: PetFacingDirection
    let row: Int
    let col: Int

    func makeNSView(context: Context) -> AtlasNSView {
        let v = AtlasNSView()
        v.wantsLayer = true
        v.apply(atlas: atlas, row: row, col: col)
        return v
    }

    func updateNSView(_ nsView: AtlasNSView, context: Context) {
        nsView.apply(atlas: atlas, row: row, col: col)
    }
}

private final class AtlasNSView: NSView {
    /// 行 0 在顶部（与雪碧图导出方向一致）
    override var isFlipped: Bool { true }

    private var lastKey: String?

    func apply(atlas: SpriteAtlas, row: Int, col: Int) {
        guard let layer = layer else { return }
        let cols = atlas.columns
        let rows = atlas.rows
        guard cols > 0, rows > 0 else { return }

        let safeRow = max(0, min(row, rows - 1))
        let safeCol = max(0, min(col, cols - 1))
        let key = "\(safeRow)-\(safeCol)"
        guard lastKey != key || layer.contents == nil else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if layer.contents == nil {
            layer.contents = atlas.image
            layer.contentsGravity = .resizeAspect
        }
        let cellW = 1.0 / CGFloat(cols)
        let cellH = 1.0 / CGFloat(rows)
        layer.contentsRect = CGRect(
            x: CGFloat(safeCol) * cellW,
            y: CGFloat(safeRow) * cellH,
            width: cellW, height: cellH
        )
        CATransaction.commit()
        lastKey = key
    }
}
