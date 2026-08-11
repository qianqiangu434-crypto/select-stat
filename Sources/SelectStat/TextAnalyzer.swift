//
// TextAnalyzer.swift
//
// 纯函数：给定一段文本，统计字数 / 词数、识别语言、估算"说完"所需时间。
// 没有副作用，不依赖任何系统状态；可以脱离 UI 单独测试。
//
// 语言识别规则（极简版）：
//   - 中文按 CJK 字符（Unicode 区段：U+4E00–U+9FFF 等）数
//   - 英文按"连续 ASCII 字母"段数（rough word count）
//   - 同时含中英文 → 视为 mixed，按各自比例分段估算时间
//
// 语速默认值（与 项目进度.md §4 保持一致；改这里一处即可）：
//   - 中文 240 字/分 —— 普通播音语速
//       数据源：Hsieh 2013/2014、Mao 2024、Yuan & Church 2021
//   - 英文 150 wpm —— 日常对话档
//       数据源：Tauroza & Allison (1990)、Laver (1994)、Rodero Antón (2012)
//
import Foundation

enum TextAnalyzer {

    struct Analysis {
        let charCount: Int           // 全文字符数（含标点 / 空格）
        let cjkCount: Int            // 中文字符数（纯 CJK，用于 mixed 模式展示与混合估算）
        let wordCount: Int           // 英文词数（连续 ASCII 字母段数）
        let language: String         // "zh" / "en" / "mixed" / "other"
        let estimatedSeconds: Int    // 说完所需秒数（向上取整，最少 1 秒）

        /// 顶部显示用的摘要文本，例如 "12 字 · 约 3 秒"、"5 词 · 约 2 秒"、"8 字 / 3 词 · 约 4 秒"
        var summary: String {
            let countText: String
            switch language {
            case "en":
                countText = "\(wordCount) 词"
            case "mixed":
                countText = "\(cjkCount) 字 / \(wordCount) 词"
            default:
                countText = "\(charCount) 字"
            }
            let timeText: String
            if estimatedSeconds < 60 {
                timeText = "约 \(estimatedSeconds) 秒"
            } else {
                let m = estimatedSeconds / 60
                let s = estimatedSeconds % 60
                timeText = s == 0 ? "约 \(m) 分" : "约 \(m) 分 \(s) 秒"
            }
            return "\(countText) · \(timeText)"
        }
    }

    // 默认语速常量（如需调整，改这里）
    static let chineseCharsPerMin: Double = 240
    static let englishWordsPerMin: Double = 150

    static func analyze(_ text: String) -> Analysis {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let totalChars = trimmed.count

        // 1) Unicode 区段统计
        var cjkCount = 0
        var latinCount = 0
        for scalar in trimmed.unicodeScalars {
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v) ||
               (0x3400...0x4DBF).contains(v) ||
               (0x20000...0x2A6DF).contains(v) {
                cjkCount += 1
            } else if (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v) {
                latinCount += 1
            }
        }

        // 2) 英文词数：拆分连续 ASCII 字母段
        let wordCount = trimmed
            .split(whereSeparator: { c in
                guard let v = c.asciiValue else { return true }
                return !((0x41...0x5A).contains(v) || (0x61...0x7A).contains(v))
            })
            .count

        // 3) 语言判定
        let language: String
        if cjkCount == 0 && latinCount == 0 {
            language = "other"
        } else if cjkCount == 0 {
            language = "en"
        } else if latinCount == 0 {
            language = "zh"
        } else {
            language = "mixed"
        }

        // 4) 时间估算
        var seconds: Int
        switch language {
        case "zh":
            seconds = Int(ceil(Double(totalChars) / chineseCharsPerMin * 60))
        case "en":
            seconds = Int(ceil(Double(wordCount) / englishWordsPerMin * 60))
        case "mixed":
            let zhSeconds = Double(cjkCount) / chineseCharsPerMin * 60
            let enSeconds = Double(wordCount) / englishWordsPerMin * 60
            seconds = Int(ceil(zhSeconds + enSeconds))
        default:
            // 其它（纯标点 / 数字 / 符号等）：按字符数套中文语速作兜底
            seconds = Int(ceil(Double(totalChars) / chineseCharsPerMin * 60))
        }

        return Analysis(
            charCount: totalChars,
            cjkCount: cjkCount,
            wordCount: wordCount,
            language: language,
            estimatedSeconds: max(seconds, 1)
        )
    }
}
