import SwiftUI

struct CommunityVerificationsView: View {
    @StateObject private var viewModel = CommunityVerificationsViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedVerification: CommunityVerification?
    @State private var isShowingActions = false
    @State private var specializationSearchText = ""
    @State private var specializationSearchTask: Task<Void, Never>?
    @State private var verificationSearchText = ""
    @State private var verificationSearchTask: Task<Void, Never>?
    @State private var verificationFlowCommunity: CommunityProfileData?

    var body: some View {
        List {
            Section("Joined Majors & Fields") {
                if !orderedJoinLimits.isEmpty {
                    ForEach(orderedJoinLimits, id: \.specializationType) { limit in
                        HStack(spacing: 10) {
                            Text(limit.pluralLabel)
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextPrimary)
                            Spacer()
                            Text(joinLimitRemainingText(limit))
                                .font(.loopedSubBodyRegular)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                specializationSearchSection
                    .listRowBackground(Color.loopedBackground)

                if viewModel.isLoading && viewModel.joinedSpecializations.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.loopedBackground)
                } else if viewModel.joinedSpecializations.isEmpty {
                    Text("None yet")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                        .listRowBackground(Color.loopedBackground)
                } else {
                    ForEach(viewModel.joinedSpecializations, id: \.id) { specialization in
                        HStack(spacing: 12) {
                            specializationPreview(for: specialization)

                            Text(specialization.displayText)
                                .font(.loopedBodyMedium)
                                .foregroundColor(.loopedTextPrimary)

                            Spacer()

                            if let type = specialization.specializationType?.displayName {
                                Text(type)
                                    .font(.loopedSubBodyRegular)
                                    .foregroundColor(.loopedTextSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                verificationSearchSection

                if viewModel.isLoading && viewModel.items.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.loopedBackground)
                } else if viewModel.items.isEmpty {
                    emptyState
                        .listRowBackground(Color.loopedBackground)
                } else {
                    ForEach(viewModel.items) { verification in
                        verificationRow(verification)
                    }
                }
            }
            header: {
                Text("Companies & Schools")
            } footer: {
                Text("Search to verify another company or school. Tap an active verification to unverify.")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            verifiedEmailsSection

            if let errorMessage = viewModel.errorMessage {
                Section {
                    statusBanner(text: errorMessage, color: .loopedError)
                        .listRowBackground(Color.loopedBackground)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Verifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.load()
            await viewModel.searchSpecializations(query: specializationSearchText)
            await viewModel.searchVerificationCommunities(query: verificationSearchText)
        }
        .sheet(
            item: $verificationFlowCommunity,
            onDismiss: {
                Task {
                    await viewModel.load()
                }
            }
        ) { community in
            CommunityVerificationFlowView(
                community: community,
                onComplete: { _ in
                    Task {
                        await viewModel.load()
                        await authViewModel.loadCurrentUser()
                    }
                }
            )
            .environmentObject(authViewModel)
        }
        .confirmationDialog(
            selectedVerification?.communityName ?? "Verification",
            isPresented: $isShowingActions,
            titleVisibility: .visible
        ) {
            if let selectedVerification, selectedVerification.verified {
                Button("Unverify", role: .destructive) {
                    Task {
                        let didUnverify = await viewModel.unverify(communityId: selectedVerification.communityId)
                        if didUnverify {
                            await authViewModel.loadCurrentUser()
                        }
                    }
                }
                .disabled(viewModel.isUnverifying)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let selectedVerification {
                Text(
                    selectedVerification.isActive
                        ? "Unverifying removes your active verification and releases the email lock for this community."
                        : "Unverifying removes this verification from your account."
                )
            }
        }
        .onChange(of: specializationSearchText) { _, _ in
            scheduleSpecializationSearch()
        }
        .onChange(of: verificationSearchText) { _, _ in
            scheduleVerificationSearch()
        }
        .onDisappear {
            specializationSearchTask?.cancel()
            verificationSearchTask?.cancel()
        }
    }

    private var orderedJoinLimits: [SpecializationJoinLimit] {
        viewModel.joinLimits
            .filter { $0.specializationType != .unknown }
            .sorted { lhs, rhs in
                switch (lhs.specializationType, rhs.specializationType) {
                case (.major, .field):
                    return true
                case (.field, .major):
                    return false
                default:
                    return lhs.pluralLabel < rhs.pluralLabel
                }
            }
    }

    @ViewBuilder
    private func specializationPreview(for specialization: DisplayCommunity) -> some View {
        Group {
            if let icon = specialization.icon?.normalizedOrNil() {
                switch icon.kind {
                case .emoji:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.loopedMutedBackground)
                        .overlay(
                            Text(icon.value)
                                .font(.loopedCustom(.semibold, size: 16))
                                .foregroundColor(.loopedTextPrimary)
                        )
                case .sfSymbol:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.loopedMutedBackground)
                        .overlay(
                            Image(systemName: icon.value)
                                .font(.loopedCustom(.semibold, size: 14))
                                .foregroundColor(.loopedTextPrimary)
                        )
                case .imageUrl:
                    if let url = URL.loopedMediaURL(from: icon.value) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .empty, .failure:
                                specializationPreviewFallback(for: specialization)
                            @unknown default:
                                specializationPreviewFallback(for: specialization)
                            }
                        }
                    } else {
                        specializationPreviewFallback(for: specialization)
                    }
                case .unknown:
                    specializationPreviewFallback(for: specialization)
                }
            } else {
                specializationPreviewFallback(for: specialization)
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func specializationPreviewFallback(for specialization: DisplayCommunity) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.loopedMutedBackground)
            .overlay(
                Text(specialization.initials)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextPrimary)
            )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.loopedCustom(size: 36))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("No community verifications yet")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    @ViewBuilder
    private var verifiedEmailsSection: some View {
        Section {
            if viewModel.isLoading && viewModel.items.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.loopedBackground)
            } else if verifiedEmailItems.isEmpty {
                verifiedEmailsEmptyState
                    .listRowBackground(Color.loopedBackground)
            } else {
                ForEach(verifiedEmailItems) { verification in
                    verifiedEmailRow(verification)
                }
            }
        } header: {
            Text("Verified Emails")
        } footer: {
            Text("Only active email verifications appear here.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
    }

    private var verifiedEmailItems: [CommunityVerification] {
        viewModel.items
            .filter { $0.isActive }
            .filter { ($0.verifiedEmail?.isEmpty == false) }
            .sorted { $0.communityName.localizedCaseInsensitiveCompare($1.communityName) == .orderedAscending }
    }

    private var verifiedEmailsEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "envelope")
                .font(.loopedCustom(size: 34))
                .foregroundColor(.loopedTextSecondary.opacity(0.5))

            Text("No verified emails yet")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            Text("Verify a community with your school/work email to see it here.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func verifiedEmailRow(_ verification: CommunityVerification) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verification.verifiedEmail ?? "")
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)
                    .textSelection(.enabled)

                Text(verification.communityName)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            Spacer()

            Text(statusText(for: verification))
                .font(.loopedSubBodyMedium)
                .foregroundColor(statusColor(for: verification))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor(for: verification).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private func verificationRow(_ verification: CommunityVerification) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verification.communityName)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedTextPrimary)

                Spacer()

                if viewModel.unverifyingCommunityId == verification.communityId {
                    ProgressView()
                        .tint(.loopedSecondary)
                }

                Text(statusText(for: verification))
                    .font(.loopedSubBodyMedium)
                    .foregroundColor(statusColor(for: verification))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(for: verification).opacity(0.12))
                    .clipShape(Capsule())
            }

            if let method = verification.method {
                Text("Method: \(method.displayName)")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            if let verifiedEmail = verification.verifiedEmail, !verifiedEmail.isEmpty {
                Text("Verified email: \(verifiedEmail)")
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
                    .textSelection(.enabled)
            }

            if let expiryText = expiryText(for: verification) {
                Text(expiryText)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(verification.isExpired ? .loopedError : .loopedTextSecondary)
            }

            if verification.status == .rejected,
               let reason = verification.rejectReason?.trimmingCharacters(in: .whitespacesAndNewlines),
               !reason.isEmpty {
                Text(reason)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            if let helperText = helperText(for: verification) {
                Text(helperText)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedTextSecondary)
            }

            if let actionHint = actionHintText(for: verification) {
                Text(actionHint)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard verification.verified else { return }
            selectedVerification = verification
            isShowingActions = true
        }
        .disabled(viewModel.isUnverifying)
    }

    private func expiryText(for verification: CommunityVerification) -> String? {
        if verification.status == .pending || verification.status == .rejected {
            return nil
        }
        guard let expiresAt = verification.expiresAt else {
            return verification.isExpired ? "Expired" : "Never expires"
        }
        let dateText = Self.expiryFormatter.string(from: expiresAt)
        return verification.isExpired ? "Expired \(dateText)" : "Expires \(dateText)"
    }

    private func statusText(for verification: CommunityVerification) -> String {
        switch verification.status {
        case .pending:
            return "Pending"
        case .rejected:
            return "Rejected"
        case .expired:
            return "Expired"
        case .active:
            return "Active"
        case .unknown:
            if !verification.verified {
                return "Pending"
            }
            if verification.isExpired || !verification.active {
                return "Expired"
            }
            return "Active"
        }
    }

    private func statusColor(for verification: CommunityVerification) -> Color {
        switch verification.status {
        case .pending:
            return .loopedSecondary
        case .rejected:
            return .loopedError
        case .expired:
            return .loopedError
        case .active:
            return .loopedSuccess
        case .unknown:
            if !verification.verified {
                return .loopedSecondary
            }
            if verification.isExpired || !verification.active {
                return .loopedError
            }
            return .loopedSuccess
        }
    }

    private func helperText(for verification: CommunityVerification) -> String? {
        switch verification.status {
        case .pending:
            return "Pending review. You’ll see the result here when it’s ready."
        case .rejected:
            return "Rejected. Re-submit to verify again."
        case .expired:
            return "Re-verify to post, comment, and like in this community."
        case .active:
            return nil
        case .unknown:
            if verification.isExpired || !verification.active {
                return "Re-verify to post, comment, and like in this community."
            }
            return nil
        }
    }

    private func actionHintText(for verification: CommunityVerification) -> String? {
        guard verification.verified else { return nil }
        return "Tap to unverify or revoke this verification."
    }

    private func statusBanner(text: String, color: Color) -> some View {
        Text(text)
            .font(.loopedSubBodyRegular)
            .foregroundColor(color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var verificationSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Find a company or school to verify")
                .font(.loopedSubBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.loopedCustom(size: 14))
                    .foregroundColor(.loopedTextSecondary)

                TextField("Search companies and schools", text: $verificationSearchText)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color.loopedMutedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if viewModel.isSearchingVerificationCommunities {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Searching...")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }
            } else if let error = viewModel.verificationSearchError, !error.isEmpty {
                Text(error)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedError)
            } else if !viewModel.verificationSearchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.verificationSearchResults.prefix(6)) { result in
                        Button {
                            verificationFlowCommunity = CommunityProfileData(community: result)
                        } label: {
                            HStack(spacing: 10) {
                                verificationSearchPreview(for: result)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name)
                                        .font(.loopedBodyMedium)
                                        .foregroundColor(.loopedTextPrimary)
                                        .lineLimit(1)
                                    if let short = result.shortName, !short.isEmpty {
                                        Text(short)
                                            .font(.loopedSmallText)
                                            .foregroundColor(.loopedTextSecondary)
                                            .lineLimit(1)
                                    }
                                    Text(result.kind == .school ? "School" : "Company")
                                        .font(.loopedSmallText)
                                        .foregroundColor(.loopedTextSecondary)
                                }
                                Spacer()
                                Text("Verify")
                                    .font(.loopedSmallText)
                                    .foregroundColor(.loopedPrimary)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if result.id != viewModel.verificationSearchResults.prefix(6).last?.id {
                            Divider()
                        }
                    }
                }
            } else if !verificationSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = verificationSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(trimmed.count < 2 ? "Type at least 2 characters." : "No companies or schools found.")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var specializationSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.loopedCustom(size: 14))
                    .foregroundColor(.loopedTextSecondary)

                TextField("Search majors and fields", text: $specializationSearchText)
                    .font(.loopedBody)
                    .foregroundColor(.loopedTextPrimary)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color.loopedMutedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if viewModel.isSearchingSpecializations {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Searching...")
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedTextSecondary)
                }
            } else if let error = viewModel.specializationSearchError, !error.isEmpty {
                Text(error)
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedError)
            } else if !viewModel.specializationSearchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.specializationSearchResults.prefix(6)) { result in
                        NavigationLink(destination: CommunityProfileView(community: CommunityProfileData(community: result))) {
                            HStack(spacing: 10) {
                                specializationSearchPreview(for: result)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name)
                                        .font(.loopedBodyMedium)
                                        .foregroundColor(.loopedTextPrimary)
                                        .lineLimit(1)
                                    Text(result.specializationType == .major ? "Major" : "Field")
                                        .font(.loopedSmallText)
                                        .foregroundColor(.loopedTextSecondary)
                                }
                                Spacer()
                                if result.isJoined == true {
                                    Text("Joined")
                                        .font(.loopedSmallText)
                                        .foregroundColor(.loopedPrimary)
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if result.id != viewModel.specializationSearchResults.prefix(6).last?.id {
                            Divider()
                        }
                    }
                }
            } else if !specializationSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = specializationSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(trimmed.count < 2 ? "Type at least 2 characters." : "No majors or fields found.")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func specializationSearchPreview(for result: CommunitySearchResult) -> some View {
        Group {
            if let icon = result.icon?.normalizedOrNil() {
                switch icon.kind {
                case .emoji:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.loopedMutedBackground)
                        .overlay(
                            Text(icon.value)
                                .font(.loopedCustom(.semibold, size: 16))
                                .foregroundColor(.loopedTextPrimary)
                        )
                case .sfSymbol:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.loopedMutedBackground)
                        .overlay(
                            Image(systemName: icon.value)
                                .font(.loopedCustom(.semibold, size: 13))
                                .foregroundColor(.loopedTextPrimary)
                        )
                case .imageUrl:
                    if let url = URL.loopedMediaURL(from: icon.value) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .empty, .failure:
                                specializationSearchPreviewFallback(for: result)
                            @unknown default:
                                specializationSearchPreviewFallback(for: result)
                            }
                        }
                    } else {
                        specializationSearchPreviewFallback(for: result)
                    }
                case .unknown:
                    specializationSearchPreviewFallback(for: result)
                }
            } else {
                specializationSearchPreviewFallback(for: result)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func specializationSearchPreviewFallback(for result: CommunitySearchResult) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.loopedMutedBackground)
            .overlay(
                Text(result.specializationType == .major ? "M" : "F")
                    .font(.loopedSmallText)
                    .foregroundColor(.loopedTextSecondary)
            )
    }

    @ViewBuilder
    private func verificationSearchPreview(for result: CommunitySearchResult) -> some View {
        let trimmed = (result.imageUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteURL = URL.loopedMediaURL(from: trimmed)

        Group {
            if let remoteURL {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        verificationSearchPreviewFallback(for: result)
                    @unknown default:
                        verificationSearchPreviewFallback(for: result)
                    }
                }
            } else {
                verificationSearchPreviewFallback(for: result)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func verificationSearchPreviewFallback(for result: CommunitySearchResult) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.loopedMutedBackground)
            .overlay(
                Image(systemName: result.kind == .school ? "graduationcap.fill" : "building.2.fill")
                    .font(.loopedCustom(size: 13))
                    .foregroundColor(.loopedTextSecondary)
            )
    }

    private func joinLimitRemainingText(_ limit: SpecializationJoinLimit) -> String {
        let remaining = max(limit.remaining, 0)
        let joinsText = remaining == 1 ? "1 join left" : "\(remaining) joins left"
        if let cooldownEndsAt = limit.cooldownEndsAt {
            return "\(joinsText) | resets at \(Self.expiryFormatter.string(from: cooldownEndsAt))"
        }
        return joinsText
    }

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private func scheduleSpecializationSearch(immediate: Bool = false) {
        specializationSearchTask?.cancel()
        let query = specializationSearchText
        specializationSearchTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            guard !Task.isCancelled else { return }
            await viewModel.searchSpecializations(query: query)
        }
    }

    private func scheduleVerificationSearch(immediate: Bool = false) {
        verificationSearchTask?.cancel()
        let query = verificationSearchText
        verificationSearchTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 450_000_000)
            }
            guard !Task.isCancelled else { return }
            await viewModel.searchVerificationCommunities(query: query)
        }
    }
}

#Preview {
    CommunityVerificationsView()
        .environmentObject(AuthViewModel())
}
