# 选区字数 · SelectStat

> macOS 选中文本字数与播报时间估算小工具。
>
> 选中任意文本 → 立即在选区上方浮出一个小黑框，显示「X 字 · 约 Y 秒」。

![screenshot placeholder — 选中一段文字，上方出现 "12 字 · 约 3 秒" 风格的浮窗]

---

## ✨ 特性

- **即看即明** —— 选中即可，无快捷键、无历史记录
- **多语种** —— 自动识别中文 / 英文 / 中英混排，分别按对应语速估算
- **隐私优先** —— 不联网、不写文件、不缓存文本
- **可审计** —— 单 Swift 包 ~500 行，零三方依赖，肉眼可读

---

## 🚀 安装与运行

### 前置环境

- macOS 13 及以上
- Xcode 15 及以上（[App Store 下载](https://apps.apple.com/cn/app/xcode/id497799835)，约 7GB）

### 三步走

```bash
# 1. 克隆仓库（请将 <USER> 替换为分享者的 GitHub 用户名）
git clone https://github.com/<USER>/select-stat.git
cd select-stat

# 2. 第一次运行：授权执行
chmod +x build_and_run.sh

# 3. 构建 + 启动（会自动弹出辅助功能授权请求）
./build_and_run.sh
```

启动后菜单栏右上角会出现 **「字数」** 图标。
选中任何文本（TextEdit、Safari、微信、备忘录……），即可看到效果。

### 退出

右上角菜单栏 **「字数」** 图标 → **退出**。

### 之后想再启动

在仓库目录里再跑一次 `./build_and_run.sh`。

---

## 🎮 使用说明

启动后，工具一直在后台监听（每 150ms 轮询一次 Accessibility API）。
选中任意文本时，会自动：

1. 读出选区里的文本
2. 统计字数 / 词数
3. 识别语言（中文 / 英文 / 混合）
4. 按语速估算「说完」所需秒数
5. 在选区正上方弹出一个圆角黑框，2.5 秒后自动消失

### 显示格式示例

| 选中内容 | 浮窗显示 |
|----------|---------|
| `你好世界`（4 字） | `4 字 · 约 1 秒` |
| `Hello world how are you`（5 词） | `5 词 · 约 2 秒` |
| `今天 hello 大家好`（混合） | `6 字 / 1 词 · 约 2 秒` |

---

## 🔒 隐私与安全承诺

**这是本项目最重要的一节。** 工具要读取你选中的文字，意味着它能看到你屏幕上发生了什么。所以我把安全边界写在最显眼的地方：

| 担忧 | 实际行为 |
|------|---------|
| **会不会联网？** | **不会。** 项目零三方依赖，只用 Apple 系统框架 `AppKit`、`ApplicationServices`、`Foundation`。代码里**没有任何网络字符串字面量**。 |
| **会不会缓存我的文本？** | **不会。** 选中的文本作为局部变量读进内存，浮窗消失时立刻释放，**不写磁盘、不进剪贴板、不发系统通知**。 |
| **有没有后台偷跑？** | **没有。** 不申请任何后台运行 entitlement，进程退出即彻底结束。 |
| **开了什么权限？** | **仅 Accessibility（辅助功能）一项。** 且只读取 `kAXSelectedTextAttribute`（选中文本）和 `kAXBoundsForRangeParameterizedAttribute`（选区位置）两个属性，绝不录音、绝不读屏。 |
| **会不会传数据？** | **不会。** 同上，零网络调用。 |

### 怎么自己验证

启动后打开终端，跑：

```bash
# 拿 SelectStat 的进程 ID
pgrep SelectStat

# 看它的网络连接（应该啥都没有）
lsof -p <PID> | grep -i tcp

# 看它加载的所有库（应该只有系统库）
lsof -p <PID> | grep -i "\.dylib" | grep -v "/System/" | grep -v "/usr/lib/"
```

两条命令都应该输出空。

---

## 📁 项目结构

```
select-stat/
├── Package.swift                # Swift Package 项目描述
├── build_and_run.sh             # 一键构建 + 启动脚本
├── README.md
└── Sources/SelectStat/
    ├── main.swift               # 入口
    ├── AppDelegate.swift        # 状态栏图标 + 菜单 + 授权请求
    ├── SelectionWatcher.swift   # Accessibility API 监听（核心）
    ├── PopupWindow.swift        # 悬浮 NSPanel + 屏幕定位
    └── TextAnalyzer.swift       # 字数统计 + 语言识别 + 时间估算
```

每个文件顶部都有一段注释，说明它做什么、用什么 API、边界在哪里。

---

## 🧮 语速数据来源

| 语言 | 默认语速 | 数据源 |
|------|---------|--------|
| 中文 | 240 字/分 | Hsieh et al. (2013/2014). "A Speaking Rate-Controlled Mandarin TTS System" · Mao et al. (2024). "Speech Rate Influence on Rhythm Alterations in Mandarin" |
| 英文 | 150 wpm | Tauroza & Allison (1990). "Speech rates in English" · Laver, John (1994). *Principles of Phonetics*, Cambridge, p. 542 |

调整默认值：改 `TextAnalyzer.swift` 里的 `chineseCharsPerMin` 和 `englishWordsPerMin` 两个常量即可。

---

## 🐛 故障排查

| 现象 | 排查 |
|------|------|
| 浮窗不出现 | 系统设置 → 隐私与安全性 → 辅助功能 → 确认 SelectStat 已勾选 |
| 菜单栏看不到「字数」 | 顶部菜单栏空处点右键 → 自定义 → 把 SelectStat 拖到能看见的地方 |
| 每次运行都弹辅助功能授权框 | 给 SelectStat 在系统设置里授权完整；或者用 `tccutil reset Accessibility com.local.SelectStat` 清空后重新授权 |
| 某些 App 里选中不出浮窗 | 密码框 / DRM 受保护内容 / 银行类 App 按设计无法读取，是预期行为 |
| 编译报错 | 确认 macOS ≥ 13、Xcode ≥ 15 |

## 🌐 兼容性

**能用（原生 macOS App）**

- TextEdit、备忘录、Mail、Pages、Numbers、Keynote
- Terminal、脚本编辑器
- Safari（原生页面）
- 钉钉 / 微信（聊天输入框等原生部分）

**需额外配置**

- **Chrome / Chromium 浏览器**：需要用 `--force-renderer-accessibility` 启动。
  ```bash
  /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --force-renderer-accessibility --user-data-dir=/tmp/chrome-test-profile
  ```

**不能用（App 架构限制，非本项目问题）**

- 飞书桌面客户端（Electron，不暴露选区给 macOS AX）
- 小红书桌面客户端（CEF 内核，同上）
- 任何包含密码框 / DRM 保护内容的场景

**判定依据**：项目用 macOS Accessibility API 读 selection，但只有宿主 App 主动暴露选区给系统时才能读到。这是 App 本身的实现限制，不是我们的项目能修的。

---

## 🛣 路线图

- [x] 核心功能（字数、时间、双语种）
- [x] .app 打包 + 一键启动脚本
- [x] 隐私安全文档
- [ ] 同事实测反馈收集
- [ ] 适合语音播报场景的语速校准
- [ ] （如有需求）浮窗位置智能避让

---

## 🙋 我为什么做这个 / Why this exists

> 写一份长文档时，经常想知道"这段大概要念多久"。网页和应用商店里的方案要么要联网、要么要收费、要么隐私边界不清楚。自己写一个半小时的事，还能 100% 看见代码。
