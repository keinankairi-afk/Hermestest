# Hermes AI Agent Installer

Installer otomatis untuk setup NousResearch Hermes Agent di VPS Ubuntu 22.04/24.04.

## Fitur

- Install dependency otomatis
- Install Node.js LTS + PM2
- Clone Hermes Agent dari NousResearch
- Setup Telegram Bot Token dan Chat ID
- Support banyak provider LLM:
  - Groq
  - OpenAI
  - Gemini
  - OpenRouter
  - NVIDIA
  - Kiro via 9Router
  - Custom OpenAI-compatible
- Auto-generate `.env`
- Jalankan Hermes via PM2
- Auto-start saat VPS reboot
- Bisa reinstall / backup folder lama

## Cara Install

Upload folder ini ke VPS, lalu jalankan:

```bash
chmod +x install.sh
./install.sh
```

Atau:

```bash
bash install.sh
```

## Data yang perlu disiapkan

1. Telegram Bot Token dari `@BotFather`
2. Telegram Chat ID dari `@userinfobot` atau `@RawDataBot`
3. API Key provider LLM:
   - Groq / OpenAI / Gemini / OpenRouter / NVIDIA
   - Untuk Kiro via 9Router, API key di Hermes boleh dummy `test`

## Command penting

```bash
pm2 status
pm2 logs hermes-agent
pm2 restart hermes-agent
pm2 stop hermes-agent
nano /opt/hermes-agent/.env
```

## 9Router untuk Kiro

Jika memilih provider `Kiro via 9Router`, installer bisa memasang 9Router di VPS.

Dashboard 9Router default hanya lokal:

```text
http://127.0.0.1:20128
```

Akses dari HP/PC dengan SSH tunnel:

```bash
ssh -L 20128:127.0.0.1:20128 user@IP_VPS
```

Lalu buka:

```text
http://127.0.0.1:20128
```

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Struktur

```text
hermes-installer/
├── install.sh
├── uninstall.sh
├── .env.example
└── README.md
```

## Catatan

- Jangan share API key ke orang lain.
- Repo Hermes utama dapat berubah. Jika script gagal karena struktur repo berubah, cek dokumentasi terbaru dari NousResearch.
- Untuk produksi/jualan, lebih stabil pakai VPS daripada Codespaces.
