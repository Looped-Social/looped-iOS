import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct TwoFactorSettingsView: View {
    @StateObject private var viewModel = TwoFactorSettingsViewModel()
    @State private var showEnrollSheet = false
    @State private var showRemovalConfirm = false
    @State private var showReauthSheet = false
    @State private var reauthPassword = ""
    @State private var reauthError: String?
    @State private var showReauthHint = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusCard

                if viewModel.phoneFactors.isEmpty {
                    emptyState
                } else {
                    factorsList
                }

                Button(action: { showEnrollSheet = true }) {
                    Text("Add Phone")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.loopedPrimary)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color.loopedBackground.ignoresSafeArea())
        .navigationTitle("Two-Factor Authentication")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadFactors()
        }
        .onChange(of: viewModel.requiresReauth) { _, newValue in
            if newValue {
                showReauthSheet = viewModel.canReauthWithPassword
                showReauthHint = !viewModel.canReauthWithPassword
            }
        }
        .sheet(isPresented: $showEnrollSheet) {
            TwoFactorEnrollmentView {
                showEnrollSheet = false
                Task { await viewModel.loadFactors() }
            }
        }
        .alert("Remove this phone?", isPresented: $showRemovalConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task { await viewModel.removePendingFactor() }
            }
        } message: {
            Text("You can add it again later.")
        }
        .alert("Re-authentication required", isPresented: $showReauthHint) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please sign out and sign back in to manage two-factor authentication.")
        }
        .sheet(isPresented: $showReauthSheet) {
            PasswordReauthView(
                password: $reauthPassword,
                errorMessage: reauthError,
                onCancel: {
                    showReauthSheet = false
                    reauthPassword = ""
                },
                onConfirm: {
                    Task {
                        let success = await viewModel.reauthenticateWithPassword(reauthPassword)
                        if success {
                            reauthPassword = ""
                            showReauthSheet = false
                            await viewModel.removePendingFactor()
                        } else {
                            reauthError = viewModel.errorMessage
                        }
                    }
                }
            )
        }
    }
}

private extension TwoFactorSettingsView {
    var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextSecondary)

            Text(viewModel.isEnabled ? "Enabled" : "Off")
                .font(.loopedHeadingMedium)
                .foregroundColor(viewModel.isEnabled ? .loopedSecondary : .loopedTextPrimary)

            Text("Add a phone number for extra security when signing in.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(16)
        .background(Color.loopedWhite)
        .cornerRadius(16)
        .shadow(color: Color.loopedBlack.opacity(0.05), radius: 10, x: 0, y: 8)
    }

    var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No phones added")
                .font(.loopedBodyMedium)
                .foregroundColor(.loopedTextPrimary)
            Text("Add a phone number to enable two-factor authentication.")
                .font(.loopedSubBodyRegular)
                .foregroundColor(.loopedTextSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.loopedTextSecondary.opacity(0.05))
        .cornerRadius(12)
    }

    var factorsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.phoneFactors) { factor in
                HStack(spacing: 12) {
                    Image(systemName: "phone")
                        .font(.loopedCustom(.medium, size: 20))
                        .foregroundColor(.loopedSecondary)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(factor.displayName)
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextPrimary)

                        Text(masked(phone: factor.phoneNumber))
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedTextSecondary)
                    }

                    Spacer()

                    Button("Remove") {
                        viewModel.pendingRemoval = factor
                        showRemovalConfirm = true
                    }
                    .font(.loopedSmallTextMedium)
                    .foregroundColor(.loopedError)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if factor.id != viewModel.phoneFactors.last?.id {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .background(Color.loopedTextSecondary.opacity(0.05))
        .cornerRadius(12)
    }

    func masked(phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        guard digits.count >= 4 else { return phone }
        let suffix = digits.suffix(4)
        return "••• ••• \(suffix)"
    }
}

