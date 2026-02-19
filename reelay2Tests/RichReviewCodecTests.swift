import Foundation
import Testing
@testable import reelay2

struct RichReviewCodecTests {

    @Test
    func parseRecognizedTagsAndKeepsUnknownLiteral() {
        let doc = RichReviewCodec.parseHTML("<b>Hi</b> <foo>x</foo> <i>there</i>")

        #expect(doc.plainText == "Hi <foo>x</foo> there")
        #expect(doc.spans.contains(RichReviewSpan(format: .bold, start: 0, end: 2)))
        #expect(doc.spans.contains(RichReviewSpan(format: .italic, start: 16, end: 21)))
    }

    @Test
    func parseIgnoresUnclosedTags() {
        let doc = RichReviewCodec.parseHTML("start <b>bold")

        #expect(doc.plainText == "start bold")
        #expect(doc.spans.isEmpty)
    }

    @Test
    func serializeRoundTripsMixedFormatting() {
        let original = "<b>Hello</b> <i>there</i> <u>friend</u>"
        let parsed = RichReviewCodec.parseHTML(original)
        let serialized = RichReviewCodec.serialize(document: parsed)

        #expect(serialized == original)
    }

    @Test
    func toggleFormatNoOpForCollapsedSelection() {
        let spans = [RichReviewSpan(format: .bold, start: 0, end: 4)]
        let result = RichReviewCodec.toggleFormat(
            .italic,
            selection: NSRange(location: 2, length: 0),
            in: spans,
            textLength: 4
        )

        #expect(result == spans)
    }

    @Test
    func toggleFormatRemovesSubrangeBySplittingSpan() {
        let spans = [RichReviewSpan(format: .bold, start: 0, end: 10)]
        let result = RichReviewCodec.toggleFormat(
            .bold,
            selection: NSRange(location: 3, length: 4),
            in: spans,
            textLength: 10
        )

        #expect(result == [
            RichReviewSpan(format: .bold, start: 0, end: 3),
            RichReviewSpan(format: .bold, start: 7, end: 10)
        ])
    }

    @Test
    func activeFormatsReflectCaretAndRangeOverlap() {
        let spans = [
            RichReviewSpan(format: .bold, start: 0, end: 5),
            RichReviewSpan(format: .italic, start: 3, end: 8)
        ]

        let caretActive = RichReviewCodec.activeFormats(
            spans: spans,
            selection: NSRange(location: 4, length: 0),
            textLength: 8
        )

        #expect(caretActive.contains(.bold))
        #expect(caretActive.contains(.italic))

        let rangeActive = RichReviewCodec.activeFormats(
            spans: spans,
            selection: NSRange(location: 6, length: 1),
            textLength: 8
        )

        #expect(!rangeActive.contains(.bold))
        #expect(rangeActive.contains(.italic))
    }

    @Test
    func spanAdjustmentShiftsRangesAfterInsert() {
        let spans = [
            RichReviewSpan(format: .underline, start: 6, end: 11)
        ]

        let updated = RichReviewCodec.adjustSpansForTextChange(
            oldText: "hello world",
            newText: "hello brave world",
            spans: spans
        )

        #expect(updated == [RichReviewSpan(format: .underline, start: 12, end: 17)])
    }
}
