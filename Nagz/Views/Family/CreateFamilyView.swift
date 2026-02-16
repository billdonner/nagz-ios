import SwiftUI

struct CreateFamilyView: View {
    @Bindable var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Family Name") {
                    TextField("e.g. The Smiths", text: $viewModel.newFamilyName)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.createFamily() }
                    } label: {
                        if viewModel.isCreating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Family")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(viewModel.newFamilyName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isCreating)
                }
            }
            .navigationTitle("New Family")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
