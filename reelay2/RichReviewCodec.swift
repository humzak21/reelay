import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias NativeFont = UIFont
private typealias NativeColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias NativeFont = NSFont
private typealias NativeColor = NSColor
#endif

enum RichReviewFormat: CaseIterable, Hashable {
    case bold
    case italic
    case underline

    var tagName: String {
        switch self {
        case .bold:
            return "b"
        case .italic:
            return "i"
        case .underline:
            return "u"
        }
    }

    var openTag: String { "<\(tagName)>" }
    var closeTag: String { "</\(tagName)>" }
}

struct RichReviewSpan: Hashable {
    var format: RichReviewFormat
    var start: Int
    var end: Int
}

struct RichReviewDocument: Hashable {
    var plainText: String
    var spans: [RichReviewSpan]
    var selection: NSRange

    init(plainText: String, spans: [RichReviewSpan], selection: NSRange = NSRange(location: 0, length: 0)) {
        self.plainText = plainText
        let textLength = plainText.utf16.count
        self.spans = RichReviewCodec.normalize(spans: spans, textLength: textLength)
        self.selection = RichReviewCodec.clamp(selection: selection, textLength: textLength)
    }
}

enum RichReviewCodec {
    static func parseHTML(_ html: String) -> RichReviewDocument {
        var plainText = ""
        plainText.reserveCapacity(html.count)

        var spans: [RichReviewSpan] = []
        var openTagStarts: [RichReviewFormat: [Int]] = [:]

        var index = html.startIndex
        var plainUTF16Length = 0

        while index < html.endIndex {
            if let tagMatch = matchedTag(in: html, at: index) {
                if tagMatch.isOpening {
                    openTagStarts[tagMatch.format, default: []].append(plainUTF16Length)
                } else if var starts = openTagStarts[tagMatch.format], let lastStart = starts.popLast() {
                    openTagStarts[tagMatch.format] = starts
                    if lastStart < plainUTF16Length {
                        spans.append(RichReviewSpan(format: tagMatch.format, start: lastStart, end: plainUTF16Length))
                    }
                }

                index = html.index(index, offsetBy: tagMatch.length)
                continue
            }

            let character = html[index]
            plainText.append(character)
            plainUTF16Length += String(character).utf16.count
            index = html.index(after: index)
        }

        return RichReviewDocument(
            plainText: plainText,
            spans: normalize(spans: spans, textLength: plainUTF16Length),
            selection: NSRange(location: plainUTF16Length, length: 0)
        )
    }

    static func serialize(document: RichReviewDocument) -> String {
        let textLength = document.plainText.utf16.count
        let normalizedSpans = normalize(spans: document.spans, textLength: textLength)
        let plainNSString = document.plainText as NSString

        struct TagInsert {
            let position: Int
            let text: String
            let priority: Int
        }

        var inserts: [TagInsert] = []
        inserts.reserveCapacity(normalizedSpans.count * 2)

        for span in normalizedSpans {
            inserts.append(TagInsert(position: span.start, text: span.format.openTag, priority: 1))
            inserts.append(TagInsert(position: span.end, text: span.format.closeTag, priority: 0))
        }

        inserts.sort {
            if $0.position != $1.position {
                return $0.position < $1.position
            }
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return $0.text < $1.text
        }

        var output = ""
        output.reserveCapacity(document.plainText.count + inserts.reduce(0) { $0 + $1.text.count })

        var cursor = 0
        for insert in inserts {
            if insert.position > cursor {
                output += plainNSString.substring(with: NSRange(location: cursor, length: insert.position - cursor))
            }
            output += insert.text
            cursor = insert.position
        }

        if cursor < textLength {
            output += plainNSString.substring(with: NSRange(location: cursor, length: textLength - cursor))
        }

        return output
    }

