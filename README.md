# 掌上吾理 · HarmonyOS

> 武汉理工大学校园客户端「掌上吾理」的原生鸿蒙实现（ArkTS / ArkUI）

<p>
  <img alt="License" src="https://img.shields.io/badge/license-AGPL--3.0--or--later-blue?style=flat-square">
  <img alt="HarmonyOS" src="https://img.shields.io/badge/HarmonyOS-6.1.1%2B%20%2F%20API%2024-black?style=flat-square">
  <img alt="ArkTS" src="https://img.shields.io/badge/ArkTS-ArkUI-1f6feb?style=flat-square">
  <img alt="DevEco" src="https://img.shields.io/badge/DevEco%20Studio-26.0.0-3fbf7f?style=flat-square">
</p>

## 这是什么

本仓库是 [TokenTeam/iwut](https://github.com/TokenTeam/iwut)（React Native / Expo 版掌上吾理）的鸿蒙移植分支。

`harmony/` 是一个独立的 DevEco Studio 工程，用 **ArkTS + ArkUI 原生重写**界面与交互，不依赖 React Native、Expo 或 RNOH 运行时；仓库其余部分保留上游 RN 工程，作为功能基线、文案与资源的来源，两者并行维护。

| | |
| --- | --- |
| 包名 | `net.tokenteam.iwut.harmony` |
| 版本 | 0.3.31（versionCode 331） |
| 目标版本 | HarmonyOS 26.0.0（`targetSdkVersion`） |
| 最低版本 | HarmonyOS 6.1.1 / API 24（`compatibleSdkVersion`） |
| 设备 | phone、tablet |

## 功能

**主界面与导航**

- 首页、课程、功能、我的四个主页面，保留上游的分组与菜单顺序
- 底部页签支持**跟手横滑**切换，点击页签叠加淡入过渡（`HdsTabs` 悬浮底栏 / `Tabs` 双实现，按设备 API 能力选择）
- 二级页面统一走原生 `Navigation` 路由栈，使用系统的进入 / 返回转场与边缘返回手势
- 课程详情、快速添加弹层带缩放 + 淡入淡出，分享面板沿用半模态转场

**课程与教务**

- 本科、研究生课表与实验课导入，跨节次课程合并、非本周课程标记、重叠课程提示
- 周次切换、中课显示、周末横向滚动查看、课程增删改、配色方案与导入导出
- 考试安排（未开始 / 已完成 / 未安排、倒计时、座位号）与成绩（按学期筛选、重新查询）
- 教务 Web 会话在前台静默刷新；会话失效后可从课程菜单重新导入

**校园服务与系统能力**

- 校园账号绑定、校园网登录
- 校园服务页面用 ArkWeb 打开学校站点，注入脚本读取数据，按域限制桥接能力
- 扫码、分享（二维码 / 文本）、课程与配色互传
- 同步到系统日历、课前与考试提醒、桌面课表卡片（Form Kit）、长按应用图标快捷入口

**设置**

- 通用（触感、提醒、免打扰、缓存与日志）、外观（主题、背景、语言）、课表、开发者选项

## 尚未接通

- Sentry 遥测、应用内反馈、通用网页自动化
- 更新入口目前打开上游发布页，未接应用市场更新
- 系统卡片、提醒、扫码、校园服务需真机验证；教务登录与校园网需要可用的学校账号与校园网络

## 架构

```
harmony/
├─ AppScope/                    应用级配置（包名、图标、版本）
├─ entry/src/main/
│  ├─ ets/
│  │  ├─ entryability/          UIAbility 入口、窗口与主题
│  │  ├─ pages/Index.ets        单页路由：四个主页 + 全部二级页面 + 弹层
│  │  ├─ components/            课表、考试、课程编辑、弹层、菜单、校园网页
│  │  ├─ model/                 数据模型、课表算法、设置菜单、课程草稿
│  │  └─ services/              日历同步、桌面卡片、校园网、小程序桥
│  ├─ resources/rawfile/        由上游同步的翻译、功能入口表、教务脚本
│  └─ module.json5              Ability、权限、卡片与快捷入口声明
├─ scripts/                     上游资源同步、源码核对脚本
├─ Build.ps1                    命令行构建
└─ build-profile.json5          SDK 与产品配置
```

几处关键实现：

- **路由**：`Index.ets` 用 `NavPathStack` + `Navigation` 管理二级页面，页面标题栏仍为自绘以保留沉浸光感；`onBackPressed` 先处理弹层与网页历史，再交还系统弹栈。
- **校园网页**：`components/CampusWeb.ets` 承载 ArkWeb，`model/AcademicBinding.ets` 与 `resources/rawfile/*.js` 负责统一认证与教务解析，桥接能力按来源域白名单放行。
- **课表**：`model/Iwut.ets` 的 `timetableBlocks` 合并跨节次课程并计算重叠；`components/Timetable.ets` 只负责绘制。
- **数据**：`LocalData` 落在应用沙箱，账号凭据不落盘，仅存在 WebView 会话中。

## 构建

前置：[DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 26.0.0 Release 或更新版本（自带 HarmonyOS SDK、hvigor、ohpm 与 node）。

```powershell
# 命令行构建（PowerShell 7 或 Windows PowerShell 5.1 均可）
.\harmony\Build.ps1 -DevEcoRoot 'D:\dev\DevEco Studio'
```

也可以在 DevEco Studio 中直接打开 `harmony/` 目录再 Run。

- 未配置签名时输出 `harmony\artifacts\iwut-harmony-unsigned.hap`，只能用于检查构建结果
- 要装到真机需签名：用 DevEco 的自动签名，或把调试证书、profile 写入 `harmony\.sign\sign-config.json5`（该文件含口令，已在 `.gitignore` 中，不随仓库分发）；随后 hvigor 会额外产出 `entry\build\default\outputs\default\entry-default-signed.hap`
- 安装：连接已开启调试的鸿蒙设备后 `hdc install -r <signed.hap>`

## 资源同步与核对

`harmony/scripts` 下的脚本从仓库内的上游源码生成翻译、功能入口、课表资源与教务脚本，并核对移植结果是否与基线一致：

```powershell
$sdkTs = 'D:\dev\DevEco Studio\sdk\default\openharmony\ets\build-tools\ets-loader\node_modules\typescript'

node .\harmony\scripts\sync-upstream.cjs $sdkTs   # 从上游源码同步资源
node .\harmony\scripts\verify-source.cjs $sdkTs   # 核对导航顺序、设置顺序、课表合并、计时与桥接域限制
```

## 上游 RN 工程

仓库根目录仍是完整的 Expo 工程（`app/`、`components/`、`hooks/`、`lib/` 等），与本移植版并行维护，开发方式见 [上游仓库](https://github.com/TokenTeam/iwut)：

```bash
bun install --frozen-lockfile
bun run start
```

根 `tsconfig.json` 与 CI（`Lint`、`Prebuild`）只针对 RN 工程，`harmony/` 目录不参与其类型检查。

## 许可

本项目基于 [TokenTeam/iwut](https://github.com/TokenTeam/iwut) `10335a5` 修改，按 **GNU Affero General Public License v3.0 或后续版本**授权，详见 [LICENSE](./LICENSE)。若修改后通过网络向用户提供服务，需按 AGPLv3 向这些用户提供对应源代码。

使用、修改或再分发本项目表示您已阅读并同意[用户协议](./docs/legal/USER_AGREEMENT.zh-CN.md)与[隐私政策](./docs/legal/PRIVACY_POLICY.zh-CN.md)。

界面文案、图标与教务脚本来自上游；校园服务与教务数据归武汉理工大学所有，本项目与学校官方无关。

## 致谢

- [TokenTeam/iwut](https://github.com/TokenTeam/iwut)：功能定义、文案、资源与教务解析的基线
- HarmonyOS 设计套件 `HdsTabs`、ArkUI `Navigation` / `Navigation` 转场能力
