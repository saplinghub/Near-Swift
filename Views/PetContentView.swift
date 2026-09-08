import SwiftUI

/// 宠物形象渲染：全部为雪碧图（codex 8x9 契约社区宠物）。
/// 由 PetManager 持有并注入 bundle；PetModel 只是状态快照的载体。
struct PetContentView: View {
    @ObservedObject var model: PetModel
    var bundle: PetBundle?

    var body: some View {
        Group {
            if let bundle = bundle, bundle.atlas != nil {
                SpriteAtlasView(model: model, bundle: bundle)
            } else {
                Color.clear.frame(width: 60, height: 60)
            }
        }
        .frame(width: 60, height: 60)
        .scaleEffect(x: model.facingDirection.scale, y: 1.0)
        .scaleEffect(model.isDocked ? 0.75 : 1.0)
        .opacity(model.isDocked ? 0.9 : 1.0)
    }
}
