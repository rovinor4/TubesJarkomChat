import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @EnvironmentObject var client: ClientService
    @State private var input = ""
    @State private var targetUsername = ""
    @State private var pendingFileTarget = ""
    @State private var showFilePicker = false
    @State private var showSendTargetPrompt = false
    @State private var showFileTargetPrompt = false
    @State private var showExitOptions = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showExitOptions = true
                } label: {
                    Image(systemName: "chevron.backward")
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass(.regular.tint(.red)))
                .accessibilityLabel("Keluar")

                Spacer()

                Text(client.username)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(client.host):\(client.port)")
                    .font(.caption)
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 22))

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(client.messages) { message in
                        HStack {
                            if message.isOutgoing {
                                Spacer(minLength: 48)
                            }

                            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                                Text(message.sender)
                                    .font(.caption)
                                    .foregroundStyle(message.isOutgoing ? .white.opacity(0.8) : .secondary)

                                if let fileURL = message.fileURL {
                                    Button(message.text) {
                                        openFile(fileURL)
                                    }
                                    .foregroundStyle(message.isOutgoing ? .white : .primary)
                                } else {
                                    Text(message.text)
                                        .foregroundStyle(message.isOutgoing ? .white : .primary)
                                }
                            }
                            .padding(12)
                            .background(message.isOutgoing ? Color.blue : Color.clear)
                            .clipShape(.rect(cornerRadius: 16))
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))

                            if !message.isOutgoing {
                                Spacer(minLength: 48)
                            }
                        }
                    }
                }
                .padding()
            }

            HStack(spacing: 12) {
                Button {
                    requestFilePicker()
                } label: {
                    Image(systemName: "paperclip")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Pilih file")

                TextField("Chat...", text: $input)
                    .textFieldStyle(.roundedBorder)

                Button {
                    requestSend()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass(.regular.tint(.blue)))
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Kirim pesan")
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
        }
        .padding()
        .overlay(alignment: .top) {
            if !client.toastMessage.isEmpty {
                Text(client.toastMessage)
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .padding(.top, 12)
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.data]) { result in
            if case .success(let url) = result {
                client.sendFile(url, to: pendingFileTarget)
            }
        }
        .confirmationDialog("Keluar dari chat?", isPresented: $showExitOptions, titleVisibility: .visible) {
            Button("Keluar") {
                client.exit()
            }

            if client.isOwner {
                Button("Keluar dan Tutup Server", role: .destructive) {
                    client.closeServer()
                }
            }

            Button("Batal", role: .cancel) {}
        }
        .alert(targetPromptTitle, isPresented: $showSendTargetPrompt) {
            TextField(targetPromptPlaceholder, text: $targetUsername)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Batal", role: .cancel) {}
            Button("Send") {
                sendMessage(to: targetUsername)
            }
            .disabled(targetUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert(targetPromptTitle, isPresented: $showFileTargetPrompt) {
            TextField(targetPromptPlaceholder, text: $targetUsername)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Batal", role: .cancel) {}
            Button("Pilih File") {
                pendingFileTarget = targetUsername
                showFilePicker = true
            }
            .disabled(targetUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var targetPromptTitle: String {
        client.serverName == "multicast" ? "Masukkan username tujuan" : "Masukkan username tujuan"
    }

    private var targetPromptPlaceholder: String {
        client.serverName == "multicast" ? "Pisahkan username dengan koma" : "Username tujuan"
    }

    private func requestSend() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if client.requiresTarget {
            targetUsername = ""
            showSendTargetPrompt = true
        } else {
            sendMessage(to: "")
        }
    }

    private func sendMessage(to target: String) {
        client.sendText(input, to: target)
        input = ""
    }

    private func requestFilePicker() {
        if client.requiresTarget {
            targetUsername = ""
            showFileTargetPrompt = true
        } else {
            pendingFileTarget = ""
            showFilePicker = true
        }
    }

    private func openFile(_ url: URL) {
        if !OpenFileViaHost.isEmpty {
            let remote = URL(string: OpenFileViaHost + "/" + url.lastPathComponent)
            if let remote {
                UIApplication.shared.open(remote)
            }
        } else {
            UIApplication.shared.open(url)
        }
    }
}

