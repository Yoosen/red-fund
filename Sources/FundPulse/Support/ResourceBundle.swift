import Foundation

extension Bundle {
    /// 资源 bundle 的统一入口，完全绕过 SwiftPM 自动生成的 `Bundle.module`。
    ///
    /// SwiftPM 生成的 `Bundle.module` 是 `static let`，初始化时只查
    /// `App根/FundPulse_FundPulse.bundle` 与编译期绝对路径，两者在非本机打包
    /// 环境下都不存在，会直接 `fatalError` 导致整个 App 启动即崩溃。
    /// 这里直接从标准 `Contents/Resources` 目录查找同名 bundle，避免触发
    /// `Bundle.module` 的初始化。
    static var fundPulseResources: Bundle {
        if let url = Bundle.main.resourceURL?
            .appendingPathComponent("FundPulse_FundPulse.bundle"),
            let bundle = Bundle(url: url) {
            return bundle
        }
        // 兜底：返回主 bundle，资源缺失时各调用处的 `if let` 会安全降级
        return .main
    }
}
