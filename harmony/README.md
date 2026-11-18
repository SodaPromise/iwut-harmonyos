# 掌上吾理 · HarmonyOS

此工程以 TokenTeam/iwut `10335a5`（0.3.31）为基线，供本地构建与测试。界面使用 ArkTS/ArkUI，包含原生 Ability、Scan Kit、Calendar Kit、Form Kit 和系统提醒。校园服务和学校统一认证页面由 ArkWeb 打开，教务数据处理复用上游查询与解析逻辑。项目保留上游 [AGPL-3.0-or-later 许可证](../LICENSE)。

## 打开和构建

1. 在 DevEco Studio 打开本仓库的 `harmony` 目录。下方命令中的路径以 DevEco Studio 的实际安装位置为准。
2. 使用 DevEco Studio 26.0.0 Release 或更新版本。编译使用 DevEco Studio 内置的 HarmonyOS SDK，目标版本为 HarmonyOS 26.0.0（`targetSdkVersion`），最低运行版本为 HarmonyOS 6.1.1（API 24，`compatibleSdkVersion`）。模拟器可选 HarmonyOS 26.0.0 稳定版。
3. 在 DevEco Studio 构建 HAP，或在 PowerShell 运行以下命令。

```powershell
.\Build.ps1 -DevEcoRoot 'D:\dev\DevEco Studio'
```

未配置签名时，输出为 `artifacts\iwut-harmony-unsigned.hap`。要在手机上运行，可连接已打开调试的鸿蒙设备，再用 DevEco Studio 的项目签名配置生成调试签名并点击 Run。工程使用独立包名 `net.tokenteam.iwut.harmony`。

## 已实现的主要流程

- 首页、课程、功能、我的，以及原有的设置分组和菜单顺序。
- 本科与研究生课表、实验课、考试、成绩的导入入口，课表管理、导入导出及配色。
- 校园账号绑定、校园网登录、长按应用图标快捷入口、扫码与分享、日历同步、系统提醒和桌面课表卡片。
- 使用现有教务 Web 会话在前台静默刷新。会话失效后，可从课程菜单重新导入。
- 校园服务页的资料、应用信息和页面分域存储接口。

课前与考试提醒由系统日历发送。考前免打扰入口显示考试时间并打开系统设置，由用户开启免打扰。Sentry 遥测与应用内反馈、通用网页自动化未接通。更新入口目前打开上游发布页面。系统卡片、提醒、扫码以及校园服务需要在真机测试，教务登录与校园网验证需要可用的学校账号和网络。

## 同步上游资源与检查

```powershell
$sdkTs = 'D:\dev\DevEco Studio\sdk\default\openharmony\ets\build-tools\ets-loader\node_modules\typescript'
node .\scripts\sync-upstream.cjs $sdkTs
node .\scripts\verify-source.cjs $sdkTs
```

同步脚本从仓库中的上游源码生成翻译、功能入口、课表资源与教务查询脚本。核对脚本检查导航顺序、设置顺序、课程校验、课表合并、首页课程状态及校园网页接口的来源限制。
