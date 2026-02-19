import SwiftUI

struct ReviewView: View {
    let title: String
    let placeholder: String
    let initialHTML: String
    let onHTMLChange: (String) -> Void
    var onDone: ((String) async -> Void)? = nil
    var showsCancelButton: Bool = false
    var onCancel: (() -> Void)? = nil
    var doneButtonTitle: String = "Save"
    var isDoneDisabled: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var html: String

    init(
        title: String,
        placeholder: String,
        initialHTML: String,
        onHTMLChange: @escaping (String) -> Void,
        onDone: ((String) async -> Void)? = nil,
        showsCancelButton: Bool = false,
        onCancel: (() -> Void)? = nil,
        doneButtonTitle: String = "Save",
        isDoneDisabled: Bool = false
    ) {
        self.title = title
        self.placeholder = placeholder
        self.initialHTML = initialHTML
        self.onHTMLChange = onHTMLChange
        self.onDone = onDone
        self.showsCancelButton = showsCancelButton
        self.onCancel = onCancel
        self.doneButtonTitle = doneButtonTitle
        self.isDoneDisabled = isDoneDisabled
        _html = State(initialValue: initialHTML)
    }

    var body: some View {
        Group {
            if showsCancelButton || onDone != nil {
                baseContent
                    .toolbar {
                        if showsCancelButton {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    onCancel?()
                                    dismiss()
                                }
                            }
                        }

                        if onDone != nil {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(doneButtonTitle) {
                                    Task {
                                        await onDone?(html)
                                    }
                                }
                                .disabled(isDoneDisabled)
                            }
                        }
                    }
            } else {
                baseContent
            }
        }
    }

    private var baseContent: some View {
        VStack(spacing: 0) {
            RichReviewTextView(html: $html, placeholder: placeholder)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
        #if canImport(UIKit)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        #else
        .background(Color(.windowBackgroundColor).ignoresSafeArea())
        #endif
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: html) { _, newValue in
            onHTMLChange(newValue)
        }
        .onDisappear {
            onHTMLChange(html)
        }
    }
}
