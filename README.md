# Hermes Agent — One-line Installer (Multi-LLM)

One-shot installer for the official **[Hermes Agent](https://hermes-agent.nousresearch.com/)** by Nous Research. Pilih provider LLM yang kamu mau saat install: Groq, OpenAI, Anthropic, OpenRouter, DeepSeek, Together AI, atau endpoint custom yang OpenAI-compatible.

Installer satu-baris untuk Hermes Agent resmi dari Nous Research, sekarang dengan **menu pilih LLM** saat install — bukan cuma Groq lagi.

---

## 🚀 What you get / Yang akan kamu dapat

**EN**
- Official Hermes Agent CLI installed (autonomous AI agent — same category as Claude Code, Codex)
- **Pick your LLM provider at install time** — Groq (default), OpenAI, Anthropic, OpenRouter, DeepSeek, Together AI, or any custom OpenAI-compatible endpoint
- Sensible model default per provider (e.g. `llama-3.3-70b-versatile` for Groq, `gpt-4o-mini` for OpenAI, `claude-3-5-sonnet-latest` for Anthropic)
- 1-token verification ping before any config is written, so you fail fast on bad keys / wrong model names
- Optional Telegram bot token + chat ID stored for later use

**ID**
- CLI Hermes Agent resmi terinstal (AI agent autonomous — kelas yang sama dengan Claude Code, Codex)
- **Pilih provider LLM saat install** — Groq (default), OpenAI, Anthropic, OpenRouter, DeepSeek, Together AI, atau custom endpoint OpenAI-compatible
- Model default per provider sudah disetelin (mis. `llama-3.3-70b-versatile` untuk Groq, `gpt-4o-mini` untuk OpenAI, `claude-3-5-sonnet-latest` untuk Anthropic)
- Tes ping 1-token sebelum config ditulis, jadi langsung ketahuan kalau key salah atau model gak ada
- Opsional simpan token bot Telegram + chat ID untuk dipakai kemudian

---

## 🤖 Supported providers

| # | Provider | Base URL | Env var | Default model |
|---|---|---|---|---|
| 1 | **Groq** (default) | `https://api.groq.com/openai/v1` | `GROQ_API_KEY` | `llama-3.3-70b-versatile` |
| 2 | OpenAI | `https://api.openai.com/v1` | `OPENAI_API_KEY` | `gpt-4o-mini` |
| 3 | Anthropic | `https://api.anthropic.com/v1` | `ANTHROPIC_API_KEY` | `claude-3-5-sonnet-latest` |
| 4 | OpenRouter | `https://openrouter.ai/api/v1` | `OPENROUTER_API_KEY` | `meta-llama/llama-3.3-70b-instruct` |
| 5 | DeepSeek | `https://api.deepseek.com/v1` | `DEEPSEEK_API_KEY` | `deepseek-chat` |
| 6 | Together AI | `https://api.together.xyz/v1` | `TOGETHER_API_KEY` | `meta-llama/Llama-3.3-70B-Instruct-Turbo` |
| 7 | Custom (OpenAI-compatible) | _kamu isi sendiri_ | _kamu isi sendiri_ (default `LLM_API_KEY`) | _kamu isi sendiri_ |

> Semua provider didaftarkan sebagai `openai_compatible` kecuali Anthropic (didaftarkan sebagai `anthropic`, karena Claude pakai endpoint `/messages` dengan header `x-api-key`).

> Punya proxy / router / gateway sendiri (mis. LiteLLM, LocalAI, Ollama dengan OpenAI shim, atau OpenRouter dengan custom routing)? Pilih opsi **7 — Custom**, lalu isi base URL, nama env var, dan model default sesuai punya kamu.

---

## ⚡ Quick Install

### Step 1 — Siapkan kebutuhan

1. **API key untuk salah satu provider di atas** — minimal satu. Daftar di:
   - Groq: [console.groq.com/keys](https://console.groq.com/keys) (key diawali `gsk_...`)
   - OpenAI: [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
   - Anthropic: [console.anthropic.com](https://console.anthropic.com/)
   - OpenRouter: [openrouter.ai/keys](https://openrouter.ai/keys)
   - DeepSeek: [platform.deepseek.com](https://platform.deepseek.com/)
   - Together: [api.together.xyz/settings/api-keys](https://api.together.xyz/settings/api-keys)
2. **(Optional) Telegram bot token + chat ID** — kalau mau pakai gateway Telegram:
   - Bot token: chat [@BotFather](https://t.me/BotFather) di Telegram → `/newbot`
   - Chat ID: chat [@userinfobot](https://t.me/userinfobot) di Telegram

### Step 2 — Jalankan satu perintah ini di server kamu

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/keinankairi-afk/Hermestest/main/install.sh)
```

Installer akan menanyakan:

```
Pilih LLM provider / Choose LLM provider:
  1) Groq           — OpenAI-compatible, default
  2) OpenAI         — api.openai.com/v1
  3) Anthropic      — Claude (api.anthropic.com)
  4) OpenRouter     — openrouter.ai (many models, one key)
  5) DeepSeek       — api.deepseek.com
  6) Together AI    — api.together.xyz
  7) Custom         — any other OpenAI-compatible endpoint

? Provider [1-7] [default: 1]:                           <Enter untuk Groq>
? <PROVIDER> API KEY:                                    <paste key kamu>
? <PROVIDER> MODEL [default: <default model>]:           <Enter untuk default>
? TELEGRAM BOT TOKEN (optional, press Enter to skip):    <paste atau skip>
? TELEGRAM CHAT ID:                                      <hanya kalau bot token diisi>
```

Selesai. Ketik `hermes "halo"` setelah install selesai untuk tes.

> 💡 Jangan jalankan dengan `sudo` — Hermes Agent diinstal **per-user** ke `~/.hermes/`. Kalau kamu jalankan sebagai root, Hermes akan masuk ke `/root/.hermes/`.

> 🔁 Mau ganti provider nanti? Cukup jalankan installer-nya lagi dan pilih nomor yang lain. Installer akan bersihin sisa key provider lama dari `~/.hermes/.env` secara otomatis sebelum nulis yang baru.

---

## 🖥️ Compatibility

| OS | Status |
|---|---|
| Ubuntu 22.04 / 24.04 | ✅ Tested target |
| Debian 12 | ✅ Should work |
| Linux Mint / Pop!_OS | ✅ apt-based |
| Fedora / Rocky / Alma | ⚠️ Best-effort (uses `dnf`) |
| Arch / Manjaro | ⚠️ Best-effort (uses `pacman`) |
| macOS | ❌ Use the upstream installer directly: see [docs](https://hermes-agent.nousresearch.com/docs/getting-started/installation) |

---

## 🔍 What the installer does

1. **OS prerequisites** — `curl`, `git`, `python3` (>=3.11), `python3-venv`, `build-essential`, `jq`
2. **Run the official Nous installer** — clones `NousResearch/hermes-agent`, sets up a virtualenv, adds `hermes` to your PATH
3. **Pilih provider + prompt for credentials** — menu 1..7 (default Groq), API key (required), model (default per provider), Telegram (optional)
4. **Verify the chosen provider** — sends a 1-token ping. For OpenAI-compatible providers it hits `${BASE_URL}/chat/completions` with `Authorization: Bearer <key>`. For Anthropic it hits `${BASE_URL}/messages` with `x-api-key` + `anthropic-version: 2023-06-01`. If 401/403/404, the installer aborts with a clear message before writing any config.
5. **Write config** — `~/.hermes/.env` (secrets, mode 600) + `~/.hermes/config.yaml` (chosen provider registered as `openai_compatible` or `anthropic`). Stale provider keys from prior runs are stripped from `.env` before the new one is written.
6. **Print summary** — paths, provider, model, env var name, next-step commands

The script is idempotent: re-running it preserves any existing Hermes config, swaps the active provider cleanly, and only updates the relevant section.

---

## 📁 Files written

```
~/.hermes/
├── .env                # <PROVIDER>_API_KEY (+ Telegram secrets if provided), mode 600
└── config.yaml         # Provider definition, default model
```

To inspect:

```bash
cat ~/.hermes/config.yaml
hermes config show         # if your version supports it
```

To rotate the API key later, just edit `~/.hermes/.env`:

```bash
nano ~/.hermes/.env
```

No restart needed — Hermes reads it on every invocation.

---

## 🤖 Default models per provider

| Provider | Default model | When to use |
|---|---|---|
| Groq | `llama-3.3-70b-versatile` | Cepat + murah, kualitas Llama 3.3 70B |
| OpenAI | `gpt-4o-mini` | Cheap reliable workhorse, swap to `gpt-4o` for harder tasks |
| Anthropic | `claude-3-5-sonnet-latest` | Best general reasoning di tier ini, swap ke `claude-3-5-haiku-latest` untuk lebih cepat/murah |
| OpenRouter | `meta-llama/llama-3.3-70b-instruct` | Satu key, banyak model — gampang switch model di config |
| DeepSeek | `deepseek-chat` | Murah banget; pakai `deepseek-reasoner` untuk reasoning chain |
| Together AI | `meta-llama/Llama-3.3-70B-Instruct-Turbo` | Llama 3.3 70B di infra Together |

Daftar model lain disetelin otomatis di `~/.hermes/config.yaml` (field `providers.<id>.models`) — tinggal edit `model:` untuk ganti default.

Latest model lists:

- Groq: [console.groq.com/dashboard/models](https://console.groq.com/dashboard/models)
- OpenAI: [platform.openai.com/docs/models](https://platform.openai.com/docs/models)
- Anthropic: [docs.anthropic.com/en/docs/about-claude/models](https://docs.anthropic.com/en/docs/about-claude/models)
- OpenRouter: [openrouter.ai/models](https://openrouter.ai/models)
- DeepSeek: [api-docs.deepseek.com/quick_start/pricing](https://api-docs.deepseek.com/quick_start/pricing)
- Together: [docs.together.ai/docs/inference-models](https://docs.together.ai/docs/inference-models)

---

## 🛠 Troubleshooting

| Problem | Fix |
|---|---|
| `hermes: command not found` after install | Open a **new shell**, or run `source ~/.bashrc`. The installer added `~/.local/bin` to your PATH but the current shell hasn't reloaded yet. |
| `HTTP 401` / `HTTP 403` from provider during verify | Your API key is wrong, revoked, or doesn't have access to that model. Generate a fresh key in the provider's console and re-run installer. |
| `HTTP 404 model_not_found` | Model name typo for the chosen provider. Cek tabel "Default models per provider" di atas, atau buka link "Latest model lists". |
| Mau ganti provider | Re-run installer, pilih nomor lain. Installer akan ganti key di `~/.hermes/.env` dan `provider:` field di `~/.hermes/config.yaml` secara otomatis. |
| Want to reset everything | `rm -rf ~/.hermes/` then re-run the installer. ⚠️ Removes all skills, learning, history. |
| Mau pakai dua provider sekaligus (mis. Groq buat draf, Claude buat finalize) | Re-run installer untuk daftarin masing-masing, lalu edit `~/.hermes/config.yaml` manual untuk pilih `provider:` mana yang aktif. Block `providers.*` dua-duanya tetap kesimpan. |

---

## 📚 Links

- 🏠 Hermes Agent home: https://hermes-agent.nousresearch.com/
- 📖 Official docs: https://hermes-agent.nousresearch.com/docs/
- 💻 Source: https://github.com/NousResearch/hermes-agent
- 🧠 Skills hub: https://hermes-agent.nousresearch.com/docs/skills
- 🔧 Adding providers (manual): https://hermes-agent.nousresearch.com/docs/developer-guide/adding-providers

---

## ⚖️ License

This installer script: MIT.

Hermes Agent itself is licensed by Nous Research — see their [repository](https://github.com/NousResearch/hermes-agent) for terms.
