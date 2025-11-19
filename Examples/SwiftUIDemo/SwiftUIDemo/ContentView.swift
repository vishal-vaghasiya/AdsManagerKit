//
//  ContentView.swift
//  SwiftUIDemo
//
//  Created by Nexios Technologies on 18/11/25.
//

import SwiftUI

struct ContentView: View {
    @State private var updateMessage: String = ""
    @State private var showUpdateAlert: Bool = false
    @State private var latestVersion: String = ""
    var appID = "YOUR_APP_ID"
    var body: some View {
        VStack(spacing: 20) {
            Button("Check for Update") {
                VersionChecker.checkForUpdate(appID: appID) { result in
                    switch result {
                    case .updateAvailable(let version):
                        updateMessage = "Update available: \(version)"
                        latestVersion = version
                        showUpdateAlert = true
                    case .upToDate:
                        updateMessage = "Your app is up to date."
                    case .error(let err):
                        updateMessage = "Error: \(err.localizedDescription)"
                    }
                }
            }
            
            Text(updateMessage)
                .padding()
        }
        .padding()
        .alert("Update Available", isPresented: $showUpdateAlert) {
            Button("Update Now") {
                if let url = URL(string: "https://apps.apple.com/app/id\(appID)") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("A new version (\(latestVersion)) is available on the App Store.")
        }
    }
}

#Preview {
    ContentView()
}
