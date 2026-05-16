#!/usr/bin/env bash
###############################################################################
#  install-nous-hermes.sh
#
#  One-shot installer for the official Hermes Agent by Nous Research, wired up
#  to use Groq as the LLM provider out of the box. Optional: Telegram gateway.
#
#  Targets : Ubuntu 22.04 / 24.04 / Debian 12 / similar (apt-based)
#  Author  : Kiro for keinankairi-afk
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/keinankairi-afk/Setup-hermes/main/install-nous-hermes.sh)
#
#  The script is INTERACTIVE — it will prompt for:
#    1. GROQ_API_KEY              (required, starts with "gsk_")
#    2. AI_MODEL                  (default: llama-3.3-70b-versatile)
#    3. TELEGRAM_BOT_TOKEN        (optional, leave empty to skip)
#    4. TELEGRAM_CHAT_ID          (optional, only if you set bot token)
#
#  What it does:
#    - Installs OS prerequisites (curl, git, build-essential, python3-venv)
#    - Runs the official Hermes installer from NousResearch/hermes-agent
#    - Writes ~/.hermes/.env with GROQ_API_KEY (+ Telegram if given)
#    - Writes ~/.hermes/config.yaml with Groq as a custom OpenAI-compatible
#      provider, and your chosen model as the default
#    - Sends a test prompt to verify Groq accepts the key + model
#    - Prints next-step commands
#
#  Re-run safe: detects existing installs, won't clobber other Hermes config.
###############################################################################

set -euo pipefail

# ---------------------------------------------------------------------------- #
# Cosmetics                                                                    #
# ---------------------------------------------------------------------------- #
if [[ -t 1 ]]; then
    C_RESET="\033[0m"; C_BOLD="\033[1m"; C_DIM="\033[2m"
    C_RED="\033[31m"; C_GREEN="\033[32m"; C_YELLOW="\033[33m"
    C_BLUE="\033[34m"; C_CYAN="\033[36m"
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""
    C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

log_info()  { echo -e "${C_CYAN}[INFO]${C_RESET}  $*"; }
log_ok()    { echo -e "${C_GREEN}[ OK ]${C_RESET}  $*"; }
log_warn()  { echo -e "${C_YELLOW}[WARN]${C_RESET}  $*"; }
log_err()   { echo -e "${C_RED}[FAIL]${C_RESET}  $*" >&2; }
log_step()  { echo -e "\n${C_BOLD}${C_BLUE}▌${C_RESET} ${C_BOLD}$*${C_RESET}"; }

trap 'log_err "Installer aborted on line $LINENO. Scroll up for the cause."; exit 1' ERR

# ---------------------------------------------------------------------------- #
# Banner                                                                       #
# ---------------------------------------------------------------------------- #
clear
cat <<'BANNER'
  _   _ _____ ____  __  __ _____ ____      _    ___
 | | | | ____|  _ \|  \/  | ____/ ___|    / \  |_ _|
 | |_| |  _| | |_) | |\/| |  _| \___ \   / _ \  | |
 |  _  | |___|  _ <| |  | | |___ ___) | / ___ \ | |
 |_| |_|_____|_| \_\_|  |_|_____|____/ /_/   \_\___|

       N O U S   R E S E A R C H   +   G R O Q

BANNER
echo -e "${C_DIM}Installs the official Hermes Agent (Nous Research) and wires it${C_RESET}"
echo -e "${C_DIM}up to use your Groq API key. Optional Telegram gateway.${C_RESET}"
echo

# ---------------------------------------------------------------------------- #
# Pre-flight                                                                   #
# ---------------------------------------------------------------------------- #
if [[ "${EUID}" -eq 0 ]]; then
    log_warn "Running as root. Hermes Agent is normally installed per-user."
    log_warn "It will install into /root/.hermes/. Continue? (y/N)"
    read -r -p "> " confirm </dev/tty || confirm="n"
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        log_info "Re-run as a non-root user, e.g.: bash <(curl ...)"
        exit 0
    fi
fi

