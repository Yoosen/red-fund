## 问题修复

- 修复 GitHub Action 打包产物在「设置-支持/关于」页签闪退的问题：SwiftPM 生成的 `Bundle.module` 在 app 根目录查找资源 bundle，与打包时拷贝到 `Contents/Resources/` 的实际位置不一致，导致非本机环境找不到资源而 fatalError 崩溃。新增 `Bundle.fundPulseResources` 统一入口，优先 `Bundle.module`、缺失时回退到标准 `Contents/Resources/FundPulse_FundPulse.bundle`，兼容打包位置差异，且不影响代码签名。
- 修复微信支付方式的闪动。
- 修复 tag-release 工作流「Commit archived release notes」步骤在 tag push 事件（detached HEAD）下 `git push` 失败的问题，改为显式 `git push origin HEAD:main`。
