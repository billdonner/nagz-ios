import SwiftUI

struct MemberListView: View {
    @State private var viewModel: MemberListViewModel

    init(apiClient: APIClient, familyId: UUID) {
        _viewModel = State(initialValue: MemberListViewModel(apiClient: apiClient, familyId: familyId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.members.isEmpty {
                ProgressView()
            } else if let error = viewModel.errorMessage, viewModel.members.isEmpty {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await viewModel.loadMembers() } }
                }
            } else {
                List {
                    ForEach(viewModel.members) { member in
                        MemberRowView(member: member)
                            .task {
                                if member.id == viewModel.members.last?.id {
                                    await viewModel.loadMore()
                                }
                            }
                    }
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Members")
        .task { await viewModel.loadMembers() }
        .refreshable { await viewModel.loadMembers() }
    }
}
