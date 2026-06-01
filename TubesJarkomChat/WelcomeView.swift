import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var client: ClientService
    @State private var host = ""
    @State private var port = ""
    @State private var username = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Connect Chat")
                .font(.largeTitle.bold())

            Text("Tubes Jarkom - Rovino Ramadhani")
                .font(.default)

            TextField("Host", text: $host)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .controlSize(.large)

            TextField("Port", text: $port)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .controlSize(.large)

            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .controlSize(.large)

            Button(client.isConnecting ? "Connecting..." : "Connect") {
                client.connect(host: host, port: port, username: username)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(client.isConnecting || host.isEmpty || port.isEmpty || username.isEmpty)

            if !client.connectionMessage.isEmpty {
                Text(client.connectionMessage)
                    .font(.caption)
                    .foregroundStyle(client.hasConnectionError ? .red : .secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: 520)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(24)
    }
}

#Preview("Welcome") {
    WelcomeView()
        .environmentObject(ClientService())
}
