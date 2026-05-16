# Hermes Agent + Groq — One-line Installer

One-shot installer for the official **[Hermes Agent](https://hermes-agent.nousresearch.com/)** by Nous Research, pre-wired to use **Groq** as the LLM provider.

Installer satu-baris untuk Hermes Agent resmi dari Nous Research, sudah disetel pakai **Groq** sebagai provider AI.

---

## 🚀 What you get / Yang akan kamu dapat

**EN**
- Official Hermes Agent CLI installed (autonomous AI agent — same category as Claude Code, Codex)
- Pre-configured to talk to Groq (`https://api.groq.com/openai/v1`)
- Sensible model default: `llama-3.3-70b-versatile`
- Optional Telegram bot token + chat ID stored for later use

**ID**
- CLI Hermes Agent resmi terinstal (AI agent autonomous — kelas yang sama dengan Claude Code, Codex)
- Otomatis dikonfigurasi pakai Groq (`https://api.groq.com/openai/v1`)
- Model default yang masuk akal: `llama-3.3-70b-versatile`
- Opsional simpan token bot Telegram + chat ID untuk dipakai kemudian

---

## ⚡ Quick Install

### Step 1 — Siapkan 2 hal ini

1. **Groq API key** — daftar gratis di [console.groq.com/keys](https://console.groq.com/keys), key kamu akan diawali `gsk_...`
2. **(Optional) Telegram bot token + chat ID** — kalau mau pakai gateway Telegram:
   - Bot token: chat [@BotFather](https://t.me/BotFather) di Telegram → `/newbot`
   - Chat ID: chat [@userinfobot](https://t.me/userinfobot) di Telegram

### Step 2 — Jalankan satu perintah ini di server kamu

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/keinankairi-afk/Hermestest/main/install.sh)
```

Installer akan menanyakan:

```
? GROQ API KEY (gsk_...): <paste key Groq kamu>
? GROQ MODEL [default: llama-3.3-70b-versatile]: <Enter untuk default>
? TELEGRAM BOT TOKEN (optional, press Enter to skip): <paste atau skip>
? TELEGRAM CHAT ID:                                    <hanya kalau bot token diisi>
```

Selesai. Ketik `hermes "halo"` setelah install selesai untuk tes.

> 💡 Jangan jalankan dengan `sudo` — Hermes Agent diinstal **per-user** ke `~/.hermes/`. Kalau kamu jalankan sebagai root, Hermes akan masuk ke `/root/.hermes/`.

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
3. **Prompt for credentials** — Groq key (required), model (default), Telegram (optional)
4. **Verify Groq** — sends a 1-token ping to `api.groq.com/openai/v1/chat/completions`. If 401/404, the installer aborts with a clear message before writing any config.
5. **Write config** — `~/.hermes/.env` (secrets, mode 600) + `~/.hermes/config.yaml` (Groq registered as a custom OpenAI-compatible provider)
6. **Print summary** — paths, model, next-step commands

The script is idempotent: re-running it preserves any existing Hermes config and just updates the Groq provider section.

---

## 📁 Files written

```
~/.hermes/
├── .env                # GROQ_API_KEY (+ Telegram secrets if provided), mode 600
└── config.yaml         # Provider definition, default model
```

To inspect:

```bash
cat ~/.hermes/config.yaml
hermes config show         # if your version supports it
```

To rotate the Groq key later, just edit `~/.hermes/.env`:

```bash
nano ~/.hermes/.env
```

No restart needed — Hermes reads it on every invocation.

---

## 🤖 Default model

`llama-3.3-70b-versatile` (Groq's flagship Llama 3.3 70B).

Other Groq models you can swap in (edit `~/.hermes/config.yaml` → `model:` field):

| Model | When to use |
|---|---|
| `llama-3.3-70b-versatile` | Default — best reasoning quality |
| `llama-3.1-8b-instant` | Fastest, cheapest |
| `openai/gpt-oss-120b` | Open-source alternative |
| `qwen/qwen3-32b` | Strong coding/reasoning |
| `moonshotai/kimi-k2-instruct` | Long context |

Latest list: [console.groq.com/dashboard/models](https://console.groq.com/dashboard/models)

---

## 🛠 Troubleshooting

| Problem | Fix |
|---|---|
| `hermes: command not found` after install | Open a **new shell**, or run `source ~/.bashrc`. The installer added `~/.local/bin` to your PATH but the current shell hasn't reloaded yet. |
| `HTTP 401` from Groq during verify | Your API key is wrong or revoked. Generate fresh at [console.groq.com/keys](https://console.groq.com/keys), re-run installer. |
| `HTTP 404 model_not_found` | Model name typo. Try `llama-3.3-70b-versatile` or `llama-3.1-8b-instant`. |
| Want to reset everything | `rm -rf ~/.hermes/` then re-run the installer. ⚠️ Removes all skills, learning, history. |
| Ingin memakai provider lain juga | Edit `~/.hermes/config.yaml` manually, atau ikuti [docs Adding Providers](https://hermes-agent.nousresearch.com/docs/developer-guide/adding-providers). |

---

## 📚 Links

- 🏠 Hermes Agent home: https://hermes-agent.nousresearch.com/
- 📖 Official docs: https://hermes-agent.nousresearch.com/docs/
- 💻 Source: https://github.com/NousResearch/hermes-agent
- 🧠 Skills hub: https://hermes-agent.nousresearch.com/docs/skills
- 🔑 Groq console: https://console.groq.com/

---

## ⚖️ License

This installer script: MIT.

Hermes Agent itself is licensed by Nous Research — see their [repository](https://github.com/NousResearch/hermes-agent) for terms.
