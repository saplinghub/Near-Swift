import Foundation
import CoreGraphics

// MARK: - 皮肤包 manifest
/// 支持两种形象来源：
///  1. source = "lottie"       → Resources/lottie/<file>.json（现有内置宠物）
///  2. source = "spriteAtlas"  → spritesheet 雪碧图（兼容 codex pet 生态）
struct PetManifest: Codable, Equatable {
    var id: String
    var displayName: String
    var description: String?
    var source: String?            // "lottie"（默认） | "spriteAtlas"
    var lottieFile: String?        // source=lottie 时的 json 文件名（不含扩展名）
    var spritesheetPath: String?   // source=spriteAtlas 时的相对文件名
    var atlasRows: Int?            // 默认 9（codex 标准）；社区 v2 为 11

    enum CodingKeys: String, CodingKey {
        case id, displayName, description, source, lottieFile, spritesheetPath, atlasRows
    }

    init(id: String, displayName: String, description: String? = nil,
         source: String? = nil, lottieFile: String? = nil,
         spritesheetPath: String? = nil, atlasRows: Int? = nil) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.source = source
        self.lottieFile = lottieFile
        self.spritesheetPath = spritesheetPath
        self.atlasRows = atlasRows
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? self.id
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.source = try c.decodeIfPresent(String.self, forKey: .source)
        self.lottieFile = try c.decodeIfPresent(String.self, forKey: .lottieFile)
        self.spritesheetPath = try c.decodeIfPresent(String.self, forKey: .spritesheetPath)
        self.atlasRows = try c.decodeIfPresent(Int.self, forKey: .atlasRows)
    }

    /// 默认内置宠物（guaishou Lottie）
    static let builtinGuaishou = PetManifest(
        id: "guaishou",
        displayName: "怪兽",
        description: "内置桌宠",
        source: "lottie",
        lottieFile: "guaishou"
    )
}

// MARK: - 皮肤库
enum PetBundleError: Error, LocalizedError {
    case missingManifest(URL)
    case missingSpritesheet(URL)
    case missingLottie(String)
    case atlasFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .missingManifest(let u): return "缺少 pet.json：\(u.path)"
        case .missingSpritesheet(let u): return "缺少雪碧图：\(u.path)"
        case .missingLottie(let f): return "缺少内置 Lottie 资源：\(f)"
        case .atlasFailed(let u, let e): return "雪碧图加载失败 \(u.lastPathComponent)：\(e.localizedDescription)"
        }
    }
}

/// 一个已解析、可直接渲染的宠物形象。
struct PetBundle {
    let manifest: PetManifest
    let directoryURL: URL?     // 非 nil = 外部皮肤包目录（App Support / ~/.codex/pets）
    var atlas: SpriteAtlas?    // source = spriteAtlas 时非 nil

    var lottieName: String? { manifest.source == "lottie" ? (manifest.lottieFile ?? manifest.id) : nil }
    var isLottie: Bool { manifest.source != "spriteAtlas" }

    /// 从目录加载外部皮肤包
    static func load(from directoryURL: URL) throws -> PetBundle {
        let manifestURL = directoryURL.appendingPathComponent("pet.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PetBundleError.missingManifest(manifestURL)
        }
        let manifest = try JSONDecoder().decode(PetManifest.self, from: Data(contentsOf: manifestURL))

        guard manifest.source == "spriteAtlas" else {
            // Lottie 型皮肤包：资源名即 manifest.id 或 lottieFile
            let name = manifest.lottieFile ?? manifest.id
            guard ResourceBundle.current.path(forResource: name, ofType: "json") != nil else {
                throw PetBundleError.missingLottie(name)
            }
            return PetBundle(manifest: manifest, directoryURL: nil, atlas: nil)
        }

        let sheetName = manifest.spritesheetPath ?? "spritesheet.webp"
        let sheetURL = directoryURL.appendingPathComponent(sheetName)
        guard FileManager.default.fileExists(atPath: sheetURL.path) else {
            throw PetBundleError.missingSpritesheet(sheetURL)
        }

        let rows = manifest.atlasRows ?? PetAtlasRows.standardRows
        do {
            let atlas = try SpriteAtlas.load(from: sheetURL, rows: rows)
            return PetBundle(manifest: manifest, directoryURL: directoryURL, atlas: atlas)
        } catch {
            throw PetBundleError.atlasFailed(sheetURL, error)
        }
    }

    /// 内置 Lottie 皮肤
    static func builtin(_ manifest: PetManifest) -> PetBundle {
        PetBundle(manifest: manifest, directoryURL: nil, atlas: nil)
    }
}

// MARK: - 宠物皮肤库（扫描内置 + 用户目录 + 社区目录）
struct PetLibrary {
    /// 安装目录：~/Library/Application Support/Near-Swift/Pets/
    static let installedDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Near-Swift/Pets", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// 社区兼容目录：~/.codex/pets/（codex 官方 & awesome-codex-pet 一键安装默认位置）
    static let codexPetsDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/pets", isDirectory: true)
    }()

    /// 内置 Pets 目录（打包进 App Bundle 的 Resources/Pets）
    static var bundledPetsDirectory: URL? {
        ResourceBundle.current.resourceURL?.appendingPathComponent("Pets", isDirectory: true)
    }

    static func listAvailablePets() -> [PetManifest] {
        var results: [PetManifest] = []
        var seen = Set<String>()

        func append(_ manifest: PetManifest) {
            guard seen.insert(manifest.id).inserted else { return }
            results.append(manifest)
        }

        append(.builtinGuaishou)
        append(PetManifest(id: "dancer-woman", displayName: "舞娘", description: "内置 Lottie", source: "lottie", lottieFile: "dancer-woman"))

        var scanDirs: [URL] = [installedDirectory, codexPetsDirectory]
        if let bundled = bundledPetsDirectory {
            scanDirs.append(bundled)
        }
        for dir in scanDirs {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }

            for entry in entries where entry.hasDirectoryPath {
                let manifestURL = entry.appendingPathComponent("pet.json")
                guard FileManager.default.fileExists(atPath: manifestURL.path),
                      let data = try? Data(contentsOf: manifestURL),
                      let manifest = try? JSONDecoder().decode(PetManifest.self, from: data)
                else { continue }
                append(manifest)
            }
        }
        return results
    }

    /// 依据当前皮肤 ID 解析出可用形象；失败回退内置 guaishou。
    static func resolveBundle(petID: String?) -> PetBundle {
        guard let petID = petID, !petID.isEmpty else {
            return .builtin(.builtinGuaishou)
        }
        // 内置
        if petID == "guaishou" { return .builtin(.builtinGuaishou) }
        if petID == "dancer-woman" {
            return .builtin(PetManifest(id: "dancer-woman", displayName: "舞娘", source: "lottie", lottieFile: "dancer-woman"))
        }
        // 外部目录（安装目录 → ~/.codex/pets → 内置 Pets）
        var resolveDirs: [URL] = [installedDirectory, codexPetsDirectory]
        if let bundled = bundledPetsDirectory {
            resolveDirs.append(bundled)
        }
        for dir in resolveDirs {
            let candidate = dir.appendingPathComponent(petID, isDirectory: true)
            if let bundle = try? PetBundle.load(from: candidate) {
                return bundle
            }
        }
        return .builtin(.builtinGuaishou)
    }
}