# Ensure we have a controlling terminal for prompts (works under `curl | bash`).
if [[ ! -t 0 ]] && [[ ! -r /dev/tty ]]; then
    log_err "No interactive terminal available. Run from an interactive shell."
    exit 1
fi

prompt_required() {
    local label="$1"
    local hint="${2:-}"
    local var
    while true; do
        if [[ -n "${hint}" ]]; then
            printf "%b? %s%b ${C_DIM}(%s)${C_RESET}: " "${C_YELLOW}" "${label}" "${C_RESET}" "${hint}" >&2
        else
            printf "%b? %s%b: " "${C_YELLOW}" "${label}" "${C_RESET}" >&2
        fi
        if ! IFS= read -r var </dev/tty; then
            log_err "Failed to read input from terminal."
            exit 1
        fi
        if [[ -n "${var// }" ]]; then
            printf '%s' "${var}"
            return 0
        fi
        log_warn "Value cannot be empty."
    done
}

prompt_optional() {
    local label="$1"
    local default="${2:-}"
    local var
    if [[ -n "${default}" ]]; then
        printf "%b? %s%b ${C_DIM}[default: %s]${C_RESET}: " "${C_YELLOW}" "${label}" "${C_RESET}" "${default}" >&2
    else
        printf "%b? %s%b ${C_DIM}(optional, press Enter to skip)${C_RESET}: " "${C_YELLOW}" "${label}" "${C_RESET}" >&2
    fi
    if ! IFS= read -r var </dev/tty; then
        var=""
    fi
    if [[ -z "${var// }" ]]; then
        printf '%s' "${default}"
    else
        printf '%s' "${var}"
    fi
}

# ---------------------------------------------------------------------------- #
# Step 1 — OS prerequisites                                                    #
# ---------------------------------------------------------------------------- #
log_step "1/6  Installing OS prerequisites"

if command -v apt-get >/dev/null 2>&1; then
    SUDO=""
    if [[ "${EUID}" -ne 0 ]]; then
        if ! command -v sudo >/dev/null 2>&1; then
            log_err "sudo is required to install OS packages but is not available."
            exit 1
        fi
        SUDO="sudo"
    fi
    export DEBIAN_FRONTEND=noninteractive
    ${SUDO} apt-get update -qq
    ${SUDO} apt-get install -y -qq \
        curl git ca-certificates \
        python3 python3-venv python3-pip \
        build-essential jq
    log_ok "apt prerequisites installed"
elif command -v dnf >/dev/null 2>&1; then
    log_warn "dnf detected — installing best-effort base packages"
    sudo dnf install -y curl git python3 python3-pip jq gcc make
elif command -v pacman >/dev/null 2>&1; then
    log_warn "pacman detected — installing best-effort base packages"
    sudo pacman -Sy --noconfirm curl git python python-pip jq base-devel
else
    log_warn "Unknown package manager. Make sure curl, git, python3 (>=3.11), and pip are installed."
fi

# ---------------------------------------------------------------------------- #
# Step 2 — Run the official Hermes Agent installer                             #
# ---------------------------------------------------------------------------- #
log_step "2/6  Installing Hermes Agent (Nous Research)"

HERMES_BIN=""
locate_hermes() {
    if command -v hermes >/dev/null 2>&1; then
        HERMES_BIN="$(command -v hermes)"
        return 0
    fi
    for candidate in \
        "${HOME}/.local/bin/hermes" \
        "${HOME}/.cargo/bin/hermes" \
        "/usr/local/bin/hermes"; do
        if [[ -x "${candidate}" ]]; then
            HERMES_BIN="${candidate}"
            return 0
        fi
    done
    return 1
}

if locate_hermes; then
    log_ok "hermes already installed at ${HERMES_BIN}"
