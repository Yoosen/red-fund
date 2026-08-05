## 问题修复

- 修复 GitHub Action 打包产物在「设置-支持/关于」页签闪退的问题：资源 bundle（FundPulse_FundPulse.bundle）此前被拷贝到 `Contents/Resources/`，而 SwiftPM 的 `Bundle.module` 在 app 根目录查找，导致非本机环境找不到资源而 fatalError 崩溃。已将拷贝目标修正为 app 根目录，与 `Bundle.module` 预期路径一致。
- 修复微信支付方式的闪动。
- 修复 tag-release 工作流「Commit archived release notes」步骤在 tag push 事件（detached HEAD）下 `git push` 失败的问题，改为显式 `git push origin HEAD:main`。
