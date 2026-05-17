#!/usr/bin/env bash
###############################################################################
#  install-nous-hermes.sh
#
#  One-shot installer for the official Hermes Agent by Nous Research, with a
#  menu to pick your LLM provider at install time. Optional Telegram gateway.
#
#  Supported providers (pilih saat install):
#    1. Groq         (default — OpenAI-compatible)
#    2. OpenAI
#    3. Anthropic
#    4. OpenRouter
#    5. DeepSeek
#    6. Together AI
#    7. Custom OpenAI-compatible endpoint
#
#  Targets : Ubuntu 22.04 / 24.04 / Debian 12 / similar (apt-based)
#  Author  : Kiro for keinankairi-afk
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/keinankairi-afk/Hermestest/main/install.sh)
#
#  The script is INTERACTIVE — it will prompt for:
#    1. PROVIDER          (1..7, default 1 = Groq)
#    2. <PROVIDER>_API_KEY (required)
#    3. AI_MODEL          (default depends on provider)
#    4. TELEGRAM_BOT_TOKEN (optional, leave empty to skip)
#    5. TELEGRAM_CHAT_ID   (optional, only if you set bot token)
#
#  What it does:
#    - Installs OS prerequisites (curl, git, build-essential, python3-venv)
#    - Runs the official Hermes installer from NousResearch/hermes-agent
#    - Writes ~/.hermes/.env with the chosen provider's key var
#      (+ Telegram if given)
#    - Writes ~/.hermes/config.yaml with the chosen provider registered
#      (OpenAI-compatible for everything except Anthropic), and your
#      chosen model as the default
#    - Sends a 1-token test prompt to verify the provider accepts the
#      key + model
#    - Prints next-step commands
#
#  Re-run safe: detects existing installs, won't clobber other Hermes config,
#  and strips stale provider keys from ~/.hermes/.env when you switch.
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

       N O U S   R E S E A R C H

BANNER
echo -e "${C_DIM}Installs the official Hermes Agent (Nous Research) and lets you${C_RESET}"
echo -e "${C_DIM}pick your LLM provider (Groq, OpenAI, Anthropic, OpenRouter,${C_RESET}"
echo -e "${C_DIM}DeepSeek, Together AI, or a custom endpoint). Optional Telegram.${C_RESET}"
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
# Step 3 — Pick LLM provider, then collect credentials                         #
# ---------------------------------------------------------------------------- #
log_step "3/6  Configuration"

echo
echo -e "${C_BOLD}Pilih LLM provider / Choose LLM provider:${C_RESET}"
echo -e "  ${C_BOLD}1)${C_RESET} Groq           ${C_DIM}— OpenAI-compatible, default${C_RESET}"
echo -e "  ${C_BOLD}2)${C_RESET} OpenAI         ${C_DIM}— api.openai.com/v1${C_RESET}"
echo -e "  ${C_BOLD}3)${C_RESET} Anthropic      ${C_DIM}— Claude (api.anthropic.com)${C_RESET}"
echo -e "  ${C_BOLD}4)${C_RESET} OpenRouter     ${C_DIM}— openrouter.ai (many models, one key)${C_RESET}"
echo -e "  ${C_BOLD}5)${C_RESET} DeepSeek       ${C_DIM}— api.deepseek.com${C_RESET}"
echo -e "  ${C_BOLD}6)${C_RESET} Together AI    ${C_DIM}— api.together.xyz${C_RESET}"
echo -e "  ${C_BOLD}7)${C_RESET} Custom         ${C_DIM}— any other OpenAI-compatible endpoint${C_RESET}"
echo

PROVIDER_CHOICE="$(prompt_optional 'Provider [1-7]' '1')"

# Normalize and dispatch
PROVIDER_ID=""
PROVIDER_NAME=""
PROVIDER_BASE_URL=""
PROVIDER_KEY_ENV=""
PROVIDER_DEFAULT_MODEL=""
PROVIDER_TYPE="openai_compatible"
# Space-separated list of model names to register in config.yaml.
PROVIDER_MODELS=""

