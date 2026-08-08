## 重要变更
- 应用对外品牌正式更名为 **Red Fund**，与原作者项目区分：菜单栏、设置、关于等界面显示名统一为 Red Fund。
- 打包产物（.app 包名、启动台/应用程序文件夹显示名）改为 **Red Fund**，Info.plist 的 CFBundleName 与 CFBundleDisplayName 均更新为 Red Fund。
- GitHub 仓库与发布/更新检查地址切换为 **yoosen/red-fund**（原为作者仓库），发布包名改为 `red-fund-<版本>-<架构>-swift.{zip,dmg}`。

## 功能优化
- 本地用户数据目录由 `~/Library/Application Support/fund-pulse/` 迁移至 `red-fund/`：旧目录在首次启动时会自动整体迁移，老用户数据不丢失。
