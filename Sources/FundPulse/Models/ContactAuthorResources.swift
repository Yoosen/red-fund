import Foundation

/// 联系作者相关资源的加载工具，目前提供微信二维码资源的查找。
enum ContactAuthorResources {
    /// 在 Bundle 的 Resources 或 Contact 子目录中查找微信联系二维码图片。
    static func wechatQRCodeURL(bundle: Bundle = .module) -> URL? {
        bundle.url(forResource: "wechat-contact", withExtension: "png")
            ?? bundle.url(
                forResource: "wechat-contact",
                withExtension: "png",
                subdirectory: "Contact"
            )
    }
}