case "${PROVIDER_CHOICE}" in
    1|groq|Groq|GROQ|"")
        PROVIDER_ID="groq"
        PROVIDER_NAME="Groq"
        PROVIDER_BASE_URL="https://api.groq.com/openai/v1"
        PROVIDER_KEY_ENV="GROQ_API_KEY"
        PROVIDER_DEFAULT_MODEL="llama-3.3-70b-versatile"
        PROVIDER_MODELS="llama-3.3-70b-versatile llama-3.1-8b-instant openai/gpt-oss-120b openai/gpt-oss-20b qwen/qwen3-32b moonshotai/kimi-k2-instruct"
        ;;
    2|openai|OpenAI|OPENAI)
        PROVIDER_ID="openai"
        PROVIDER_NAME="OpenAI"
        PROVIDER_BASE_URL="https://api.openai.com/v1"
        PROVIDER_KEY_ENV="OPENAI_API_KEY"
        PROVIDER_DEFAULT_MODEL="gpt-4o-mini"
        PROVIDER_MODELS="gpt-4o gpt-4o-mini gpt-4-turbo o1-mini"
        ;;
    3|anthropic|Anthropic|ANTHROPIC|claude|Claude)
        PROVIDER_ID="anthropic"
        PROVIDER_NAME="Anthropic"
        PROVIDER_BASE_URL="https://api.anthropic.com/v1"
        PROVIDER_KEY_ENV="ANTHROPIC_API_KEY"
        PROVIDER_DEFAULT_MODEL="claude-3-5-sonnet-latest"
        PROVIDER_TYPE="anthropic"
        PROVIDER_MODELS="claude-3-5-sonnet-latest claude-3-5-haiku-latest claude-3-opus-latest"
        ;;
    4|openrouter|OpenRouter|OPENROUTER)
        PROVIDER_ID="openrouter"
        PROVIDER_NAME="OpenRouter"
        PROVIDER_BASE_URL="https://openrouter.ai/api/v1"
        PROVIDER_KEY_ENV="OPENROUTER_API_KEY"
        PROVIDER_DEFAULT_MODEL="meta-llama/llama-3.3-70b-instruct"
        PROVIDER_MODELS="meta-llama/llama-3.3-70b-instruct anthropic/claude-3.5-sonnet openai/gpt-4o-mini"
        ;;
    5|deepseek|DeepSeek|DEEPSEEK)
        PROVIDER_ID="deepseek"
        PROVIDER_NAME="DeepSeek"
        PROVIDER_BASE_URL="https://api.deepseek.com/v1"
        PROVIDER_KEY_ENV="DEEPSEEK_API_KEY"
        PROVIDER_DEFAULT_MODEL="deepseek-chat"
        PROVIDER_MODELS="deepseek-chat deepseek-reasoner"
        ;;
    6|together|Together|TOGETHER|togetherai)
        PROVIDER_ID="together"
        PROVIDER_NAME="Together AI"
        PROVIDER_BASE_URL="https://api.together.xyz/v1"
        PROVIDER_KEY_ENV="TOGETHER_API_KEY"
        PROVIDER_DEFAULT_MODEL="meta-llama/Llama-3.3-70B-Instruct-Turbo"
        PROVIDER_MODELS="meta-llama/Llama-3.3-70B-Instruct-Turbo meta-llama/Llama-3.1-8B-Instruct-Turbo"
        ;;
    7|custom|Custom|CUSTOM)
        PROVIDER_ID="custom"
        PROVIDER_NAME="Custom (OpenAI-compatible)"
        PROVIDER_BASE_URL="$(prompt_required 'CUSTOM BASE URL' 'e.g. https://api.example.com/v1')"
        PROVIDER_KEY_ENV="$(prompt_optional 'CUSTOM ENV VAR NAME for API key' 'LLM_API_KEY')"
        # Sanitize env var name — must be a valid POSIX-ish shell identifier.
        if [[ ! "${PROVIDER_KEY_ENV}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            log_warn "'${PROVIDER_KEY_ENV}' is not a valid env var name. Falling back to LLM_API_KEY."
            PROVIDER_KEY_ENV="LLM_API_KEY"
        fi
        PROVIDER_DEFAULT_MODEL="$(prompt_required 'CUSTOM DEFAULT MODEL' 'e.g. my-llama-3.3-70b')"
        PROVIDER_MODELS="${PROVIDER_DEFAULT_MODEL}"
        ;;
    *)
        log_err "Invalid choice '${PROVIDER_CHOICE}'. Pick a number from 1 to 7."
        exit 1
        ;;
esac

log_info "Provider: ${C_BOLD}${PROVIDER_NAME}${C_RESET} (${PROVIDER_BASE_URL})"
log_info "API key env var: ${C_BOLD}${PROVIDER_KEY_ENV}${C_RESET}"

echo
echo -e "${C_DIM}You'll be asked for:${C_RESET}"
echo -e "${C_DIM}  • ${PROVIDER_NAME} API key  (required)${C_RESET}"
echo -e "${C_DIM}  • Default model            (press Enter for ${PROVIDER_DEFAULT_MODEL})${C_RESET}"
echo -e "${C_DIM}  • Telegram bot token + chat id (optional — press Enter to skip)${C_RESET}"
echo

LLM_API_KEY="$(prompt_required "${PROVIDER_NAME} API KEY")"
if [[ "${PROVIDER_ID}" == "groq" ]]; then
    if [[ ! "${LLM_API_KEY}" =~ ^gsk_ ]]; then
        log_warn "Your key doesn't start with 'gsk_' — Groq keys usually do."
        log_warn "Continuing anyway, but Groq will likely reject it."
    fi
fi

AI_MODEL="$(prompt_optional "${PROVIDER_NAME} MODEL" "${PROVIDER_DEFAULT_MODEL}")"

TELEGRAM_BOT_TOKEN="$(prompt_optional 'TELEGRAM BOT TOKEN' '')"
TELEGRAM_CHAT_ID=""
if [[ -n "${TELEGRAM_BOT_TOKEN}" ]]; then
    TELEGRAM_CHAT_ID="$(prompt_required 'TELEGRAM CHAT ID')"
fi

# ---------------------------------------------------------------------------- #
# Step 4 — Verify the LLM credentials BEFORE writing config                    #
# ---------------------------------------------------------------------------- #
log_step "4/6  Verifying ${PROVIDER_NAME} API key + model"

LLM_RESP_BODY="$(mktemp)"
if [[ "${PROVIDER_TYPE}" == "anthropic" ]]; then
    LLM_HTTP=$(curl -sS --max-time 15 -o "${LLM_RESP_BODY}" -w "%{http_code}" \
        "${PROVIDER_BASE_URL}/messages" \
        -H "x-api-key: ${LLM_API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${AI_MODEL}\",\"max_tokens\":1,\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}]}" || echo "000")
else
    LLM_HTTP=$(curl -sS --max-time 15 -o "${LLM_RESP_BODY}" -w "%{http_code}" \
        "${PROVIDER_BASE_URL}/chat/completions" \
        -H "Authorization: Bearer ${LLM_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"${AI_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":1}" || echo "000")
fi

case "${LLM_HTTP}" in
    200)
        log_ok "${PROVIDER_NAME} accepted the key + model (HTTP 200)"
        ;;
    401|403)
        log_err "${PROVIDER_NAME} returned HTTP ${LLM_HTTP} — invalid or unauthorized API key."
        log_err "Body: $(head -c 300 "${LLM_RESP_BODY}")"
        log_err "Fix: regenerate your key at the provider's console and re-run this script."
        rm -f "${LLM_RESP_BODY}"
        exit 1
        ;;
    404|400)
        log_err "${PROVIDER_NAME} returned HTTP ${LLM_HTTP} — model '${AI_MODEL}' likely not available."
        log_err "Body: $(head -c 300 "${LLM_RESP_BODY}")"
        log_err "Try a known-good model name for ${PROVIDER_NAME} (default was: ${PROVIDER_DEFAULT_MODEL})."
        rm -f "${LLM_RESP_BODY}"
        exit 1
        ;;
    429)
        log_warn "${PROVIDER_NAME} rate-limited the verification ping (HTTP 429)."
        log_warn "Continuing — real usage may work once limits reset."
        ;;
    000)
        log_err "Could not reach ${PROVIDER_BASE_URL} — check internet/DNS on this server."
        rm -f "${LLM_RESP_BODY}"
        exit 1
        ;;
    *)
        log_warn "${PROVIDER_NAME} returned HTTP ${LLM_HTTP}. Continuing, but expect issues."
        log_warn "Body: $(head -c 300 "${LLM_RESP_BODY}")"
        ;;
