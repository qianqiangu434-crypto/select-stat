//
// PopupWindow.swift
//
// 悬浮 NSPanel：黑底白字 + 圆角，显示"XX 字 · 约 YY 秒"，2.5 秒后自动隐藏。
//
// 行为：
//   - level 调到 maximum，置顶显示
//   - 忽略鼠标事件（不抢焦点、不挡用户操作）
//   - canBecomeKey/MainWindow 均返回 false
//   - 选中内容变化时会刷新文本并重置 2.5s 倒计时
//
import AppKit

final class PopupWindow: NSPanel {

    private var hideTimer: Timer?
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // 浮窗属性
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        // 内容视图：圆角黑底
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 56))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.82).cgColor
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true
        self.contentView = container

        // 文字 label
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.alignment = .center
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])
    }

    /// 不重写 canBecomeKeyWindow/canBecomeMainWindow：
    ///   styleMask 含 .nonactivatingPanel 已经能保证浮窗不抢焦点。
    ///   如果真要重写，Swift 中应使用 `override func canBecomeKeyWindow() -> Bool { return false }`
    ///   这种方法语法（不能写成 computed property）。

    /// 在选区 rect 附近显示浮窗。rect 是 AX 坐标，原点在主屏左上。
    func show(analysis: TextAnalyzer.Analysis, near rect: CGRect) {
        let text = analysis.summary

        // 1. 量文字 → 决定浮窗尺寸
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium)
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let width = min(max(180, ceil(textSize.width) + 32), 480)
        let height: CGFloat = 56

        // 2. 找含 rect 的屏幕（多屏支持）
        guard let screen = screenContaining(rect: rect) else { return }
        let sFrame = screen.frame
        let H = sFrame.height
        let W = sFrame.width

        // 3. 计算垂直位置：优先选区上方，放不下则放下方
        let aboveY = H - rect.minY + 8
        let fitsAbove = (aboveY + height) <= H
        let belowY = H - rect.maxY - 8 - height
        let fitsBelow = belowY >= 0

        let originY: CGFloat
        if fitsAbove {
            originY = aboveY
        } else if fitsBelow {
            originY = belowY
        } else {
            originY = max(0, aboveY) // 兜底：可能略微超出屏幕顶
        }

        // 4. 水平：基于选区中点居中，夹到屏幕可视范围内
        var originX = rect.midX - width / 2
        originX = max(sFrame.minX, min(originX, sFrame.maxX - width))

        // 5. 应用 frame 并刷新
        setFrame(NSRect(x: originX, y: originY, width: width, height: height), display: true)
        label.stringValue = text
        orderFrontRegardless()

        // 6. 重置 2.5s 自动隐藏定时器
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.orderOut(nil)
        }
    }

    func hide() {
        hideTimer?.invalidate()
        orderOut(nil)
    }

    // MARK: - Multi-screen helper
    //
    // AX 返回的 rect 坐标：原点在主屏左上、y 向下增长（CG 系）。
    // AppKit 的 NSScreen.frame 坐标：原点在主屏左下、y 向上增长。
    // 转换公式：appkit_y = total_screen_height - cg_y
    // 这里用 rect 中心点去比对屏幕是否包含该点。
    //
    private func screenContaining(rect: CGRect) -> NSScreen? {
        let totalH = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
        let centerAppKit = CGPoint(x: rect.midX, y: totalH - rect.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(centerAppKit) }) ?? NSScreen.main
    }
}
