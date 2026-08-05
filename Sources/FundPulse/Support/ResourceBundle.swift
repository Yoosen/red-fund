import Foundation

extension Bundle {
    /// 资源 bundle 的统一入口。
    ///
    /// SwiftPM 生成的 `Bundle.module` 在打包成 `.app` 后，
    /// 其查找路径（`App根/FundPulse_FundPulse.bundle`）与实际拷贝位置
    /// （`Contents/Resources/FundPulse_FundPulse.bundle`）可能不一致，
    /// 导致非本机环境下找不到资源而崩溃。
    /// 这里优先使用 `Bundle.module`，若其资源目录不存在则回退到
    /// 标准 `Contents/Resources` 下的同名 bundle，保证打包产物可正常加载。
    static var fundPulseResources: Bundle {
        let moduleBundle = Bundle.module
        if FileManager.default.fileExists(atPath: moduleBundle.bundlePath) {
            return moduleBundle
        }
        if let url = Bundle.main.resourceURL?
            .appendingPathComponent("FundPulse_FundPulse.bundle"),
            let fallback = Bundle(url: url) {
            return fallback
        }
        return moduleBundle
    }
}
