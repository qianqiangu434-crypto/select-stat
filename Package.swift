// swift-tools-version: 5.9
//
// SelectStat —— macOS 选区字数统计工具
//
// 这是一个 Swift Package 项目，Xcode 可直接打开运行。
// 不依赖任何第三方包；只用 Apple 自带框架（AppKit、ApplicationServices、Foundation）。
//
// 打开方式：在 Xcode 中 File → Open → 选本文件（Package.swift）
// 运行：选中左上角 SelectStat scheme → ▶ 按钮
//
import PackageDescription

let package = Package(
    name: "SelectStat",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "SelectStat",
            path: "Sources/SelectStat"
        )
    ]
)
