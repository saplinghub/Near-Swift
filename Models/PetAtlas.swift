import Foundation
import CoreGraphics
import ImageIO

// MARK: - 中文风格宠物语义状态
/// 业务层只表达“宠物现在在做什么”，渲染层负责把语义翻译成动画资源（雪碧图行 / Lottie）。
/// 采用中文风格命名，沿用项目拟人化风格。
enum PetAnimSemantic: String, Codable, CaseIterable, Equatable {
    case idle = "闲置"
    case walking = "行走"
    case dragging = "拖拽"
    case speaking = "说话"
    case waiting = "待命"
    case working = "忙碌"
    case review = "评审"
    case success = "成功"
    case failure = "失败"
    case docked = "贴边"
    case lowPower = "低电量"

    /// 旧逻辑中的播放意图（兼容迁移期：哪些语义应当“动起来”）
    var shouldAnimate: Bool {
        switch self {
        case .speaking, .dragging, .walking, .working, .waiting, .review, .idle, .docked:
            return true
        case .success, .failure, .lowPower:
            return false // 播完即停/静态帧
        }
    }
}

// MARK: - 雪碧图契约
/// Codex Pet 生态的标准行定义（8 列 × 9 行）。
/// 社区宠物 spritesheet 按此契约排列，本项目直接兼容加载。
enum PetAtlasRows {
    static let standardRows: Int = 9
    static let standardCols: Int = 8

    /// 每行使用的帧时长（毫秒）。未用到的格子必须透明。
    /// 参考 awesome-codex-pet / OpenPetsKit 的行定义。
    static let durationsMS: [Int: [Int]] = [
        0: [280, 110, 110, 140, 140, 320],                                   // idle
        1: [120, 120, 120, 120, 120, 120, 120, 220],                         // running-right
        2: [120, 120, 120, 120, 120, 120, 120, 220],                         // running-left
        3: [140, 140, 140, 280],                                             // waving
        4: [140, 140, 140, 140, 280],                                        // jumping
        5: [140, 140, 140, 140, 140, 140, 140, 240],                         // failed
        6: [150, 150, 150, 150, 150, 280],                                   // waiting
        7: [150, 150, 150, 150, 150, 280],                                   // running（正面/原地）
        8: [150, 150, 150, 150, 150, 280]                                    // review
    ]
}

/// 一段“语义动画”如何从雪碧图中取帧。
struct AtlasClip: Equatable {
    let row: Int
    let durationsMS: [Int]
    let loop: Bool          // false = 播完回到闲置
    let staticFrame: Bool   // true = 只显示首帧（低电量等）

    init(row: Int, durationsMS: [Int]? = nil, loop: Bool = true, staticFrame: Bool = false) {
        self.row = row
        self.durationsMS = durationsMS ?? PetAtlasRows.durationsMS[row] ?? [280]
        self.loop = loop
        self.staticFrame = staticFrame
    }

    var totalMS: Int { durationsMS.reduce(0, +) }
    var frameCount: Int { durationsMS.count }
}

extension PetAnimSemantic {
    /// 语义 → 雪碧图行映射（codex 契约行）。
    /// 社区宠物没有“说话/拖拽/成功”专属行时，用近义行兜底。
    func atlasClip(facing: PetFacingDirection) -> AtlasClip {
        switch self {
        case .idle:
            return AtlasClip(row: 0)
        case .walking:
            // 行走方向决定左/右行
            return facing == .left ? AtlasClip(row: 2, loop: true) : AtlasClip(row: 1, loop: true)
        case .dragging:
            // 拖拽中：显示闲置呼吸帧即可（手感不跳变）
            return AtlasClip(row: 0)
        case .speaking:
            // 说话 → waving（打招呼/引起注意）
            return AtlasClip(row: 3, loop: false)
        case .waiting:
            return AtlasClip(row: 6)
        case .working:
            return AtlasClip(row: 7)
        case .review:
            return AtlasClip(row: 8)
        case .success:
            return AtlasClip(row: 4, loop: false)
        case .failure:
            return AtlasClip(row: 5, loop: false)
        case .docked:
            return AtlasClip(row: 0)
        case .lowPower:
            return AtlasClip(row: 0, staticFrame: true)
        }
    }
}

// MARK: - 雪碧图资源
enum SpriteAtlasError: Error, LocalizedError {
    case unreadable(URL)
    case invalidDimensions(URL, width: Int, height: Int, rows: Int)

    var errorDescription: String? {
        switch self {
        case .unreadable(let url):
            return "无法读取雪碧图：\(url.lastPathComponent)"
        case .invalidDimensions(let url, let width, let height, let rows):
            return "雪碧图尺寸 \(width)x\(height) 无法按 \(PetAtlasRows.standardCols) 列 x \(rows) 行切分：\(url.lastPathComponent)"
        }
    }
}

/// 一张可切帧的雪碧图（整图持有 + 按行裁剪缓存）。
struct SpriteAtlas {
    let image: CGImage
    let columns: Int
    let rows: Int
    let cellWidth: Int
    let cellHeight: Int

    private var rowFrameCache: [Int: [CGImage]] = [:]

    init(image: CGImage, columns: Int, rows: Int) {
        self.image = image
        self.columns = columns
        self.rows = rows
        self.cellWidth = image.width / columns
        self.cellHeight = image.height / rows
    }

    /// 兼容 codex 生态加载（8 列；行数可配，默认 9）
    static func load(from url: URL, rows: Int = PetAtlasRows.standardRows) throws -> SpriteAtlas {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            CGImageSourceGetCount(source) > 0,
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = props[kCGImagePropertyPixelWidth] as? Int,
            let height = props[kCGImagePropertyPixelHeight] as? Int
        else {
            throw SpriteAtlasError.unreadable(url)
        }

        guard width % PetAtlasRows.standardCols == 0, height % rows == 0 else {
            throw SpriteAtlasError.invalidDimensions(url, width: width, height: height, rows: rows)
        }

        return SpriteAtlas(image: image, columns: PetAtlasRows.standardCols, rows: rows)
    }

    /// 取某一帧（每次裁剪，适合低频/视图绘制；高频用 frame(row:column:) 走缓存）。
    func cropFrame(row: Int, column: Int) -> CGImage? {
        guard row >= 0, row < rows, column >= 0, column < columns else { return nil }
        let rect = CGRect(x: column * cellWidth,
                          y: (rows - 1 - row) * cellHeight, // CGImage 坐标系原点在左下，行 0 在顶部
                          width: cellWidth, height: cellHeight)
        return image.cropping(to: rect)
    }

    /// 取某一帧（裁剪原图并缓存整行）。
    mutating func frame(row: Int, column: Int) -> CGImage? {
        guard row >= 0, row < rows, column >= 0, column < columns else { return nil }
        if let cached = rowFrameCache[row] {
            return column < cached.count ? cached[column] : nil
        }

        var frames: [CGImage] = []
        for col in 0..<columns {
            let rect = CGRect(x: col * cellWidth, y: row * cellHeight, width: cellWidth, height: cellHeight)
            if let cropped = image.cropping(to: rect) {
                frames.append(cropped)
            }
        }
        rowFrameCache[row] = frames
        return column < frames.count ? frames[column] : nil
    }
}