esac
rm -f "${LLM_RESP_BODY}"

# ---------------------------------------------------------------------------- #
# Step 5 — Write Hermes config                                                 #
# ---------------------------------------------------------------------------- #
log_step "5/6  Writing Hermes config (~/.hermes/)"

HERMES_DIR="${HOME}/.hermes"
mkdir -p "${HERMES_DIR}"
ENV_FILE="${HERMES_DIR}/.env"
CONFIG_FILE="${HERMES_DIR}/config.yaml"

# --- .env  (secrets only) -----------------------------------------------------
# Preserve other env keys the user may already have configured. We strip ALL
# known provider key vars so switching providers doesn't leave a stale key
# from a previous install lying around.
TMP_ENV="$(mktemp)"
if [[ -f "${ENV_FILE}" ]]; then
    grep -v -E '^(GROQ_API_KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY|OPENROUTER_API_KEY|DEEPSEEK_API_KEY|TOGETHER_API_KEY|LLM_API_KEY|TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID)=' "${ENV_FILE}" > "${TMP_ENV}" || true
    # If the user picked Custom with a non-default env var name, also strip
    # that exact name from any prior run, to keep the file clean on switches.
    if [[ "${PROVIDER_KEY_ENV}" != "GROQ_API_KEY" && "${PROVIDER_KEY_ENV}" != "OPENAI_API_KEY" && \
          "${PROVIDER_KEY_ENV}" != "ANTHROPIC_API_KEY" && "${PROVIDER_KEY_ENV}" != "OPENROUTER_API_KEY" && \
          "${PROVIDER_KEY_ENV}" != "DEEPSEEK_API_KEY" && "${PROVIDER_KEY_ENV}" != "TOGETHER_API_KEY" && \
          "${PROVIDER_KEY_ENV}" != "LLM_API_KEY" ]]; then
        TMP_ENV2="$(mktemp)"
        grep -v -E "^${PROVIDER_KEY_ENV}=" "${TMP_ENV}" > "${TMP_ENV2}" || true
        mv "${TMP_ENV2}" "${TMP_ENV}"
    fi
