# Tubes Jarkom Chat

Aplikasi chat client iOS berbasis SwiftUI untuk tugas Jaringan Komputer. Aplikasi terhubung ke server menggunakan TCP melalui framework `Network` dan mendukung pertukaran pesan serta file.

## Identitas

| Keterangan | Data |
| --- | --- |
| Nama | Rovino Ramadhani |
| NIM | 103072400031 |
| Kelas | IF 04-01 |
| Mata Kuliah | Jaringan Komputer - Telkom University Surabaya |

## Fitur

- Login menggunakan host, port, dan username.
- Dukungan server broadcast, unicast, dan multicast.
- Pengiriman pesan teks dan file.
- Pemilihan username tujuan untuk unicast dan multicast.
- Tampilan bubble chat untuk pesan masuk dan keluar.
- Toast untuk notifikasi dari server.
- Reconnect otomatis saat koneksi terputus sementara.
- Opsi keluar biasa dan menutup server untuk owner percakapan.

## Teknologi

- SwiftUI
- Network framework (`NWConnection`)
- Uniform Type Identifiers
- Liquid Glass UI

## Menjalankan Aplikasi

1. Buka project `TubesJarkomChat` menggunakan Xcode.
2. Jalankan server chat yang kompatibel.
3. Build dan jalankan aplikasi pada simulator atau perangkat iOS.
4. Isi host, port, dan username pada halaman awal.
5. Tekan tombol `Connect`.

## Struktur Utama

- `ChatClientApp.swift`: entry point aplikasi.
- `WelcomeView.swift`: halaman koneksi dan login.
- `ChatView.swift`: tampilan percakapan dan pengiriman file.
- `ClientService.swift`: koneksi TCP, protokol paket, dan state aplikasi.
