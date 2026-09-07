import SwiftUI
import AppKit

/// 雪碧图渲染视图：从 PetModel 读取当前行/列，展示对应帧。
/// 由 PetDirector 驱动 model.atlasRow / model.atlasCol。
/// 每个语义是一个“行”，列 = 该动画的帧。
struct SpriteAtlasView: View {
    @ObservedObject var model: PetModel
    var bundle: PetBundle?

    private var frameImage: NSImage? {
        guard let atlas = bundle?.atlas,
              let cg = atlas.cropFrame(row: model.atlasRow, column: model.atlasCol) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: atlas.cellWidth, height: atlas.cellHeight))
    }

    var body: some View {
        Group {
            if let img = frameImage {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
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
