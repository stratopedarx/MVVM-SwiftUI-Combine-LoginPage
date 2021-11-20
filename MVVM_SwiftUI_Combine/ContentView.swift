//
//  ContentView.swift
//  MVVM_SwiftUI_Combine
//
//  Created by Sergey Lobanov on 20.11.2021.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        Text("Welcome!")
    }
}

struct ContentView: View {
    
    @ObservedObject private var userViewModel = UserViewModel()
    @State private var presentAlert = false
    
    var body: some View {
        Form {
            Section(footer: Text(userViewModel.usernameMessage)) {
                TextField("Username", text: $userViewModel.username)
                    .textInputAutocapitalization(.none)
            }
            
            Section(footer: Text(userViewModel.passwordMessage)) {
                SecureField("Password", text: $userViewModel.password)
                SecureField("Password again", text: $userViewModel.passwordAgain)
            }
            
            Section() {
                Button {
                    signUp()
                } label: {
                    Text("Sign up")
                }
                .disabled(!userViewModel.isValid)

            }
        }
        .sheet(isPresented: $presentAlert) {
            WelcomeView()
        }
    }
    
    private func signUp() {
        presentAlert = true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
