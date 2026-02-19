import SwiftUI

#if canImport(UIKit)
import UIKit

struct RichReviewTextView: UIViewRepresentable {
    @Binding var html: String
    let placeholder: String
    var autoFocus: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> RichReviewEditorContainerView {
        let container = RichReviewEditorContainerView()
        container.placeholderLabel.text = placeholder

        let textView = container.textView
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 4, bottom: 12, right: 4)
        textView.font = UIFont.preferredFont(forTextStyle: .body)

        context.coordinator.bind(container: container)
        context.coordinator.buildToolbar(for: textView)
        context.coordinator.syncFromExternalHTMLIfNeeded(force: true)

        if autoFocus {
            DispatchQueue.main.async {
                textView.becomeFirstResponder()
            }
        }

        return container
    }

    func updateUIView(_ container: RichReviewEditorContainerView, context: Context) {
        context.coordinator.parent = self
        container.placeholderLabel.text = placeholder
        context.coordinator.bind(container: container)
        context.coordinator.syncFromExternalHTMLIfNeeded(force: false)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichReviewTextView

        private var document: RichReviewDocument
        private var lastSerializedHTML: String
        private var isApplyingProgrammaticChange = false
        private let underlineDecorationTag = 91057

        private weak var container: RichReviewEditorContainerView?

        private weak var boldButton: UIButton?
        private weak var italicButton: UIButton?
        private weak var underlineButton: UIButton?

        init(parent: RichReviewTextView) {
            self.parent = parent
            self.document = RichReviewCodec.parseHTML(parent.html)
            self.lastSerializedHTML = RichReviewCodec.serialize(document: self.document)
        }

        func bind(container: RichReviewEditorContainerView) {
            self.container = container
        }

        func buildToolbar(for textView: UITextView) {
            let accessory = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 48))
            accessory.backgroundColor = accessoryBackgroundColor()

            let topBorder = UIView()
            topBorder.translatesAutoresizingMaskIntoConstraints = false
            topBorder.backgroundColor = accessoryTopBorderColor()
            accessory.addSubview(topBorder)

            let leadingStack = UIStackView()
            leadingStack.axis = .horizontal
            leadingStack.spacing = 9
            leadingStack.alignment = .center
            leadingStack.translatesAutoresizingMaskIntoConstraints = false

            let trailingStack = UIStackView()
            trailingStack.axis = .horizontal
            trailingStack.spacing = 9
            trailingStack.alignment = .center
            trailingStack.translatesAutoresizingMaskIntoConstraints = false

            let bold = makeFormatButton(title: "B")
            bold.addTarget(self, action: #selector(toggleBold), for: .touchUpInside)
            leadingStack.addArrangedSubview(bold)

            let italic = makeFormatButton(title: "I")
            italic.addTarget(self, action: #selector(toggleItalic), for: .touchUpInside)
            leadingStack.addArrangedSubview(italic)

            let underline = makeFormatButton(title: "U")
            underline.addTarget(self, action: #selector(toggleUnderline), for: .touchUpInside)
            leadingStack.addArrangedSubview(underline)

            let undo = makeDisabledCircularButton(systemName: "arrow.uturn.backward")
            trailingStack.addArrangedSubview(undo)

            let redo = makeDisabledCircularButton(systemName: "arrow.uturn.forward")
            trailingStack.addArrangedSubview(redo)

            let spacer = UIView()
            spacer.translatesAutoresizingMaskIntoConstraints = false

            let contentStack = UIStackView(arrangedSubviews: [leadingStack, spacer, trailingStack])
            contentStack.axis = .horizontal
            contentStack.alignment = .center
            contentStack.spacing = 0
            contentStack.translatesAutoresizingMaskIntoConstraints = false

            accessory.addSubview(contentStack)

            NSLayoutConstraint.activate([
                topBorder.topAnchor.constraint(equalTo: accessory.topAnchor),
                topBorder.leadingAnchor.constraint(equalTo: accessory.leadingAnchor),
                topBorder.trailingAnchor.constraint(equalTo: accessory.trailingAnchor),
                topBorder.heightAnchor.constraint(equalToConstant: 0.5),

                contentStack.leadingAnchor.constraint(equalTo: accessory.leadingAnchor, constant: 12),
                contentStack.trailingAnchor.constraint(equalTo: accessory.trailingAnchor, constant: -12),
                contentStack.topAnchor.constraint(equalTo: accessory.topAnchor),
                contentStack.bottomAnchor.constraint(equalTo: accessory.safeAreaLayoutGuide.bottomAnchor),
                contentStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 42)
            ])

            textView.inputAccessoryView = accessory

            boldButton = bold
            italicButton = italic
            underlineButton = underline
            updateToolbarState()
        }

        private func makeFormatButton(title: String) -> UIButton {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.layer.cornerRadius = 8
            button.layer.borderWidth = 2
            button.backgroundColor = .clear
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.adjustsImageWhenHighlighted = false

            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 33),
                button.heightAnchor.constraint(equalToConstant: 33)
            ])

            if title == "I" {
                button.titleLabel?.font = UIFont.italicSystemFont(ofSize: 23)
            } else if title == "B" {
                button.titleLabel?.font = UIFont.systemFont(ofSize: 23, weight: .heavy)
            } else if title == "U" {
                button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
                let underlineDecoration = UIView()
                underlineDecoration.translatesAutoresizingMaskIntoConstraints = false
                underlineDecoration.tag = underlineDecorationTag
                underlineDecoration.isUserInteractionEnabled = false
                underlineDecoration.backgroundColor = formatButtonForegroundColor(isActive: false)
                button.addSubview(underlineDecoration)

                NSLayoutConstraint.activate([
                    underlineDecoration.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                    underlineDecoration.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -7),
                    underlineDecoration.widthAnchor.constraint(equalToConstant: 12),
                    underlineDecoration.heightAnchor.constraint(equalToConstant: 1.5)
                ])
            }

            applyFormatButtonStyle(button, format: format(for: title), isActive: false)
            return button
        }

        private func makeDisabledCircularButton(systemName: String) -> UIButton {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.layer.cornerRadius = 16.5
            button.layer.borderWidth = 2
            button.layer.borderColor = disabledCircularButtonBorderColor().cgColor
            button.tintColor = disabledCircularButtonForegroundColor()
            button.isUserInteractionEnabled = false

            if let image = UIImage(systemName: systemName) {
                button.setImage(image, for: .normal)
                button.imageView?.contentMode = .scaleAspectFit
            } else {
                button.setTitle("↺", for: .normal)
            }
            button.alpha = 0.9

            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 33),
                button.heightAnchor.constraint(equalToConstant: 33)
            ])

            return button
        }

        func syncFromExternalHTMLIfNeeded(force: Bool) {
            guard let textView = container?.textView else { return }

            if !force && parent.html == lastSerializedHTML {
                updatePlaceholderVisibility()
                return
            }

            document = RichReviewCodec.parseHTML(parent.html)
            lastSerializedHTML = RichReviewCodec.serialize(document: document)

            let selection = RichReviewCodec.clamp(selection: document.selection, textLength: document.plainText.utf16.count)
            applyDocument(to: textView, selection: selection, syncBinding: false)
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else { return }

            let newText = textView.text ?? ""
            let oldText = document.plainText

            document.spans = RichReviewCodec.adjustSpansForTextChange(
                oldText: oldText,
                newText: newText,
                spans: document.spans
            )
            document.plainText = newText
            document.selection = RichReviewCodec.clamp(
                selection: textView.selectedRange,
                textLength: newText.utf16.count
            )

            applyDocument(to: textView, selection: document.selection, syncBinding: true)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplyingProgrammaticChange else { return }

            document.selection = RichReviewCodec.clamp(
                selection: textView.selectedRange,
                textLength: document.plainText.utf16.count
            )
            updateToolbarState()
        }

        @objc
        private func toggleBold() {
            toggle(.bold)
        }

        @objc
        private func toggleItalic() {
            toggle(.italic)
        }

        @objc
        private func toggleUnderline() {
            toggle(.underline)
        }

        private func toggle(_ format: RichReviewFormat) {
            guard let textView = container?.textView else { return }

            let textLength = document.plainText.utf16.count
            let selection = RichReviewCodec.clamp(selection: textView.selectedRange, textLength: textLength)
            guard selection.length > 0 else {
                updateToolbarState()
                return
            }

            document.selection = selection
            document.spans = RichReviewCodec.toggleFormat(
                format,
                selection: selection,
                in: document.spans,
                textLength: textLength
            )

            applyDocument(to: textView, selection: selection, syncBinding: true)
        }

        private func applyDocument(to textView: UITextView, selection: NSRange, syncBinding: Bool) {
            let textLength = document.plainText.utf16.count
            let clampedSelection = RichReviewCodec.clamp(selection: selection, textLength: textLength)
            document.selection = clampedSelection

            let attributed = RichReviewCodec.makeAttributedString(document: document)

            isApplyingProgrammaticChange = true
            textView.attributedText = attributed
            textView.selectedRange = clampedSelection
            isApplyingProgrammaticChange = false

            updatePlaceholderVisibility()
            updateToolbarState()

            if syncBinding {
                syncHTMLToBinding()
            }
        }

        private func syncHTMLToBinding() {
            let serialized = RichReviewCodec.serialize(document: document)
            guard serialized != lastSerializedHTML else { return }

            lastSerializedHTML = serialized
            parent.html = serialized
        }

        private func updateToolbarState() {
            let active = RichReviewCodec.activeFormats(
                spans: document.spans,
                selection: document.selection,
                textLength: document.plainText.utf16.count
            )

            applyFormatButtonStyle(boldButton, format: .bold, isActive: active.contains(.bold))
            applyFormatButtonStyle(italicButton, format: .italic, isActive: active.contains(.italic))
            applyFormatButtonStyle(underlineButton, format: .underline, isActive: active.contains(.underline))
        }

        private func updatePlaceholderVisibility() {
            container?.placeholderLabel.isHidden = !document.plainText.isEmpty
        }

        private func applyFormatButtonStyle(_ button: UIButton?, format: RichReviewFormat, isActive: Bool) {
            guard let button else { return }

            button.layer.borderColor = formatButtonBorderColor(isActive: isActive).cgColor
            button.backgroundColor = formatButtonFillColor(isActive: isActive)

            switch format {
            case .bold:
                button.setTitle("B", for: .normal)
                button.setTitle("B", for: .highlighted)
                button.setTitle("B", for: .selected)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 23, weight: .heavy)
                let color = formatButtonForegroundColor(isActive: isActive)
                button.setTitleColor(color, for: .normal)
                button.setTitleColor(color, for: .highlighted)
                button.setTitleColor(color, for: .selected)
            case .italic:
                button.setTitle("I", for: .normal)
                button.setTitle("I", for: .highlighted)
                button.setTitle("I", for: .selected)
                button.titleLabel?.font = UIFont.italicSystemFont(ofSize: 23)
                let color = formatButtonForegroundColor(isActive: isActive)
                button.setTitleColor(color, for: .normal)
                button.setTitleColor(color, for: .highlighted)
                button.setTitleColor(color, for: .selected)
            case .underline:
                let color = formatButtonForegroundColor(isActive: isActive)
                button.setAttributedTitle(nil, for: .normal)
                button.setAttributedTitle(nil, for: .highlighted)
                button.setAttributedTitle(nil, for: .selected)
                button.setTitle("U", for: .normal)
                button.setTitle("U", for: .highlighted)
                button.setTitle("U", for: .selected)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
                button.setTitleColor(color, for: .normal)
                button.setTitleColor(color, for: .highlighted)
                button.setTitleColor(color, for: .selected)
                if let underlineDecoration = button.viewWithTag(underlineDecorationTag) {
                    underlineDecoration.backgroundColor = color
                }
            }
        }

        private func format(for title: String) -> RichReviewFormat {
            switch title {
            case "I":
                return .italic
            case "U":
                return .underline
            default:
                return .bold
            }
        }

        private func accessoryBackgroundColor() -> UIColor {
            UIColor.black.withAlphaComponent(0.15)
        }

        private func accessoryTopBorderColor() -> UIColor {
            UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor.black.withAlphaComponent(0.15)
                }
                return UIColor.white
            }
        }

        private func formatButtonForegroundColor(isActive: Bool) -> UIColor {
            if isActive {
                return .white
            }
            return UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(red: 199.0 / 255.0, green: 214.0 / 255.0, blue: 228.0 / 255.0, alpha: 1.0) : UIColor(red: 59.0 / 255.0, green: 81.0 / 255.0, blue: 103.0 / 255.0, alpha: 1.0)
            }
        }

        private func formatButtonBorderColor(isActive: Bool) -> UIColor {
            if isActive {
                return UIColor(red: 0.0, green: 0.88, blue: 0.42, alpha: 1.0)
            }
            return UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(red: 150.0 / 255.0, green: 172.0 / 255.0, blue: 191.0 / 255.0, alpha: 1.0) : UIColor(red: 118.0 / 255.0, green: 142.0 / 255.0, blue: 165.0 / 255.0, alpha: 1.0)
            }
        }

        private func formatButtonFillColor(isActive: Bool) -> UIColor {
            if isActive {
                return UIColor(red: 0.0, green: 0.88, blue: 0.42, alpha: 0.18)
            }
            return .clear
        }

        private func disabledCircularButtonBorderColor() -> UIColor {
            UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(red: 113.0 / 255.0, green: 134.0 / 255.0, blue: 155.0 / 255.0, alpha: 1.0) : UIColor(red: 137.0 / 255.0, green: 157.0 / 255.0, blue: 177.0 / 255.0, alpha: 1.0)
            }
        }

        private func disabledCircularButtonForegroundColor() -> UIColor {
            UIColor { trait in
                trait.userInterfaceStyle == .dark ? UIColor(red: 113.0 / 255.0, green: 134.0 / 255.0, blue: 155.0 / 255.0, alpha: 1.0) : UIColor(red: 137.0 / 255.0, green: 157.0 / 255.0, blue: 177.0 / 255.0, alpha: 1.0)
            }
        }
    }
}

final class RichReviewEditorContainerView: UIView {
    let textView = UITextView()
    let placeholderLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear

        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.font = UIFont.preferredFont(forTextStyle: .body)
        placeholderLabel.numberOfLines = 0
        addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),

            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 10),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor, constant: -10),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 20)
        ])
    }
}

#else

struct RichReviewTextView: View {
    @Binding var html: String
    let placeholder: String
    var autoFocus: Bool = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            if html.isEmpty {
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
            }

            TextEditor(text: $html)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#endif
