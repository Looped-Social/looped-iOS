import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile") {
                    HStack {
                        Text("Username")
                        Spacer()
                        Text(viewModel.user?.username ?? "")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Company")
                        Spacer()
                        HStack {
                            Text(viewModel.user?.company ?? "")
                            if viewModel.user?.isVerified == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Display Name")
                        Spacer()
                        Text(viewModel.user?.displayName ?? "Not set")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Privacy") {
                    Toggle("Anonymous Mode", isOn: .constant(viewModel.user?.isAnonymous ?? false))
                        .onChange(of: viewModel.user?.isAnonymous ?? false) { _ in
                            // Handle anonymous mode toggle
                        }
                }
                
                Section("Account") {
                    Button("Sign Out", role: .destructive) {
                        viewModel.signOut()
                    }
                }
            }
            .navigationTitle("Profile")
            .task {
                await viewModel.loadUserProfile()
            }
        }
    }
}

#Preview {
    ProfileView()
}