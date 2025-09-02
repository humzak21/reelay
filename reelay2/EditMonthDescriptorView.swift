import SwiftUI

struct EditMonthDescriptorView: View {
    let monthYear: String
    let displayMonthYear: String
    @Binding var isPresented: Bool
    @StateObject private var monthDescriptorService = MonthDescriptorService.shared
    
    @State private var descriptorText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Edit Month Descriptor")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    Text("Add a descriptor for \(displayMonthYear)")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Descriptor")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    TextField("e.g., Superhero Mania", text: $descriptorText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            Task {
                                await saveDescriptor()
                            }
                        }
                    
                    Text("The result will appear as: \(previewText)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
                .padding(.horizontal)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: {
                        isPresented = false
                    }) {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Cancel")
                        }
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        Task {
                            await saveDescriptor()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark")
                            }
                            Text("Save")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isLoading ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
        .onAppear {
            setupInitialState()
        }
        .task {
            await loadExistingDescriptor()
        }
    }
    
    private var previewText: String {
        let trimmed = descriptorText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return displayMonthYear
        } else {
            return "\(displayMonthYear) - \(trimmed)"
        }
    }
    
    private func setupInitialState() {
        isTextFieldFocused = true
    }
    
    private func loadExistingDescriptor() async {
        if let existingDescriptor = monthDescriptorService.getDescriptor(for: monthYear) {
            await MainActor.run {
                descriptorText = existingDescriptor
            }
        }
    }
    
    private func saveDescriptor() async {
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await monthDescriptorService.setDescriptor(
                for: monthYear,
                descriptor: descriptorText
            )
            
            await MainActor.run {
                isLoading = false
                isPresented = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to save descriptor: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    EditMonthDescriptorView(
        monthYear: "2025-08",
        displayMonthYear: "August 2025",
        isPresented: .constant(true)
    )
}