    static func stripForPlainPreview(_ html: String) -> String {
        let pattern = "<[^>]*>"
        let nsRange = NSRange(location: 0, length: (html as NSString).length)

        let withoutTags: String
        if let regex = try? NSRegularExpression(pattern: pattern) {
            withoutTags = regex.stringByReplacingMatches(in: html, options: [], range: nsRange, withTemplate: "")
        } else {
            withoutTags = html
        }

        return withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func activeFormats(spans: [RichReviewSpan], selection: NSRange, textLength: Int) -> Set<RichReviewFormat> {
        let clampedSelection = clamp(selection: selection, textLength: textLength)
        let start = clampedSelection.location
        let end = clampedSelection.location + clampedSelection.length

        return Set(RichReviewFormat.allCases.filter { format in
            if clampedSelection.length == 0 {
                return spans.contains(where: { span in
                    span.format == format && span.start <= start && start < span.end
                })
            }

            return spans.contains(where: { span in
                span.format == format && span.start < end && span.end > start
            })
        })
    }

    static func toggleFormat(
        _ format: RichReviewFormat,
        selection: NSRange,
        in spans: [RichReviewSpan],
        textLength: Int
    ) -> [RichReviewSpan] {
        let clampedSelection = clamp(selection: selection, textLength: textLength)
        guard clampedSelection.length > 0 else {
            return normalize(spans: spans, textLength: textLength)
        }

        let selectionStart = clampedSelection.location
        let selectionEnd = clampedSelection.location + clampedSelection.length

        if isSelectionFullyFormatted(format: format, selection: clampedSelection, spans: spans, textLength: textLength) {
            var updated: [RichReviewSpan] = []
            updated.reserveCapacity(spans.count + 2)

            for span in spans {
                guard span.format == format else {
                    updated.append(span)
                    continue
                }

                if span.end <= selectionStart || span.start >= selectionEnd {
                    updated.append(span)
                    continue
                }

                if span.start < selectionStart {
                    updated.append(RichReviewSpan(format: format, start: span.start, end: selectionStart))
                }

                if span.end > selectionEnd {
                    updated.append(RichReviewSpan(format: format, start: selectionEnd, end: span.end))
                }
            }

            return normalize(spans: updated, textLength: textLength)
        }

        var updated = spans
        updated.append(RichReviewSpan(format: format, start: selectionStart, end: selectionEnd))
        return normalize(spans: updated, textLength: textLength)
    }

    static func adjustSpansForTextChange(oldText: String, newText: String, spans: [RichReviewSpan]) -> [RichReviewSpan] {
        if oldText == newText {
            return normalize(spans: spans, textLength: newText.utf16.count)
        }

        let oldUTF16 = Array(oldText.utf16)
        let newUTF16 = Array(newText.utf16)

        let commonLength = min(oldUTF16.count, newUTF16.count)
        var changeStart = 0
        while changeStart < commonLength && oldUTF16[changeStart] == newUTF16[changeStart] {
            changeStart += 1
        }

        let lengthDiff = newUTF16.count - oldUTF16.count
        let newLength = newUTF16.count

        let adjusted = spans.compactMap { span -> RichReviewSpan? in
            var updated = span

            if updated.end <= changeStart {
                // Unchanged span before the edit.
            } else if updated.start >= changeStart {
                updated.start += lengthDiff
                updated.end += lengthDiff
            } else {
                updated.end += lengthDiff
            }

            updated.start = max(0, min(updated.start, newLength))
            updated.end = max(0, min(updated.end, newLength))

            return updated.start < updated.end ? updated : nil
        }

        return normalize(spans: adjusted, textLength: newLength)
    }

    static func normalize(spans: [RichReviewSpan], textLength: Int) -> [RichReviewSpan] {
        let clamped = spans.compactMap { span -> RichReviewSpan? in
            var copy = span
            copy.start = max(0, min(copy.start, textLength))
            copy.end = max(0, min(copy.end, textLength))
            return copy.start < copy.end ? copy : nil
        }

        var merged: [RichReviewSpan] = []

        for format in RichReviewFormat.allCases {
            let sorted = clamped
                .filter { $0.format == format }
                .sorted { lhs, rhs in
                    if lhs.start != rhs.start {
                        return lhs.start < rhs.start
                    }
                    return lhs.end < rhs.end
                }

            var formatMerged: [RichReviewSpan] = []
            for span in sorted {
                if let last = formatMerged.last, span.start <= last.end {
                    formatMerged[formatMerged.count - 1] = RichReviewSpan(
                        format: format,
                        start: last.start,
                        end: max(last.end, span.end)
                    )
                } else {
                    formatMerged.append(span)
                }
            }

            merged.append(contentsOf: formatMerged)
        }

        return merged.sorted {
            if $0.start != $1.start {
                return $0.start < $1.start
            }
            if $0.end != $1.end {
                return $0.end < $1.end
            }
            return formatSortOrder($0.format) < formatSortOrder($1.format)
        }
    }

    static func clamp(selection: NSRange, textLength: Int) -> NSRange {
        let start = max(0, min(selection.location, textLength))
        let length = max(0, min(selection.length, textLength - start))
        return NSRange(location: start, length: length)
    }

    static func toAttributedString(_ html: String) -> AttributedString {
        let document = parseHTML(html)

        #if canImport(UIKit) || canImport(AppKit)
        let nsAttributed = makeAttributedString(document: document)
        if let attributed = try? AttributedString(nsAttributed) {
            return attributed
        }
        #endif

        return AttributedString(document.plainText)
    }

    #if canImport(UIKit) || canImport(AppKit)
    static func makeAttributedString(document: RichReviewDocument) -> NSAttributedString {
        let textLength = document.plainText.utf16.count
        let normalizedSpans = normalize(spans: document.spans, textLength: textLength)

        let baseFont = baseBodyFont()
        let attributed = NSMutableAttributedString(
            string: document.plainText,
            attributes: [
                .font: baseFont,
                .foregroundColor: bodyTextColor()
            ]
        )

        guard textLength > 0 else {
            return attributed
        }

        var styleBits = Array(repeating: SpanStyleBits(), count: textLength)

        for span in normalizedSpans {
            let start = max(0, min(span.start, textLength))
            let end = max(0, min(span.end, textLength))
            guard start < end else { continue }

            let bit: SpanStyleBits
            switch span.format {
            case .bold:
                bit = .bold
            case .italic:
                bit = .italic
            case .underline:
                bit = .underline
            }

            for index in start..<end {
                styleBits[index].insert(bit)
            }
        }

        var runStart = 0
        while runStart < textLength {
            let bits = styleBits[runStart]
            var runEnd = runStart + 1

            while runEnd < textLength && styleBits[runEnd] == bits {
                runEnd += 1
            }

            var attributes: [NSAttributedString.Key: Any] = [
                .font: font(for: bits, baseFont: baseFont),
                .foregroundColor: bodyTextColor()
            ]

            if bits.contains(.underline) {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }

            attributed.addAttributes(attributes, range: NSRange(location: runStart, length: runEnd - runStart))
            runStart = runEnd
        }

        return attributed
    }
    #endif
}

private extension RichReviewCodec {
    struct MatchedTag {
        let format: RichReviewFormat
        let isOpening: Bool
        let length: Int
    }

