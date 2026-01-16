import Foundation

/// 资源 Bundle 工具类
/// 用于解决 SPM `Bundle.module` 在 macOS 打包成 .app 后可能无法定位资源的问题。
public enum ResourceBundle {
    /// 获取当前可用的资源 Bundle
    public static var current: Bundle = {
        let bundleName = "NearCountdown_NearCountdown.bundle"
        let mainBundle = Bundle.main
        
        // 1. 优先尝试在 .app 的 Resources 目录下查找 (打包后的标准位置)
        if let resourceURL = mainBundle.resourceURL {
            let bundleURL = resourceURL.appendingPathComponent(bundleName)
            if let bundle = Bundle(url: bundleURL) {
                return bundle
            }
        }
        
        // 2. 尝试在当前可执行文件同级目录查找
        let executableBundleURL = mainBundle.bundleURL.appendingPathComponent(bundleName)
        if let bundle = Bundle(url: executableBundleURL) {
            return bundle
        }
        
        // 3. 回退到 SPM 默认生成的 Bundle.module
        return Bundle.module
    }()
}