else
    log_info "Running official installer from raw.githubusercontent.com/NousResearch/hermes-agent ..."
    # The official installer manages its own venv + uv. Don't use `set -e` cancellation
    # for it, because it has its own retry logic.
    set +e
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
    install_rc=$?
    set -e
    if [[ ${install_rc} -ne 0 ]]; then
        log_err "Official Hermes installer exited with status ${install_rc}."
        log_err "Try running the same command manually, or visit:"
        log_err "  https://hermes-agent.nousresearch.com/docs/getting-started/installation"
        exit 1
    fi

    # Re-load shell config for this session so `hermes` is on PATH.
    # The installer typically appends to ~/.bashrc / ~/.zshrc.
    export PATH="${HOME}/.local/bin:${PATH}"
    if ! locate_hermes; then
        log_err "Installer finished but 'hermes' is not on PATH yet."
        log_err "Open a new shell (or run: source ~/.bashrc) and re-run this script."
        exit 1
    fi
    log_ok "hermes installed at ${HERMES_BIN}"
fi

"${HERMES_BIN}" --version 2>/dev/null || true

# ---------------------------------------------------------------------------- #
# Step 3 — Collect credentials from the user                                   #
# ---------------------------------------------------------------------------- #
log_step "3/6  Configuration"

echo
echo -e "${C_DIM}You'll be asked for:${C_RESET}"
echo -e "${C_DIM}  • Groq API key      (required, starts with 'gsk_')${C_RESET}"
echo -e "${C_DIM}  • Default Groq model (press Enter for the recommended default)${C_RESET}"
echo -e "${C_DIM}  • Telegram bot token + chat id (optional — press Enter to skip)${C_RESET}"
echo

GROQ_API_KEY="$(prompt_required 'GROQ API KEY' 'gsk_...')"
if [[ ! "${GROQ_API_KEY}" =~ ^gsk_ ]]; then
    log_warn "Your key doesn't start with 'gsk_' — Groq keys usually do."
    log_warn "Continuing anyway, but Groq will likely reject it."
fi

AI_MODEL="$(prompt_optional 'GROQ MODEL' 'llama-3.3-70b-versatile')"

TELEGRAM_BOT_TOKEN="$(prompt_optional 'TELEGRAM BOT TOKEN' '')"
TELEGRAM_CHAT_ID=""
if [[ -n "${TELEGRAM_BOT_TOKEN}" ]]; then
    TELEGRAM_CHAT_ID="$(prompt_required 'TELEGRAM CHAT ID')"
fi

# ---------------------------------------------------------------------------- #
# Step 4 — Verify the Groq credentials BEFORE writing config                   #
# ---------------------------------------------------------------------------- #
log_step "4/6  Verifying Groq API key + model"

GROQ_BASE_URL="https://api.groq.com/openai/v1"
GROQ_RESP_BODY="$(mktemp)"
GROQ_HTTP=$(curl -sS --max-time 15 -o "${GROQ_RESP_BODY}" -w "%{http_code}" \
    "${GROQ_BASE_URL}/chat/completions" \
    -H "Authorization: Bearer ${GROQ_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${AI_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":1}" || echo "000")

case "${GROQ_HTTP}" in
    200)
        log_ok "Groq accepted the key + model (HTTP 200)"
        ;;
    401)
        log_err "Groq returned HTTP 401 — invalid API key."
        log_err "Body: $(head -c 300 "${GROQ_RESP_BODY}")"
        log_err "Fix: regenerate at https://console.groq.com/keys and re-run this script."
        rm -f "${GROQ_RESP_BODY}"
        exit 1
        ;;
    404|400)
        log_err "Groq returned HTTP ${GROQ_HTTP} — model '${AI_MODEL}' likely not available."
        log_err "Body: $(head -c 300 "${GROQ_RESP_BODY}")"
        log_err "Try a known-good model name, e.g.:"
        log_err "  • llama-3.3-70b-versatile"
        log_err "  • llama-3.1-8b-instant"
        rm -f "${GROQ_RESP_BODY}"
        exit 1
        ;;
    429)
        log_warn "Groq rate-limited the verification ping (HTTP 429)."
        log_warn "Continuing — real usage may work once limits reset."
        ;;
    000)
        log_err "Could not reach api.groq.com — check internet/DNS on this server."
        rm -f "${GROQ_RESP_BODY}"
        exit 1
        ;;
    *)
        log_warn "Groq returned HTTP ${GROQ_HTTP}. Continuing, but expect issues."
        log_warn "Body: $(head -c 300 "${GROQ_RESP_BODY}")"
        ;;