    struct SpanStyleBits: OptionSet, Equatable {
        let rawValue: Int

        static let bold = SpanStyleBits(rawValue: 1 << 0)
        static let italic = SpanStyleBits(rawValue: 1 << 1)
        static let underline = SpanStyleBits(rawValue: 1 << 2)
    }

    static func matchedTag(in text: String, at index: String.Index) -> MatchedTag? {
        for format in RichReviewFormat.allCases {
            if hasCaseInsensitivePrefix(text, from: index, prefix: format.openTag) {
                return MatchedTag(format: format, isOpening: true, length: format.openTag.count)
            }

            if hasCaseInsensitivePrefix(text, from: index, prefix: format.closeTag) {
                return MatchedTag(format: format, isOpening: false, length: format.closeTag.count)
            }
        }

        return nil
    }

    static func hasCaseInsensitivePrefix(_ text: String, from index: String.Index, prefix: String) -> Bool {
        guard let endIndex = text.index(index, offsetBy: prefix.count, limitedBy: text.endIndex) else {
            return false
        }

        let slice = text[index..<endIndex]
        return slice.compare(prefix, options: [.caseInsensitive, .literal]) == .orderedSame
    }

    static func isSelectionFullyFormatted(
        format: RichReviewFormat,
        selection: NSRange,
        spans: [RichReviewSpan],
        textLength: Int
    ) -> Bool {
        let clampedSelection = clamp(selection: selection, textLength: textLength)
        let selectionStart = clampedSelection.location
        let selectionEnd = clampedSelection.location + clampedSelection.length

        guard selectionStart < selectionEnd else { return false }

        let overlaps = spans
            .filter { $0.format == format && $0.start < selectionEnd && $0.end > selectionStart }
            .map {
                RichReviewSpan(
                    format: format,
                    start: max(selectionStart, $0.start),
                    end: min(selectionEnd, $0.end)
                )
            }
            .sorted { lhs, rhs in
                if lhs.start != rhs.start {
                    return lhs.start < rhs.start
                }
                return lhs.end < rhs.end
            }

        guard var coverage = overlaps.first else {
            return false
        }

        if coverage.start > selectionStart {
            return false
        }

        for span in overlaps.dropFirst() {
            if span.start > coverage.end {
                return false
            }
            coverage.end = max(coverage.end, span.end)
            if coverage.end >= selectionEnd {
                return true
            }
        }

        return coverage.end >= selectionEnd
    }

    static func formatSortOrder(_ format: RichReviewFormat) -> Int {
        switch format {
        case .bold:
            return 0
        case .italic:
            return 1
        case .underline:
            return 2
        }
    }

    #if canImport(UIKit) || canImport(AppKit)
    static func baseBodyFont() -> NativeFont {
        #if canImport(UIKit)
        return .preferredFont(forTextStyle: .body)
        #else
        return .systemFont(ofSize: NSFont.systemFontSize)
        #endif
    }

    static func font(for bits: SpanStyleBits, baseFont: NativeFont) -> NativeFont {
        #if canImport(UIKit)
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bits.contains(.bold) { traits.insert(.traitBold) }
        if bits.contains(.italic) { traits.insert(.traitItalic) }

        let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) ?? baseFont.fontDescriptor
        return UIFont(descriptor: descriptor, size: baseFont.pointSize)
        #else
        var traitMask: NSFontTraitMask = []
        if bits.contains(.bold) { traitMask.insert(.boldFontMask) }
        if bits.contains(.italic) { traitMask.insert(.italicFontMask) }

        if traitMask.isEmpty {
            return baseFont
        }

        return NSFontManager.shared.convert(baseFont, toHaveTrait: traitMask)
        #endif
    }

    static func bodyTextColor() -> NativeColor {
        #if canImport(UIKit)
        return .label
        #else
        return .labelColor
        #endif
    }
    #endif
}
