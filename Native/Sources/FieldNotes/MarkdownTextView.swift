import AppKit
import SwiftUI

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    let documentID: UUID
    var font: NSFont
    var lineSpacing: CGFloat

    private var styleKey: String { "\(font.fontName)-\(font.pointSize)-\(lineSpacing)" }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
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
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        var lastDocumentID: UUID?
        var selections: [UUID: [NSValue]] = [:]
        var lastStyleKey = ""
        init(_ parent: MarkdownTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if parent.text != textView.string { parent.text = textView.string }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, let documentID = lastDocumentID else { return }
            selections[documentID] = textView.selectedRanges
        }
    }
}
