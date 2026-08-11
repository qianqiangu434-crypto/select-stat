//
// main.swift
//
// 应用入口。
// 仅做一件事：把控制权交给 AppKit 主事件循环，绑定 AppDelegate。
//
// 不写任何网络代码；不申请任何后台运行 entitlement；关闭 App 即彻底退出。
//
import AppKit

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
