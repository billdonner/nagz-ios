import SwiftUI

struct EditNagView: View {
    @State private var viewModel: EditNagViewModel
    @Environment(\.dismiss) private var dismiss

    init(apiClient: APIClient, nag: NagResponse) {
        _viewModel = State(initialValue: EditNagViewModel(apiClient: apiClient, nag: nag))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Due Date") {
                    DatePicker("Due", selection: $viewModel.dueAt, in: Date()...)
                }

                Section("Category") {
                    Picker("Category", selection: $viewModel.category) {
                        ForEach(NagCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.iconName).tag(cat)
                        }
                    }
                }

                Section("Completion Type") {
                    Picker("Done Definition", selection: $viewModel.doneDefinition) {
                        ForEach(DoneDefinition.allCases, id: \.self) { def in
                            Text(def.displayName).tag(def)
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle("Edit Nag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.save() }
                    }
                    .disabled(!viewModel.hasChanges || viewModel.isUpdating)
                }
            }
            .onChange(of: viewModel.didSave) { _, saved in
                if saved { dismiss() }
            }
        }
    }
}
