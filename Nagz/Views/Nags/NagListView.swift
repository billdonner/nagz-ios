import SwiftUI

struct NagListView: View {
    @State var viewModel: NagListViewModel
    let isGuardian: Bool
    let familyId: UUID
    @State private var showCreateNag = false

    init(apiClient: APIClient, familyId: UUID, isGuardian: Bool) {
        let vm = NagListViewModel(apiClient: apiClient)
        _viewModel = State(initialValue: vm)
        self.familyId = familyId
        self.isGuardian = isGuardian
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $viewModel.filter) {
                ForEach(NagFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                if viewModel.isLoading && viewModel.nags.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.nags.isEmpty {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") { Task { await viewModel.loadNags() } }
                    }
                } else if viewModel.nags.isEmpty {
                    ContentUnavailableView {
                        Label("No Nags", systemImage: "checkmark.circle")
                    } description: {
                        Text(viewModel.filter == .open ? "All caught up!" : "No nags to show.")
                    }
                } else {
                    List {
                        ForEach(viewModel.nags) { nag in
                            NavigationLink(value: nag.id) {
                                NagRowView(nag: nag)
                            }
                            .task {
                                if nag.id == viewModel.nags.last?.id {
                                    await viewModel.loadMore()
                                }
                            }
                        }
                        if viewModel.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Nags")
        .toolbar {
            if isGuardian {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateNag = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateNag) {
            Task { await viewModel.loadNags() }
        } content: {
            CreateNagView(apiClient: viewModel.apiClient, familyId: familyId)
        }
        .task {
            viewModel.setFamily(familyId)
            await viewModel.loadNags()
        }
        .refreshable { await viewModel.refresh() }
        .onChange(of: viewModel.filter) {
            Task { await viewModel.loadNags() }
        }
    }
}
