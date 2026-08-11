//
// SelectionWatcher.swift
//
// 监听 macOS 系统级文本选区的变化。
//
// 工作机制：
//   每 150ms 通过 Accessibility API 轮询"当前焦点控件"的 kAXSelectedTextAttribute。
//   如果选中文本变了，调用 onSelectionChanged 回调并附带选区的屏幕坐标（CGRect）。
//
// 监听范围：所有原生 macOS 应用 + 大多数跨平台应用（TextEdit、备忘录、Safari、
//           Terminal、VSCode、Slack、微信桌面版等）。密码框 / DRM 内容无法读取。
//
// 设计备注：
//   macOS Accessibility API 没有"选区变化"事件，必须轮询。这是 PopClip 等同类工具的标准做法。
//
import AppKit
import ApplicationServices

final class SelectionWatcher {

    /// 选区变化回调：(选中文本, 选区屏幕坐标 rect)
    var onSelectionChanged: ((String, CGRect) -> Void)?

    private var timer: Timer?
    private var lastText: String = ""

    func start() {
        let t = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.poll()
        }
        // common modes 让 timer 在 UI 交互期间也能正常触发
        RunLoop.current.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard let (text, rect) = readCurrentSelection() else {
            if !lastText.isEmpty {
                lastText = ""
                DispatchQueue.main.async { [weak self] in
                    self?.onSelectionChanged?("", .zero)
                }
            }
            return
        }

        guard text != lastText else { return }
        lastText = text
        DispatchQueue.main.async { [weak self] in
            self?.onSelectionChanged?(text, rect)
        }
    }

    /// 读取当前焦点应用 / 焦点控件的选中文本和屏幕坐标。
    /// 返回 nil 表示当前没有可读选区。
    private func readCurrentSelection() -> (String, CGRect)? {
        // 1. 系统级 AX 句柄
        let systemWide = AXUIElementCreateSystemWide()

        // 2. 当前焦点应用
        var appRef: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &appRef
        )
        guard appResult == .success, let appCF = appRef else { return nil }
        let appElement = appCF as! AXUIElement

        // 3. 当前焦点控件
        var elementRef: CFTypeRef?
        let elementResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &elementRef
        )
        guard elementResult == .success, let elementCF = elementRef else { return nil }
        let element = elementCF as! AXUIElement

        // 4. 选中的文本
        var textRef: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &textRef
        )
        guard textResult == .success, let text = textRef as? String, !text.isEmpty else {
            return nil
        }
        //
        // 注意：kAXBoundsForRange* 是参数化属性（Parameterized Attribute），
        //       必须用 AXUIElementCopyParameterizedAttributeValue 并把 CFRange 作为 parameter 传入。
        //       常量全名是 kAXBoundsForRangeParameterizedAttribute
        //       （注意中间多了 "Parameterized"）。
        //
        // 兼容性备注：
        //   - 原生 App（TextEdit、Safari、Terminal）返回的 rect 是真屏幕坐标，
        //     且和焦点控件自身的 frame 相交。
        //   - Chrome / Chromium 内核 App 可能返回错位的坐标（控件本地坐标，
        //     或 Y 轴翻转等），与自身 frame 不相交。这种情况下回退到焦点控件的
        //     frame —— popup 出现在页面顶部，对于全屏页面来说是可接受的位置。
        //
        var selectionRect: CGRect = .zero

        var rangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeRef
        )
        if rangeResult == .success, let rangeVal = rangeRef {
            var boundsRef: CFTypeRef?
            let boundsResult = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                rangeVal,
                &boundsRef
            )
            if boundsResult == .success, let boundsVal = boundsRef {
                AXValueGetValue(boundsVal as! AXValue, .cgRect, &selectionRect)
            }
        }

        // 焦点控件自身的屏幕坐标（始终拿一份作为基准 + 兑底）
        var elementFrame: CGRect = .zero
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        if posResult == .success, let posVal = posRef,
           sizeResult == .success, let sizeVal = sizeRef {
            var p = CGPoint.zero
            var s = CGSize.zero
            AXValueGetValue(posVal as! AXValue, .cgPoint, &p)
            AXValueGetValue(sizeVal as! AXValue, .cgSize, &s)
            elementFrame = CGRect(origin: p, size: s)
        }

        // 决策: 选择 selectionRect 还是回退到 elementFrame
        let rect: CGRect
        if selectionRect != .zero && elementFrame != .zero {
            // 两个都拿得到：检测 selectionRect 是否在 elementFrame 范围内
            if selectionRect.intersects(elementFrame) {
                rect = selectionRect       // 看起来是屏幕坐标，信任它
            } else {
                rect = elementFrame        // 与 frame 不相交（Chrome 的情况），兑底
            }
        } else if elementFrame != .zero {
            rect = elementFrame            // 没拿到 selectionRect，用 frame
        } else {
            rect = selectionRect           // 都没拿到 frame，仅用 selectionRect
        }

        return (text, rect)
    }
}