fi
{
    echo "# Managed by install-nous-hermes.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "${PROVIDER_KEY_ENV}=${LLM_API_KEY}"
    if [[ -n "${TELEGRAM_BOT_TOKEN}" ]]; then
        echo "TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}"
        echo "TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}"
    fi
} >> "${TMP_ENV}"
mv "${TMP_ENV}" "${ENV_FILE}"
chmod 600 "${ENV_FILE}"
log_ok "wrote ${ENV_FILE} (mode 600)"

# --- config.yaml  (provider definition) --------------------------------------
# We register the chosen provider as either "openai_compatible" (default) or
# "anthropic" (for Claude). This is the path the official docs recommend for
# any endpoint that isn't built in:
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

python3 - \
    "${CONFIG_FILE}" \
    "${AI_MODEL}" \
    "${PROVIDER_ID}" \
    "${PROVIDER_TYPE}" \
    "${PROVIDER_BASE_URL}" \
    "${PROVIDER_KEY_ENV}" \
    "${PROVIDER_MODELS}" \
    <<'PY'
import sys, pathlib

cfg_path     = pathlib.Path(sys.argv[1])
model        = sys.argv[2]
provider_id  = sys.argv[3]
provider_typ = sys.argv[4]
base_url     = sys.argv[5]
key_env      = sys.argv[6]
models_list  = [m for m in sys.argv[7].split() if m]

