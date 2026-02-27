import SwiftUI

struct ChildLoginView: View {
    @State private var viewModel: ChildLoginViewModel
    @FocusState private var pinFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(authManager: AuthManager) {
        _viewModel = State(initialValue: ChildLoginViewModel(authManager: authManager))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "face.smiling.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.orange)

                Text("Kid Sign In")
                    .font(.title.bold())

                Text("Ask your parent for the Kid Login Code and your username.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Kid Login Code")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. NAG7K2", text: $viewModel.familyCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.title3, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    TextField("Username", text: $viewModel.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    pinField
                }
                .padding(.horizontal)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task { await viewModel.login() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.isValid || viewModel.isLoading)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var pinField: some View {
        VStack(spacing: 8) {
            Text("4-Digit PIN")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    let digit = index < viewModel.pin.count
                        ? String(viewModel.pin[viewModel.pin.index(viewModel.pin.startIndex, offsetBy: index)])
                        : ""
                    Text(digit.isEmpty ? "•" : digit)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .frame(width: 48, height: 56)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(digit.isEmpty ? .tertiary : .primary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { pinFocused = true }

            TextField("", text: $viewModel.pin)
                .keyboardType(.numberPad)
                .focused($pinFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: viewModel.pin) { _, newValue in
                    let filtered = String(newValue.prefix(4).filter(\.isNumber))
                    if filtered != newValue {
                        viewModel.pin = filtered
                    }
                }
        }
    }
}