private struct TwoFactorEnrollmentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TwoFactorEnrollmentViewModel()
    let onComplete: () -> Void
    @State private var showCountryPicker = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.step == .phoneEntry {
                    Text("Enter your phone number")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    HStack(spacing: 10) {
                        Button(action: { showCountryPicker = true }) {
                            HStack(spacing: 6) {
                                Text(viewModel.selectedCountry.flagEmoji)
                                    .font(.loopedBody)
                                Text("+\(viewModel.selectedCountry.callingCode)")
                                    .font(.loopedBodyMedium)
                                    .foregroundColor(.loopedTextPrimary)
                                Image(systemName: "chevron.down")
                                    .font(.loopedCustom(.medium, size: 14))
                                    .foregroundColor(.loopedTextSecondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.loopedMutedBackground.opacity(0.6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        TextField(
                            PhoneNumberFormatter.placeholderNational(countryCallingCode: viewModel.selectedCountry.callingCode),
                            text: Binding(
                                get: {
                                    PhoneNumberFormatter.formattedNational(
                                        digits: viewModel.phoneDigits,
                                        countryCallingCode: viewModel.selectedCountry.callingCode
                                    )
                                },
                                set: {
                                    viewModel.phoneDigits = PhoneNumberFormatter.sanitizedDigits(
                                        from: $0,
                                        countryCallingCode: viewModel.selectedCountry.callingCode
                                    )
                                }
                            )
                        )
                        .font(.loopedBody)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(Color.loopedMutedBackground.opacity(0.6))
                        .cornerRadius(12)
                    }

                    Button(action: {
                        Task { await viewModel.sendCode() }
                    }) {
                        Text(viewModel.isLoading ? "Sending..." : "Send Code")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.loopedPrimary)
                            .clipShape(Capsule())
                    }
                    .disabled(viewModel.isLoading || !viewModel.isPhoneNumberComplete)
                } else {
                    Text("Enter the code we sent")
                        .font(.loopedBodyMedium)
                        .foregroundColor(.loopedTextPrimary)

                    TextField("Verification code", text: $viewModel.verificationCode)
                        .font(.loopedBody)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.loopedMutedBackground.opacity(0.6))
                        .cornerRadius(12)
                        .keyboardType(.numberPad)

                    Button(action: {
                        Task {
                            let success = await viewModel.enroll()
                            if success {
                                onComplete()
                            }
                        }
                    }) {
                        Text(viewModel.isLoading ? "Verifying..." : "Verify & Add")
                            .font(.loopedBodyMedium)
                            .foregroundColor(.loopedWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.loopedPrimary)
                            .clipShape(Capsule())
                    }
                    .disabled(viewModel.isLoading)

                    Button(action: {
                        Task { await viewModel.resendCode() }
                    }) {
                        Text("Resend code")
                            .font(.loopedSubBodyRegular)
                            .foregroundColor(.loopedSecondary)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.loopedSubBodyRegular)
                        .foregroundColor(.loopedError)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .navigationTitle("Add Phone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    LoopedCancelTextButton(action: { dismiss() })
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(Color.loopedBackground.ignoresSafeArea())
        .sheet(isPresented: $showCountryPicker) {
            CountryCallingCodePickerView(selected: $viewModel.selectedCountry)
        }
        .onChange(of: viewModel.selectedCountry) { _, newValue in
            viewModel.phoneDigits = PhoneNumberFormatter.sanitizedDigits(
                from: viewModel.phoneDigits,
                countryCallingCode: newValue.callingCode
            )
        }
    }
}

private struct CountryCallingCodePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: CountryCallingCode
    @State private var query = ""

    private var filtered: [CountryCallingCode] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return CountryCallingCode.supported }

        return CountryCallingCode.supported.filter { item in
            item.name.localizedCaseInsensitiveContains(trimmed)
            || item.isoCode.localizedCaseInsensitiveContains(trimmed)
            || item.callingCode.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { item in
                Button(action: {
                    selected = item
                    dismiss()
                }) {
                    HStack {
                        Text(item.displayLabel)
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)

                        Spacer()

                        if item == selected {
                            Image(systemName: "checkmark")
                                .font(.loopedCustom(.medium, size: 16))
                                .foregroundColor(.loopedSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Country Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic))
        }
    }
}

private struct PasswordReauthView: View {
    @Binding var password: String
    let errorMessage: String?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Confirm Password")
                .font(.loopedSubheadMedium)
                .foregroundColor(.loopedTextPrimary)

            SecureField("Password", text: $password)
                .font(.loopedBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.loopedMutedBackground.opacity(0.6))
                .cornerRadius(12)

            if let errorMessage {
                Text(errorMessage)
                    .font(.loopedSubBodyRegular)
                    .foregroundColor(.loopedError)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.loopedMutedBackground)
                    .clipShape(Capsule())

                Button("Continue", action: onConfirm)
                    .font(.loopedBodyMedium)
                    .foregroundColor(.loopedWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.loopedPrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .presentationDetents([.medium])
    }
}

#Preview {
    TwoFactorSettingsView()
}
