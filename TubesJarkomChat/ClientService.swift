import SwiftUI
import Combine
import Network
import UniformTypeIdentifiers

let OpenFileViaHost = ""

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: String
    let text: String
    let fileURL: URL?
    let isOutgoing: Bool
}

@MainActor
final class ClientService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isConnected = false
    @Published var username = ""
    @Published var serverName = ""
    @Published var host = ""
    @Published var port = ""
    @Published private(set) var isOwner = false
    @Published private(set) var isConnecting = false
    @Published private(set) var connectionMessage = ""
    @Published private(set) var hasConnectionError = false
    @Published private(set) var toastMessage = ""

    private var connection: NWConnection?
    private var reconnectTask: Task<Void, Never>?
    private var isReconnecting = false
    private var shouldReconnect = false

    func connect(host: String, port: String, username: String) {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = port.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !host.isEmpty, !username.isEmpty,
              let rawPort = UInt16(port),
              NWEndpoint.Port(rawValue: rawPort) != nil else {
            showConnectionError("Isi host, port, dan username dengan benar.")
            return
        }

        messages.removeAll()
        self.host = host
        self.port = port
        self.username = username
        isConnected = false
        shouldReconnect = true
        startConnection(isReconnect: false)
    }

    private func startConnection(isReconnect: Bool) {
        guard let rawPort = UInt16(port),
              let nwPort = NWEndpoint.Port(rawValue: rawPort) else { return }

        reconnectTask?.cancel()
        connection?.cancel()
        isReconnecting = isReconnect
        isConnecting = true
        hasConnectionError = false

        if isReconnect {
            showToast("Koneksi terputus. Menghubungkan ulang...")
        } else {
            connectionMessage = "Menghubungkan ke server..."
        }

        let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, self.connection === conn else { return }

                switch state {
                case .ready:
                    if !self.isReconnecting {
                        self.connectionMessage = "Server terhubung. Memproses login..."
                    }
                    self.sendPacket([
                        "type": "login",
                        "username": self.username
                    ])
                    self.receivePacket()
                case .waiting(let error):
                    if self.isConnected {
                        self.showToast("Koneksi terganggu: \(error.localizedDescription)")
                    } else {
                        self.connectionMessage = "Menunggu server: \(error.localizedDescription)"
                    }
                case .failed(let error):
                    if self.isConnected && self.shouldReconnect {
                        self.scheduleReconnect()
                    } else {
                        self.showConnectionError("Gagal terhubung: \(error.localizedDescription)")
                        self.connection = nil
                    }
                case .cancelled:
                    if !self.isReconnecting {
                        self.isConnecting = false
                    }
                default:
                    break
                }
            }
        }

        conn.start(queue: .global())
    }

    private func scheduleReconnect() {
        connection?.cancel()
        connection = nil
        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, shouldReconnect, isConnected else { return }
            startConnection(isReconnect: true)
        }
    }

    var requiresTarget: Bool {
        serverName != "broadcast"
    }

    func sendText(_ text: String, to target: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let target = resolvedTarget(target) else { return }

        sendPacket([
            "type": "text",
            "from": username,
            "to": target,
            "message": text
        ])

        messages.append(ChatMessage(sender: "saya", text: text, fileURL: nil, isOutgoing: true))
    }

    func sendFile(_ url: URL, to target: String) {
        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url),
              let target = resolvedTarget(target) else { return }

        sendPacket([
            "type": "file",
            "from": username,
            "to": target,
            "filename": url.lastPathComponent
        ], data: data)

        messages.append(ChatMessage(sender: "saya", text: "mengirim file: \(url.lastPathComponent)", fileURL: url, isOutgoing: true))
    }

    func exit() {
        disconnect()
    }

    func closeServer() {
        guard isOwner else { return }

        sendPacket([
            "type": "close",
            "from": username
        ]) { [weak self] in
            self?.disconnect()
        }
    }

    private func disconnect() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        connection?.cancel()
        connection = nil
        isConnected = false
        isConnecting = false
        isReconnecting = false
        isOwner = false
        connectionMessage = ""
        hasConnectionError = false
        messages.removeAll()
    }

    private func showToast(_ message: String) {
        toastMessage = message

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if toastMessage == message {
                toastMessage = ""
            }
        }
    }

    private func resolvedTarget(_ target: String) -> String? {
        if serverName == "broadcast" {
            return "all"
        }

        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        return target.isEmpty ? nil : target
    }

    private func showConnectionError(_ message: String) {
        isConnected = false
        isConnecting = false
        hasConnectionError = true
        connectionMessage = message
    }

    private func sendPacket(_ header: [String: Any], data: Data = Data(), completion: (() -> Void)? = nil) {
        var header = header
        header["size"] = data.count

        guard let headerData = try? JSONSerialization.data(withJSONObject: header) else {
            completion?()
            return
        }

        var length = UInt32(headerData.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)

        guard let connection else {
            completion?()
            return
        }

        connection.send(content: lengthData + headerData + data, completion: .contentProcessed { _ in
            Task { @MainActor in
                completion?()
            }
        })
    }

    private func receivePacket() {
        guard let connection else { return }

        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { lengthData, _, _, _ in
            guard let lengthData, lengthData.count == 4 else {
                Task { @MainActor in
                    self.handleConnectionLoss(for: connection)
                }
                return
            }

            let headerLength = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            connection.receive(minimumIncompleteLength: Int(headerLength), maximumLength: Int(headerLength)) { headerData, _, _, _ in
                guard let headerData,
                      let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any] else {
                    Task { @MainActor in
                        self.handleConnectionLoss(for: connection)
                    }
                    return
                }

                let size = header["size"] as? Int ?? 0

                guard size > 0 else {
                    Task { @MainActor in
                        self.handlePacket(header, data: Data())
                        self.receivePacket()
                    }
                    return
                }

                connection.receive(minimumIncompleteLength: size, maximumLength: size) { body, _, _, _ in
                    Task { @MainActor in
                        guard let body else {
                            self.handleConnectionLoss(for: connection)
                            return
                        }

                        self.handlePacket(header, data: body)
                        self.receivePacket()
                    }
                }
            }
        }
    }

    private func handleConnectionLoss(for connection: NWConnection) {
        guard self.connection === connection else { return }

        if isConnected && shouldReconnect {
            scheduleReconnect()
        } else if isConnecting {
            showConnectionError("Koneksi ke server terputus sebelum login selesai.")
            self.connection = nil
        }
    }

    private func handlePacket(_ header: [String: Any], data: Data) {
        let type = header["type"] as? String ?? ""
        let sender = header["from"] as? String ?? "server"

        if type == "login_ok" {
            serverName = header["server"] as? String ?? ""
            isOwner = header["is_owner"] as? Bool ?? false
            isConnecting = false
            hasConnectionError = false
            connectionMessage = ""
            isConnected = true

            if isReconnecting {
                isReconnecting = false
                showToast("Terhubung kembali ke server.")
            }
        } else if type == "login_error" || type == "error" {
            if isReconnecting && shouldReconnect {
                scheduleReconnect()
            } else {
                showConnectionError(header["message"] as? String ?? "Login ditolak oleh server.")
                connection?.cancel()
                connection = nil
            }
        } else if type == "text" {
            messages.append(ChatMessage(sender: sender, text: header["message"] as? String ?? "", fileURL: nil, isOutgoing: false))
        } else if type == "file" {
            let filename = header["saved_filename"] as? String ?? header["filename"] as? String ?? "file.bin"
            let fileURL = saveFile(filename: filename, data: data)
            messages.append(ChatMessage(sender: sender, text: "mengirim file: \(filename)", fileURL: fileURL, isOutgoing: false))
        } else if type == "system" {
            showToast(header["message"] as? String ?? "Pesan dari server")
        } else if type == "server_down" {
            shouldReconnect = false
            reconnectTask?.cancel()
            showToast(header["message"] as? String ?? "Server dimatikan")
            connection?.cancel()
            connection = nil

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                self.disconnect()
            }
        }
    }

    private func saveFile(filename: String, data: Data) -> URL? {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }
}
