//
// AppDelegate.swift
//
// 职责：
//   1. 在状态栏（菜单栏右侧）显示"字数"图标
//   2. 提供菜单项：授权辅助功能、退出
//   3. 启动 SelectionWatcher 监听系统级选区
//   4. 把选区变化转发给 PopupWindow 显示
//
// 权限：仅请求 Accessibility（辅助功能），用于读取选中文字。
// 隐私：不联网；不写磁盘；不进剪贴板；不发通知。
//
import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var watcher: SelectionWatcher!
    private var popup: PopupWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        checkAccessibilityAndPrompt()

        popup = PopupWindow()

        watcher = SelectionWatcher()
        watcher.onSelectionChanged = { [weak self] text, rect in
            guard let self = self else { return }
            self.handleSelection(text: text, rect: rect)
        }
        watcher.start()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "字数"
            button.toolTip = "选区字数统计工具"
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "授权辅助功能…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
    }

    // MARK: - Permission

    private func checkAccessibilityAndPrompt() {
        // 如果已授权，直接返回
        if AXIsProcessTrustedWithOptions(nil) {
            return
        }
        // 未授权：主动召唤系统授权面板
        // 好处是不需要人去手动加文件；坏处是一次验证取消后每次启动都会再弹一次（因为没记住）
        print("[SelectStat] ⚠️  尚未获得辅助功能权限，下面调出系统授权面板。")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Selection Routing

    private func handleSelection(text: String, rect: CGRect) {
        if text.isEmpty {
            popup.hide()
            return
        }
        let analysis = TextAnalyzer.analyze(text)
        popup.show(analysis: analysis, near: rect)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
