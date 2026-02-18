import SwiftUI

struct LegalDocumentView: View {
    let apiClient: APIClient
    let documentType: LegalDocumentType

    @State private var document: LegalDocument?
    @State private var isLoading = true
    @State private var errorMessage: String?

    enum LegalDocumentType {
        case privacyPolicy
        case termsOfService

        var title: String {
            switch self {
            case .privacyPolicy: "Privacy Policy"
            case .termsOfService: "Terms of Service"
            }
        }

        var endpoint: APIEndpoint {
            switch self {
            case .privacyPolicy: .privacyPolicy()
            case .termsOfService: .termsOfService()
            }
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let document {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Version \(document.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Effective: \(document.effectiveDate)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                        Text(document.content)
                            .font(.body)
                    }
                    .padding()
                }
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            }
        }
        .navigationTitle(documentType.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDocument() }
    }

    private func loadDocument() async {
        isLoading = true
        errorMessage = nil
        do {
            document = try await apiClient.request(documentType.endpoint)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
