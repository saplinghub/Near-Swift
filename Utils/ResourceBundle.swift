import Foundation

/// 资源 Bundle 工具类
/// 用于解决 SPM `Bundle.module` 在 macOS 打包成 .app 后可能无法定位资源的问题。
public enum ResourceBundle {
    /// 获取当前可用的资源 Bundle
    public static var current: Bundle = {
        let mainBundle = Bundle.main
        let fileManager = FileManager.default

        func hasExpectedResources(_ bundle: Bundle) -> Bool {
            guard let resourceURL = bundle.resourceURL else { return false }

            let iconsURL = resourceURL.appendingPathComponent("icons")
            let lottieURL = resourceURL.appendingPathComponent("lottie")
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: iconsURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return true
            }

            if fileManager.fileExists(atPath: lottieURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return true
            }

            return bundle.path(forResource: "fan_00", ofType: "png", inDirectory: "icons/fan_frames") != nil
        }

        func findBundle(in directoryURL: URL) -> Bundle? {
            guard let urls = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
                return nil
            }

            let bundleURLs = urls.filter { $0.pathExtension == "bundle" }

            for bundleURL in bundleURLs {
                if let bundle = Bundle(url: bundleURL), hasExpectedResources(bundle) {
                    return bundle
                }
            }

            if let firstBundleURL = bundleURLs.first, let bundle = Bundle(url: firstBundleURL) {
                return bundle
            }

            return nil
        }

        if let resourceURL = mainBundle.resourceURL, let bundle = findBundle(in: resourceURL) {
            return bundle
        }

        if let bundle = findBundle(in: mainBundle.bundleURL) {
            return bundle
        }

        return Bundle.module
    }()
}