esac
rm -f "${GROQ_RESP_BODY}"

# ---------------------------------------------------------------------------- #
# Step 5 — Write Hermes config                                                 #
# ---------------------------------------------------------------------------- #
log_step "5/6  Writing Hermes config (~/.hermes/)"

HERMES_DIR="${HOME}/.hermes"
mkdir -p "${HERMES_DIR}"
ENV_FILE="${HERMES_DIR}/.env"
CONFIG_FILE="${HERMES_DIR}/config.yaml"

# --- .env  (secrets only) -----------------------------------------------------
# Preserve other env keys the user may already have configured.
TMP_ENV="$(mktemp)"
if [[ -f "${ENV_FILE}" ]]; then
    grep -v -E '^(GROQ_API_KEY|TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID)=' "${ENV_FILE}" > "${TMP_ENV}" || true
fi
{
    echo "# Managed by install-nous-hermes.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "GROQ_API_KEY=${GROQ_API_KEY}"
    if [[ -n "${TELEGRAM_BOT_TOKEN}" ]]; then
        echo "TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}"
        echo "TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}"
    fi
} >> "${TMP_ENV}"
mv "${TMP_ENV}" "${ENV_FILE}"
chmod 600 "${ENV_FILE}"
log_ok "wrote ${ENV_FILE} (mode 600)"

# --- config.yaml  (provider definition) --------------------------------------
# We treat Groq as a "custom OpenAI-compatible provider". This is the path the
# official docs recommend for any OpenAI-style endpoint that isn't built in.
#
#   https://hermes-agent.nousresearch.com/docs/developer-guide/adding-providers
#
# If a config.yaml already exists, we MERGE rather than overwrite, so we don't
# clobber other settings (model lists, MCP servers, channels, etc.).

if [[ -f "${CONFIG_FILE}" ]]; then
    BACKUP="${CONFIG_FILE}.bak.$(date +%s)"
    cp "${CONFIG_FILE}" "${BACKUP}"
    log_info "Backed up existing config to ${BACKUP}"
fi

python3 - "${CONFIG_FILE}" "${AI_MODEL}" <<'PY'
import os, sys, pathlib

cfg_path = pathlib.Path(sys.argv[1])
model    = sys.argv[2]

# Try to use PyYAML if available so we preserve the user's other settings
# faithfully. If not, fall back to writing a minimal-but-valid config.
try:
    import yaml  # type: ignore
    have_yaml = True
except Exception:
    have_yaml = False

groq_block = {
    "type": "openai_compatible",
    "base_url": "https://api.groq.com/openai/v1",
    "api_key_env": "GROQ_API_KEY",
    "models": [
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
        "qwen/qwen3-32b",
        "moonshotai/kimi-k2-instruct",
    ],
}

if have_yaml and cfg_path.exists():
    data = yaml.safe_load(cfg_path.read_text()) or {}
    providers = data.setdefault("providers", {})
    providers["groq"] = groq_block
    data["provider"] = "groq"
    data["model"] = model
    cfg_path.write_text(yaml.safe_dump(data, sort_keys=False))
    print(f"[ok] merged Groq provider into existing {cfg_path}")
elif have_yaml:
    data = {
        "provider": "groq",
        "model": model,
        "providers": {"groq": groq_block},
    }
    cfg_path.write_text(yaml.safe_dump(data, sort_keys=False))
    print(f"[ok] wrote new {cfg_path}")
else:
    # Minimal hand-written YAML — works without PyYAML.
    cfg_path.write_text(f"""# Managed by install-nous-hermes.sh
provider: groq
model: {model}
providers:
  groq:
    type: openai_compatible
    base_url: https://api.groq.com/openai/v1
    api_key_env: GROQ_API_KEY
    models:
      - llama-3.3-70b-versatile
      - llama-3.1-8b-instant
      - openai/gpt-oss-120b
      - openai/gpt-oss-20b
      - qwen/qwen3-32b
      - moonshotai/kimi-k2-instruct
""")
    print(f"[ok] wrote new {cfg_path} (PyYAML not available, used template)")
