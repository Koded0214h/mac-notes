import AppKit
import SwiftUI

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    let documentID: UUID
    var font: NSFont
    var lineSpacing: CGFloat
    var insertTaskToken: Int

    private var styleKey: String { "\(font.fontName)-\(font.pointSize)-\(lineSpacing)" }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = ChecklistTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 14)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.string = text
        applyStyle(to: textView)
        context.coordinator.lastDocumentID = documentID
        context.coordinator.lastStyleKey = styleKey
        context.coordinator.lastInsertTaskToken = insertTaskToken
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        let changedDocument = context.coordinator.lastDocumentID != documentID
        if changedDocument, let previousID = context.coordinator.lastDocumentID {
            context.coordinator.selections[previousID] = textView.selectedRanges
        }

        if textView.string != text || changedDocument {
            let selections = changedDocument ? context.coordinator.selections[documentID] ?? [NSValue(range: NSRange(location: 0, length: 0))] : textView.selectedRanges
            let visibleOrigin = scrollView.contentView.bounds.origin
            textView.string = text
            textView.selectedRanges = selections.compactMap { value in
                let range = value.rangeValue
                let location = min(range.location, text.utf16.count)
                let length = min(range.length, text.utf16.count - location)
                return NSValue(range: NSRange(location: location, length: length))
            }
            scrollView.contentView.scroll(to: visibleOrigin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        context.coordinator.lastDocumentID = documentID
        if context.coordinator.lastStyleKey != styleKey {
            applyStyle(to: textView)
            context.coordinator.lastStyleKey = styleKey
        }
        if context.coordinator.lastInsertTaskToken != insertTaskToken {
            textView.window?.makeFirstResponder(textView)
            (textView as? ChecklistTextView)?.toggleChecklist(nil)
            context.coordinator.lastInsertTaskToken = insertTaskToken
        }
    }

    private func applyStyle(to textView: NSTextView) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.paragraphSpacing = 5
        textView.font = font
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.defaultParagraphStyle = paragraph
        textView.typingAttributes = [.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph]
        if let storage = textView.textStorage, storage.length > 0 {
            storage.addAttributes([.font: font, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph], range: NSRange(location: 0, length: storage.length))
        }
        applyChecklistStyles(to: textView)
    }

    private func applyChecklistStyles(to textView: NSTextView) {
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.strikethroughStyle, range: fullRange)
        storage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

        let expression = try? NSRegularExpression(pattern: #"(?m)^([\t ]*- \[([ xX])\] )(.*)$"#)
        expression?.enumerateMatches(in: storage.string, range: fullRange) { match, _, _ in
            guard let match else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: match.range(at: 1))
            let statusRange = match.range(at: 2)
            let contentRange = match.range(at: 3)
            let checked = (storage.string as NSString).substring(with: statusRange).lowercased() == "x"
            if checked, contentRange.length > 0 {
                storage.addAttributes([
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                ], range: contentRange)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        var lastDocumentID: UUID?
        var selections: [UUID: [NSValue]] = [:]
        var lastStyleKey = ""
        var lastInsertTaskToken = 0
        init(_ parent: MarkdownTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string { parent.text = textView.string }
            parent.applyChecklistStyles(to: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, let documentID = lastDocumentID else { return }
            selections[documentID] = textView.selectedRanges
        }
    }
}

final class ChecklistTextView: NSTextView {
    private static let taskExpression = try! NSRegularExpression(pattern: #"^([\t ]*)- \[([ xX])\] ?"#)

    @objc func toggleChecklist(_ sender: Any?) {
        guard isEditable else { return }
        let source = string as NSString
        let selection = selectedRange()
        let lineRange = source.lineRange(for: selection)
        let selectedLines = source.substring(with: lineRange)
        var lines = selectedLines.components(separatedBy: "\n")
        let endsWithNewline = selectedLines.hasSuffix("\n")
        if endsWithNewline { lines.removeLast() }

        let meaningfulLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let removeTasks = !meaningfulLines.isEmpty && meaningfulLines.allSatisfy { taskMatch(in: $0) != nil }
        let restoredCaret: Int? = selection.length == 0 ? caretLocation(afterToggling: lines.first ?? "", lineStart: lineRange.location, originalLocation: selection.location, removingTask: removeTasks) : nil
        let updatedLines = lines.map { line -> String in
            if removeTasks, let match = taskMatch(in: line) {
                return (line as NSString).replacingCharacters(in: match.range, with: matchIndent(from: line, match: match))
            }
            if taskMatch(in: line) != nil { return line }
            let indent = leadingIndent(in: line)
            let content = String(line.dropFirst(indent.count))
            return indent + "- [ ] " + content
        }
        let replacement = updatedLines.joined(separator: "\n") + (endsWithNewline ? "\n" : "")

        guard shouldChangeText(in: lineRange, replacementString: replacement) else { return }
        textStorage?.replaceCharacters(in: lineRange, with: replacement)
        didChangeText()
        if let restoredCaret {
            setSelectedRange(NSRange(location: restoredCaret, length: 0))
        } else {
            setSelectedRange(NSRange(location: lineRange.location, length: (replacement as NSString).length))
        }
    }

    override func insertNewline(_ sender: Any?) {
        let source = string as NSString
        let selection = selectedRange()
        guard selection.length == 0 else {
            super.insertNewline(sender)
            return
        }

        let lineRange = source.lineRange(for: NSRange(location: min(selection.location, source.length), length: 0))
        let rawLine = source.substring(with: lineRange).trimmingCharacters(in: .newlines)
        guard let match = taskMatch(in: rawLine) else {
            super.insertNewline(sender)
            return
        }

        let prefixEnd = match.range.location + match.range.length
        let content = (rawLine as NSString).substring(from: prefixEnd)
        let indent = matchIndent(from: rawLine, match: match)
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            let replacementRange = NSRange(location: lineRange.location, length: (rawLine as NSString).length)
            guard shouldChangeText(in: replacementRange, replacementString: indent) else { return }
            textStorage?.replaceCharacters(in: replacementRange, with: indent)
            didChangeText()
            setSelectedRange(NSRange(location: replacementRange.location + (indent as NSString).length, length: 0))
            return
        }

        super.insertNewline(sender)
        insertText(indent + "- [ ] ", replacementRange: selectedRange())
    }

    override func mouseDown(with event: NSEvent) {
        guard isEditable, let layoutManager, let textContainer else {
            super.mouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let containerPoint = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let characterIndex = min(layoutManager.characterIndexForGlyph(at: glyphIndex), (string as NSString).length)
        let source = string as NSString
        let lineRange = source.lineRange(for: NSRange(location: characterIndex, length: 0))
        let line = source.substring(with: lineRange).trimmingCharacters(in: .newlines)

        if let match = taskMatch(in: line) {
            let indentLength = match.range(at: 1).length
            let markerRange = NSRange(location: lineRange.location + indentLength + 2, length: 3)
            let glyphRange = layoutManager.glyphRange(forCharacterRange: markerRange, actualCharacterRange: nil)
            var markerRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            markerRect.origin.x += textContainerOrigin.x
            markerRect.origin.y += textContainerOrigin.y
            markerRect = markerRect.insetBy(dx: -4, dy: -3)
            if markerRect.contains(point) {
                let statusRange = NSRange(location: markerRange.location + 1, length: 1)
                let checked = source.substring(with: statusRange).lowercased() == "x"
                let replacement = checked ? " " : "x"
                if shouldChangeText(in: statusRange, replacementString: replacement) {
                    textStorage?.replaceCharacters(in: statusRange, with: replacement)
                    didChangeText()
                    setSelectedRange(NSRange(location: statusRange.location + 1, length: 0))
                }
                return
            }
        }
        super.mouseDown(with: event)
    }

    private func taskMatch(in line: String) -> NSTextCheckingResult? {
        Self.taskExpression.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
    }

    private func matchIndent(from line: String, match: NSTextCheckingResult) -> String {
        (line as NSString).substring(with: match.range(at: 1))
    }

    private func leadingIndent(in line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }

    private func caretLocation(afterToggling line: String, lineStart: Int, originalLocation: Int, removingTask: Bool) -> Int {
        let offset = max(0, originalLocation - lineStart)
        if removingTask, let match = taskMatch(in: line) {
            let indentLength = match.range(at: 1).length
            let markerLength = match.range.length - indentLength
            return lineStart + (offset <= match.range.length ? indentLength : offset - markerLength)
        }
        let indentLength = (leadingIndent(in: line) as NSString).length
        return lineStart + (offset <= indentLength ? indentLength + 6 : offset + 6)
    }
}