# Always include the chosen default model first.
if model not in models_list:
    models_list.insert(0, model)

# Try to use PyYAML if available so we preserve the user's other settings
# faithfully. If not, fall back to writing a minimal-but-valid config.
try:
    import yaml  # type: ignore
    have_yaml = True
except Exception:
    have_yaml = False

provider_block = {
    "type": provider_typ,
    "base_url": base_url,
    "api_key_env": key_env,
    "models": models_list,
}

if have_yaml and cfg_path.exists():
    data = yaml.safe_load(cfg_path.read_text()) or {}
    providers = data.setdefault("providers", {})
    providers[provider_id] = provider_block
    data["provider"] = provider_id
    data["model"] = model
    cfg_path.write_text(yaml.safe_dump(data, sort_keys=False))
    print(f"[ok] merged {provider_id} provider into existing {cfg_path}")
elif have_yaml:
    data = {
        "provider": provider_id,
        "model": model,
        "providers": {provider_id: provider_block},
    }
    cfg_path.write_text(yaml.safe_dump(data, sort_keys=False))
    print(f"[ok] wrote new {cfg_path}")
else:
    # Minimal hand-written YAML — works without PyYAML.
    models_yaml = "\n".join(f"      - {m}" for m in models_list)
    cfg_path.write_text(
        "# Managed by install-nous-hermes.sh\n"
        f"provider: {provider_id}\n"
        f"model: {model}\n"
        "providers:\n"
        f"  {provider_id}:\n"
        f"    type: {provider_typ}\n"
        f"    base_url: {base_url}\n"
        f"    api_key_env: {key_env}\n"
        "    models:\n"
        f"{models_yaml}\n"
    )
    print(f"[ok] wrote new {cfg_path} (PyYAML not available, used template)")
PY

log_ok "wrote ${CONFIG_FILE}"

# Also try the canonical `hermes config set` path. If the running version of
# Hermes uses a different config schema, this will be the one that "wins" and
# the YAML we wrote will be ignored harmlessly.
if "${HERMES_BIN}" config --help >/dev/null 2>&1; then
    log_info "Trying 'hermes config set' as a backup path (best-effort)..."
    set +e
    "${HERMES_BIN}" config set provider "${PROVIDER_ID}"                                       >/dev/null 2>&1
    "${HERMES_BIN}" config set model "${AI_MODEL}"                                             >/dev/null 2>&1
    "${HERMES_BIN}" config set "providers.${PROVIDER_ID}.type" "${PROVIDER_TYPE}"              >/dev/null 2>&1
    "${HERMES_BIN}" config set "providers.${PROVIDER_ID}.base_url" "${PROVIDER_BASE_URL}"      >/dev/null 2>&1
    "${HERMES_BIN}" config set "providers.${PROVIDER_ID}.api_key_env" "${PROVIDER_KEY_ENV}"    >/dev/null 2>&1
    set -e
    log_ok "best-effort 'hermes config set' calls completed"
fi

# ---------------------------------------------------------------------------- #
# Step 6 — Summary + next steps                                                #
# ---------------------------------------------------------------------------- #
log_step "6/6  Done"

echo
echo -e "${C_GREEN}${C_BOLD}╔══════════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}║   HERMES AGENT INSTALLED & CONFIGURED                ║${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}╚══════════════════════════════════════════════════════╝${C_RESET}"
echo
echo -e "  ${C_BOLD}hermes binary :${C_RESET} ${HERMES_BIN}"
echo -e "  ${C_BOLD}config dir    :${C_RESET} ${HERMES_DIR}"
echo -e "  ${C_BOLD}env file      :${C_RESET} ${ENV_FILE}"
echo -e "  ${C_BOLD}config file   :${C_RESET} ${CONFIG_FILE}"
echo -e "  ${C_BOLD}provider      :${C_RESET} ${PROVIDER_NAME}  (${PROVIDER_BASE_URL})"
echo -e "  ${C_BOLD}api key env   :${C_RESET} ${PROVIDER_KEY_ENV}"
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