PY

log_ok "wrote ${CONFIG_FILE}"

# Also try the canonical `hermes config set` path. If the running version of
# Hermes uses a different config schema, this will be the one that "wins" and
# the YAML we wrote will be ignored harmlessly.
if "${HERMES_BIN}" config --help >/dev/null 2>&1; then
    log_info "Trying 'hermes config set' as a backup path (best-effort)..."
    set +e
    "${HERMES_BIN}" config set provider groq                         >/dev/null 2>&1
    "${HERMES_BIN}" config set model "${AI_MODEL}"                   >/dev/null 2>&1
    "${HERMES_BIN}" config set providers.groq.type openai_compatible >/dev/null 2>&1
    "${HERMES_BIN}" config set providers.groq.base_url "https://api.groq.com/openai/v1" >/dev/null 2>&1
    "${HERMES_BIN}" config set providers.groq.api_key_env GROQ_API_KEY                  >/dev/null 2>&1
    set -e
    log_ok "best-effort 'hermes config set' calls completed"
fi

# ---------------------------------------------------------------------------- #
# Step 6 — Summary + next steps                                                #
# ---------------------------------------------------------------------------- #
log_step "6/6  Done"

echo
echo -e "${C_GREEN}${C_BOLD}╔══════════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}║   HERMES AGENT INSTALLED & CONFIGURED FOR GROQ       ║${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}╚══════════════════════════════════════════════════════╝${C_RESET}"
echo
echo -e "  ${C_BOLD}hermes binary :${C_RESET} ${HERMES_BIN}"
echo -e "  ${C_BOLD}config dir    :${C_RESET} ${HERMES_DIR}"
echo -e "  ${C_BOLD}env file      :${C_RESET} ${ENV_FILE}"
echo -e "  ${C_BOLD}config file   :${C_RESET} ${CONFIG_FILE}"
echo -e "  ${C_BOLD}provider      :${C_RESET} groq  (https://api.groq.com/openai/v1)"
echo -e "  ${C_BOLD}model         :${C_RESET} ${AI_MODEL}"
if [[ -n "${TELEGRAM_BOT_TOKEN}" ]]; then
    echo -e "  ${C_BOLD}telegram      :${C_RESET} configured (chat id ${TELEGRAM_CHAT_ID})"
else
    echo -e "  ${C_BOLD}telegram      :${C_RESET} ${C_DIM}skipped${C_RESET}"
fi
echo
echo -e "${C_BOLD}Try it:${C_RESET}"
echo -e "  ${C_CYAN}hermes${C_RESET} \"halo, perkenalkan dirimu\""
echo
echo -e "${C_BOLD}Other useful commands:${C_RESET}"
echo -e "  ${C_CYAN}hermes --help${C_RESET}                show all commands"
echo -e "  ${C_CYAN}hermes config show${C_RESET}           print current config"
echo -e "  ${C_CYAN}cat ~/.hermes/.env${C_RESET}           inspect secrets (read-only sensible)"
echo -e "  ${C_CYAN}hermes update${C_RESET}                update Hermes Agent"
echo
if [[ -n "${TELEGRAM_BOT_TOKEN}" ]]; then
    echo -e "${C_YELLOW}Telegram note:${C_RESET}"
    echo -e "  Hermes ships a Telegram gateway as an optional skill. To enable it,"
    echo -e "  follow the docs at:"
    echo -e "    https://hermes-agent.nousresearch.com/docs/user-guide/messaging/"
    echo -e "  Your token + chat id are already in ${ENV_FILE}, so the gateway"
    echo -e "  will pick them up automatically once enabled."
    echo
fi
echo -e "${C_DIM}If 'hermes' is not found in this terminal, open a NEW shell first${C_RESET}"
echo -e "${C_DIM}(or run: source ~/.bashrc) — the installer added it to your PATH.${C_RESET}"
echo
