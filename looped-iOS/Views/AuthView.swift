import SwiftUI

struct AuthView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var isLogin = true
    
    var body: some View {
        VStack {
            Picker("Auth Type", selection: $isLogin) {
                Text("Login").tag(true)
                Text("Sign Up").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if isLogin {
                LoginView(viewModel: authViewModel)
            } else {
                SignUpView(viewModel: authViewModel)
            }
        }
    }
}

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to Looped")
                .font(.largeTitle)
                .bold()
                .padding(.bottom, 32)
            
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Button("Login") {
                Task {
                    await viewModel.login(email: email, password: password)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || viewModel.isLoading)
            
            if viewModel.isLoading {
                ProgressView()
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
}

struct SignUpView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var company = ""
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Join Your Company")
                .font(.largeTitle)
                .bold()
                .padding(.bottom, 32)
            
            VStack(spacing: 12) {
                TextField("Work Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                TextField("Username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                TextField("Company", text: $company)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Button("Sign Up") {
                Task {
                    await viewModel.signUp(
                        email: email,
                        password: password,
                        username: username,
                        company: company
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || username.isEmpty || company.isEmpty || viewModel.isLoading)
            
            if viewModel.isLoading {
                ProgressView()
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
}

#Preview {
    AuthView(authViewModel: AuthViewModel())
}