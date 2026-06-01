import SwiftUI

@main
struct ChatClientApp: App {
    @StateObject private var client = ClientService()

    var body: some Scene {
        WindowGroup {
            if client.isConnected {
                ChatView()
                    .environmentObject(client)
            } else {
                WelcomeView()
                    .environmentObject(client)
            }
        }
    }
}
