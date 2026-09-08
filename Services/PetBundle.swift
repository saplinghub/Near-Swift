import Foundation
import CoreGraphics

// MARK: - 皮肤包 manifest
/// 宠物形象统一为雪碧图（codex 8x9 契约社区宠物）。
struct PetManifest: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var description: String?
    var spritesheetPath: String?   // 相对文件名，默认 spritesheet.webp
    var atlasRows: Int?            // 默认 9（codex 标准）；社区 v2 为 11

    enum CodingKeys: String, CodingKey {
        case id, displayName, description, spritesheetPath, atlasRows
    }

    init(id: String, displayName: String, description: String? = nil,
         spritesheetPath: String? = nil, atlasRows: Int? = nil) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.spritesheetPath = spritesheetPath
        self.atlasRows = atlasRows
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? self.id
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.spritesheetPath = try c.decodeIfPresent(String.self, forKey: .spritesheetPath)
        self.atlasRows = try c.decodeIfPresent(Int.self, forKey: .atlasRows)
    }

    /// 内置默认宠物（仓库 Resources/Pets 中的独角兽）
    static let builtinStarcorn = PetManifest(
        id: "starcorn",
        displayName: "独角兽",
        description: "内置社区宠物 (OpenPets Starcorn, MIT)"
    )
}

// MARK: - 皮肤库
enum PetBundleError: Error, LocalizedError {
    case missingManifest(URL)
    case missingSpritesheet(URL)
    case atlasFailed(URL, Error)

    var errorDescription: String? {
        switch self {
        case .missingManifest(let u): return "缺少 pet.json：\(u.path)"
        case .missingSpritesheet(let u): return "缺少雪碧图：\(u.path)"
        case .atlasFailed(let u, let e): return "雪碧图加载失败 \(u.lastPathComponent)：\(e.localizedDescription)"
        }
    }
}

/// 一个已解析、可直接渲染的宠物形象（雪碧图）。
struct PetBundle {
    let manifest: PetManifest
    let directoryURL: URL?
    var atlas: SpriteAtlas?

    var displayName: String { manifest.displayName }

    /// 从目录加载外部皮肤包（~/.codex/pets 或 App Support/Pets）
    static func load(from directoryURL: URL) throws -> PetBundle {
        let manifestURL = directoryURL.appendingPathComponent("pet.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw PetBundleError.missingManifest(manifestURL)
        }
        let manifest = try JSONDecoder().decode(PetManifest.self, from: Data(contentsOf: manifestURL))

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

        append(.builtinStarcorn)

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

    /// 依据当前皮肤 ID 解析出可用形象；失败回退内置 starcorn。
    static func resolveBundle(petID: String?) -> PetBundle {
        guard let petID = petID, !petID.isEmpty, petID != "guaishou", petID != "dancer-woman" else {
            return resolveStarcorn()
        }
        if petID == "starcorn" { return resolveStarcorn() }

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
        return resolveStarcorn()
    }

    private static func resolveStarcorn() -> PetBundle {
        // 优先内置资源目录，其次 App Support 里的 starcorn
        let candidates: [URL] = {
            var list: [URL] = [installedDirectory]
            if let bundled = bundledPetsDirectory { list.append(bundled) }
            list.append(codexPetsDirectory)
            return list
        }()
        for dir in candidates {
            let candidate = dir.appendingPathComponent("starcorn", isDirectory: true)
            if let bundle = try? PetBundle.load(from: candidate) {
                return bundle
            }
        }
        // 理论不可达（内置包总是存在），仅防御
        return PetBundle(manifest: .builtinStarcorn, directoryURL: nil, atlas: nil)
    }
}
