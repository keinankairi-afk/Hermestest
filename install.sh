#!/usr/bin/env bash
###############################################################################
#  install.sh  —  Hermes Agent (Nous Research) Super-Friendly Installer
#  ---------------------------------------------------------------------
#  Installer interaktif berbahasa Indonesia untuk Hermes Agent resmi dari
#  Nous Research. Mendukung banyak provider LLM (OpenAI, Anthropic, Grok,
#  Groq, OpenRouter, Gemini, DeepSeek, Mistral, Ollama, dll.), fallback
#  otomatis, gateway Telegram, manajemen skill, dan menu utama yang
#  mudah dipakai bahkan oleh pengguna pemula.
#
#  Cara pakai (one-liner):
#    bash <(curl -fsSL https://raw.githubusercontent.com/keinankairi-afk/Hermestest/main/install.sh)
#
#  Atau jalankan langsung setelah di-clone:
#    bash install.sh
#
#  Lisensi: MIT
###############################################################################

set -uo pipefail

# =============================================================================
#  WARNA & FUNGSI LOG
# =============================================================================
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m';  C_BOLD=$'\033[1m';   C_DIM=$'\033[2m'
    C_RED=$'\033[31m';   C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m';  C_MAGENTA=$'\033[35m'; C_CYAN=$'\033[36m'
    C_WHITE=$'\033[37m'
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""
    C_YELLOW=""; C_BLUE=""; C_MAGENTA=""; C_CYAN=""; C_WHITE=""
fi

log_info()  { echo -e "${C_CYAN}[INFO]${C_RESET}  $*"; }
log_ok()    { echo -e "${C_GREEN}[ OK ]${C_RESET}  $*"; }
log_warn()  { echo -e "${C_YELLOW}[ ! ]${C_RESET}   $*"; }
log_err()   { echo -e "${C_RED}[GAGAL]${C_RESET} $*" >&2; }
log_step()  { echo -e "\n${C_BOLD}${C_BLUE}▌${C_RESET} ${C_BOLD}$*${C_RESET}"; }
log_hint()  { echo -e "  ${C_DIM}↳ $*${C_RESET}"; }

hr() { echo -e "${C_DIM}────────────────────────────────────────────────────────────${C_RESET}"; }

press_enter() {
    echo
    read -r -p "$(echo -e "${C_DIM}Tekan ENTER untuk melanjutkan...${C_RESET}")" _ </dev/tty || true
}

# =============================================================================
#  KONSTANTA & LOKASI FILE
# =============================================================================
HERMES_DIR="${HOME}/.hermes"
ENV_FILE="${HERMES_DIR}/.env"
CONFIG_FILE="${HERMES_DIR}/config.yaml"
PROVIDERS_FILE="${HERMES_DIR}/providers.conf"   # daftar provider yg sudah disetup
FALLBACK_FILE="${HERMES_DIR}/fallback.conf"     # urutan fallback
SKILLS_DIR="${HERMES_DIR}/skills"
SOUL_FILE="${HERMES_DIR}/SOUL.md"                # kepribadian / identitas agent
LOG_FILE="${HERMES_DIR}/installer.log"

mkdir -p "${HERMES_DIR}" "${SKILLS_DIR}"
touch "${LOG_FILE}"

# =============================================================================
#  BANNER
# =============================================================================
show_banner() {
    clear
    echo -e "${C_MAGENTA}${C_BOLD}"
    cat <<'EOF'
  ╔═══════════════════════════════════════════════════════════════╗
  ║   _   _ _____ ____  __  __ _____ ____      _    ___           ║
  ║  | | | | ____|  _ \|  \/  | ____/ ___|    / \  |_ _|          ║
  ║  | |_| |  _| | |_) | |\/| |  _| \___ \   / _ \  | |           ║
  ║  |  _  | |___|  _ <| |  | | |___ ___) | / ___ \ | |           ║
  ║  |_| |_|_____|_| \_\_|  |_|_____|____/ /_/   \_\___|          ║
  ║                                                               ║
  ║          INSTALLER RAMAH PEMULA  ·  Nous Research             ║
  ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${C_RESET}"
    echo -e "  ${C_DIM}AI Agent autonomous (sekelas Claude Code / Codex)${C_RESET}"
    echo -e "  ${C_DIM}Versi installer: 2.0  ·  $(date '+%Y-%m-%d')${C_RESET}"
    echo
}

# =============================================================================
#  HELPER: PROMPT
# =============================================================================
prompt_required() {
    # $1 = label, $2 = hint (opsional)
    local label="$1" hint="${2:-}" var
    while true; do
        if [[ -n "${hint}" ]]; then
            printf "  ${C_YELLOW}?${C_RESET} %s ${C_DIM}(%s)${C_RESET}: " "${label}" "${hint}" >&2
        else
            printf "  ${C_YELLOW}?${C_RESET} %s: " "${label}" >&2
        fi
        IFS= read -r var </dev/tty || { log_err "Gagal membaca input."; exit 1; }
        if [[ -n "${var// }" ]]; then
            printf '%s' "${var}"
            return 0
        fi
        log_warn "Tidak boleh kosong, silakan isi."
    done
}

prompt_optional() {
    # $1 = label, $2 = default (opsional)
    local label="$1" default="${2:-}" var
    if [[ -n "${default}" ]]; then
        printf "  ${C_YELLOW}?${C_RESET} %s ${C_DIM}[default: %s]${C_RESET}: " "${label}" "${default}" >&2
    else
        printf "  ${C_YELLOW}?${C_RESET} %s ${C_DIM}(boleh kosong, tekan ENTER untuk lewati)${C_RESET}: " "${label}" >&2
    fi
    IFS= read -r var </dev/tty || var=""
    if [[ -z "${var// }" ]]; then
        printf '%s' "${default}"
    else
        printf '%s' "${var}"
    fi
}

prompt_secret() {
    # $1 = label
    local label="$1" var
    printf "  ${C_YELLOW}?${C_RESET} %s ${C_DIM}(input disembunyikan)${C_RESET}: " "${label}" >&2
    IFS= read -rs var </dev/tty || var=""
    echo >&2
    printf '%s' "${var}"
}

prompt_yes_no() {
    # $1 = pertanyaan, $2 = default (y/n)
    local q="$1" default="${2:-n}" ans
    local hint="[y/N]"
    [[ "${default}" == "y" ]] && hint="[Y/n]"
    while true; do
        printf "  ${C_YELLOW}?${C_RESET} %s ${C_DIM}%s${C_RESET}: " "${q}" "${hint}" >&2
        IFS= read -r ans </dev/tty || ans=""
        ans="${ans:-${default}}"
        case "${ans,,}" in
            y|ya|yes) return 0 ;;
            n|no|tidak) return 1 ;;
            *) log_warn "Jawab dengan y atau n." ;;
        esac
    done
}

prompt_choice() {
    # $1 = judul, sisanya = pilihan; cetak indeks (mulai 1) ke stdout
    local title="$1"; shift
    local options=("$@")
    local i choice
    echo >&2
    echo -e "  ${C_BOLD}${title}${C_RESET}" >&2
    for i in "${!options[@]}"; do
        printf "    ${C_CYAN}%2d)${C_RESET} %s\n" "$((i+1))" "${options[$i]}" >&2
    done
    while true; do
        printf "  ${C_YELLOW}?${C_RESET} Pilih nomor [1-%d]: " "${#options[@]}" >&2
        IFS= read -r choice </dev/tty || choice=""
        if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            printf '%s' "${choice}"
            return 0
        fi
        log_warn "Pilihan tidak valid."
    done
}

# =============================================================================
#  PROVIDER REGISTRY
# =============================================================================
# Format: nama|label|base_url|env_key|model_default|model_recommendation
PROVIDER_REGISTRY=(
    "openai|OpenAI (GPT-4o, GPT-5)|https://api.openai.com/v1|OPENAI_API_KEY|gpt-4o-mini|gpt-4o-mini, gpt-4o, gpt-4-turbo"
    "anthropic|Anthropic (Claude)|https://api.anthropic.com/v1|ANTHROPIC_API_KEY|claude-3-5-sonnet-latest|claude-3-5-sonnet-latest, claude-3-5-haiku-latest"
    "grok|xAI (Grok)|https://api.x.ai/v1|XAI_API_KEY|grok-2-latest|grok-2-latest, grok-beta"
    "groq|Groq (Llama, Mixtral - super cepat)|https://api.groq.com/openai/v1|GROQ_API_KEY|llama-3.3-70b-versatile|llama-3.3-70b-versatile, llama-3.1-8b-instant"
    "openrouter|OpenRouter (banyak model 1 key)|https://openrouter.ai/api/v1|OPENROUTER_API_KEY|openai/gpt-4o-mini|openai/gpt-4o-mini, anthropic/claude-3.5-sonnet"
    "gemini|Google Gemini|https://generativelanguage.googleapis.com/v1beta/openai|GEMINI_API_KEY|gemini-2.0-flash|gemini-2.0-flash, gemini-1.5-pro"
    "deepseek|DeepSeek (murah & pintar)|https://api.deepseek.com/v1|DEEPSEEK_API_KEY|deepseek-chat|deepseek-chat, deepseek-reasoner"
    "mistral|Mistral AI|https://api.mistral.ai/v1|MISTRAL_API_KEY|mistral-large-latest|mistral-large-latest, codestral-latest"
    "together|Together AI|https://api.together.xyz/v1|TOGETHER_API_KEY|meta-llama/Llama-3.3-70B-Instruct-Turbo|meta-llama/Llama-3.3-70B-Instruct-Turbo"
    "ollama|Ollama (lokal, gratis)|http://localhost:11434/v1|OLLAMA_API_KEY|llama3.2|llama3.2, qwen2.5-coder, deepseek-coder-v2"
    "9router|9Router (gateway lokal: 60+ provider sekaligus)|http://localhost:20128/v1|NINEROUTER_API_KEY|claude-sonnet-4|claude-sonnet-4, gpt-4o, gemini-2.0-flash, deepseek-chat"
    "custom|Custom OpenAI-compatible|||||"
)

provider_info() {
    # $1 = nama provider, $2 = field index (2=label, 3=base_url, 4=env_key, 5=model_default, 6=rekomendasi)
    local name="$1" idx="$2" entry
    for entry in "${PROVIDER_REGISTRY[@]}"; do
        IFS='|' read -ra parts <<< "${entry}"
        if [[ "${parts[0]}" == "${name}" ]]; then
            printf '%s' "${parts[$((idx-1))]}"
            return 0
        fi
    done
    return 1
}

list_provider_names() {
    local entry
    for entry in "${PROVIDER_REGISTRY[@]}"; do
        echo "${entry%%|*}"
    done
}

list_provider_labels() {
    local entry
    for entry in "${PROVIDER_REGISTRY[@]}"; do
        IFS='|' read -ra parts <<< "${entry}"
        echo "${parts[1]}"
    done
}

# =============================================================================
#  9ROUTER: AUTO-INSTALL & START
# =============================================================================
# 9Router (https://github.com/decolua/9router) adalah gateway lokal Node.js
# yang berjalan di port 20128 dan expose endpoint OpenAI-compatible. Dia
# meneruskan request Hermes ke 60+ provider asli dengan fallback otomatis.
ensure_9router_running() {
    log_step "Memeriksa instalasi 9Router..."

    # Cek apakah 9Router sudah jalan
    if curl -sS --max-time 3 "http://localhost:20128/v1/models" >/dev/null 2>&1 \
       || curl -sS --max-time 3 "http://localhost:20128/" >/dev/null 2>&1; then
        log_ok "9Router sudah berjalan di http://localhost:20128"
        log_hint "Dashboard: http://localhost:20128/dashboard"
        log_hint "Pastikan kamu sudah input API key provider asli (Claude/GPT/Gemini) di dashboard."
        return 0
    fi

    log_warn "9Router belum berjalan."

    # Cek Node.js
    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        log_warn "Node.js / npm belum terpasang."
        if prompt_yes_no "Pasang Node.js 22 LTS sekarang?" "y"; then
            install_nodejs_lts || { log_err "Gagal install Node.js."; return 1; }
        else
            log_hint "Install manual: https://nodejs.org → lalu 'npm install -g 9router'"
            return 1
        fi
    fi

    # Cek apakah paket 9router sudah ter-install via npm
    if ! command -v 9router >/dev/null 2>&1 && ! npm list -g 9router >/dev/null 2>&1; then
        if prompt_yes_no "Pasang 9Router via 'npm install -g 9router'?" "y"; then
            log_info "Menjalankan: npm install -g 9router"
            if npm install -g 9router 2>&1 | tee -a "${LOG_FILE}"; then
                log_ok "9Router ter-install."
            else
                log_err "Gagal install 9Router via npm."
                log_hint "Coba manual: sudo npm install -g 9router"
                return 1
            fi
        else
            return 1
        fi
    else
        log_ok "Paket 9Router sudah ter-install via npm."
    fi

    # Jalankan 9Router di background
    if prompt_yes_no "Jalankan 9Router di background sekarang?" "y"; then
        local nrlog="${HERMES_DIR}/9router.log"
        local nrpid="${HERMES_DIR}/9router.pid"
        if [[ -f "${nrpid}" ]] && kill -0 "$(cat "${nrpid}")" 2>/dev/null; then
            log_info "9Router sudah berjalan (PID $(cat "${nrpid}"))."
        else
            nohup 9router > "${nrlog}" 2>&1 &
            echo $! > "${nrpid}"
            log_info "9Router dijalankan (PID $(cat "${nrpid}")). Menunggu siap..."
            local i
            for i in 1 2 3 4 5 6 7 8 9 10; do
                sleep 1
                if curl -sS --max-time 2 "http://localhost:20128/" >/dev/null 2>&1; then
                    log_ok "9Router siap di http://localhost:20128"
                    break
                fi
                printf "."
            done
            echo
            log_hint "Log 9Router: ${nrlog}"
        fi
    fi

    echo
    log_warn "PENTING: Sebelum dipakai, kamu harus input API key provider asli"
    log_warn "(Claude, OpenAI, Gemini, dll.) di dashboard 9Router:"
    echo -e "    ${C_BOLD}${C_CYAN}http://localhost:20128/dashboard${C_RESET}"
    echo
    if prompt_yes_no "Sudah input API key provider di dashboard 9Router?" "n"; then
        return 0
    fi
    log_warn "Buka dashboard dulu, lalu kembali ke sini untuk lanjut."
    press_enter
}

install_nodejs_lts() {
    local SUDO=""
    [[ "${EUID}" -ne 0 ]] && SUDO="sudo"
    if command -v apt-get >/dev/null 2>&1; then
        log_info "Memasang Node.js 22 LTS via NodeSource..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | ${SUDO} -E bash - 2>&1 | tee -a "${LOG_FILE}"
        ${SUDO} apt-get install -y nodejs 2>&1 | tee -a "${LOG_FILE}"
    elif command -v dnf >/dev/null 2>&1; then
        ${SUDO} dnf module install -y nodejs:22/common
    elif command -v pacman >/dev/null 2>&1; then
        ${SUDO} pacman -Sy --noconfirm nodejs npm
    elif command -v brew >/dev/null 2>&1; then
        brew install node@22
    else
        log_err "Package manager tidak dikenal. Install Node.js manual."
        return 1
    fi
    command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
}

# =============================================================================
#  ENV FILE: BACA / TULIS KEY
# =============================================================================
env_get() {
    # $1 = nama key
    local key="$1"
    [[ -f "${ENV_FILE}" ]] || return 1
    local line
    line=$(grep -E "^${key}=" "${ENV_FILE}" | tail -n1 || true)
    [[ -n "${line}" ]] && echo "${line#*=}"
}

env_set() {
    # $1 = key, $2 = value
    local key="$1" value="$2"
    local tmp
    tmp=$(mktemp)
    if [[ -f "${ENV_FILE}" ]]; then
        grep -v -E "^${key}=" "${ENV_FILE}" > "${tmp}" || true
    fi
    echo "${key}=${value}" >> "${tmp}"
    mv "${tmp}" "${ENV_FILE}"
    chmod 600 "${ENV_FILE}"
}

env_unset() {
    local key="$1"
    [[ -f "${ENV_FILE}" ]] || return 0
    local tmp
    tmp=$(mktemp)
    grep -v -E "^${key}=" "${ENV_FILE}" > "${tmp}" || true
    mv "${tmp}" "${ENV_FILE}"
    chmod 600 "${ENV_FILE}"
}

# =============================================================================
#  PROVIDERS.CONF: DAFTAR PROVIDER YANG SUDAH AKTIF
# =============================================================================
# Format tiap baris: nama|model
providers_active_add() {
    local name="$1" model="$2"
    touch "${PROVIDERS_FILE}"
    local tmp
    tmp=$(mktemp)
    grep -v -E "^${name}\|" "${PROVIDERS_FILE}" > "${tmp}" || true
    echo "${name}|${model}" >> "${tmp}"
    mv "${tmp}" "${PROVIDERS_FILE}"
}

providers_active_list() {
    [[ -f "${PROVIDERS_FILE}" ]] || return 0
    cat "${PROVIDERS_FILE}"
}

providers_active_remove() {
    local name="$1"
    [[ -f "${PROVIDERS_FILE}" ]] || return 0
    local tmp
    tmp=$(mktemp)
    grep -v -E "^${name}\|" "${PROVIDERS_FILE}" > "${tmp}" || true
    mv "${tmp}" "${PROVIDERS_FILE}"
}

# =============================================================================
#  CEK PRASYARAT OS
# =============================================================================
ensure_os_prereqs() {
    log_step "Memeriksa kebutuhan sistem..."
    local missing=()
    for cmd in curl git python3 jq; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing+=("${cmd}")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log_ok "Semua tool dasar sudah terpasang (curl, git, python3, jq)."
        return 0
    fi

    log_warn "Tool berikut belum terpasang: ${missing[*]}"
    if ! prompt_yes_no "Pasang otomatis sekarang?" "y"; then
        log_warn "Lewati instalasi prasyarat. Beberapa fitur mungkin tidak jalan."
        return 0
    fi

    local SUDO=""
    if [[ "${EUID}" -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else
            log_err "Butuh sudo untuk install paket OS."
            return 1
        fi
    fi

    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        ${SUDO} apt-get update -qq
        ${SUDO} apt-get install -y -qq \
            curl git ca-certificates python3 python3-venv python3-pip \
            build-essential jq
    elif command -v dnf >/dev/null 2>&1; then
        ${SUDO} dnf install -y curl git python3 python3-pip jq gcc make
    elif command -v pacman >/dev/null 2>&1; then
        ${SUDO} pacman -Sy --noconfirm curl git python python-pip jq base-devel
    elif command -v brew >/dev/null 2>&1; then
        brew install curl git python jq
    else
        log_err "Package manager tidak dikenal. Pasang manual: ${missing[*]}"
        return 1
    fi
    log_ok "Prasyarat OS terpasang."
}

# =============================================================================
#  LOKASI BINARY HERMES
# =============================================================================
HERMES_BIN=""
locate_hermes() {
    if command -v hermes >/dev/null 2>&1; then
        HERMES_BIN="$(command -v hermes)"
        return 0
    fi
    for c in "${HOME}/.local/bin/hermes" "${HOME}/.cargo/bin/hermes" "/usr/local/bin/hermes"; do
        if [[ -x "${c}" ]]; then HERMES_BIN="${c}"; return 0; fi
    done
    return 1
}

# =============================================================================
#  INSTALL HERMES VIA OFFICIAL ONE-LINER
# =============================================================================
install_hermes_official() {
    log_step "Memasang Hermes Agent (one-liner resmi Nous Research)..."
    if locate_hermes; then
        log_ok "Hermes sudah terpasang di: ${HERMES_BIN}"
        "${HERMES_BIN}" --version 2>/dev/null || true
        return 0
    fi

    log_info "Mengunduh & menjalankan installer resmi..."
    log_hint "Source: github.com/NousResearch/hermes-agent"

    set +e
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh \
        | bash 2>&1 | tee -a "${LOG_FILE}"
    local rc=${PIPESTATUS[0]}
    set -e

    if [[ ${rc} -ne 0 ]]; then
        log_err "Installer resmi gagal (kode: ${rc})."
        log_hint "Cek log: ${LOG_FILE}"
        log_hint "Atau coba manual: https://hermes-agent.nousresearch.com/docs/getting-started/installation"
        return 1
    fi

    export PATH="${HOME}/.local/bin:${PATH}"
    if ! locate_hermes; then
        log_warn "Hermes terinstal tapi belum ada di PATH."
        log_hint "Buka terminal baru atau jalankan: source ~/.bashrc"
        log_hint "Lalu jalankan ulang script ini."
        return 1
    fi

    log_ok "Hermes terpasang: ${HERMES_BIN}"
    "${HERMES_BIN}" --version 2>/dev/null || true
}

# =============================================================================
#  VERIFIKASI API KEY (test ping ke endpoint provider)
# =============================================================================
verify_api_key() {
    # $1 = base_url, $2 = api_key, $3 = model, $4 = nama provider (untuk pesan)
    local base_url="$1" key="$2" model="$3" name="$4"
    local body http resp_file
    resp_file=$(mktemp)

    log_info "Mencoba ping ke ${name} (${base_url})..."

    # Anthropic memakai header & format berbeda
    if [[ "${name}" == "anthropic" ]]; then
        http=$(curl -sS --max-time 15 -o "${resp_file}" -w "%{http_code}" \
            "${base_url}/messages" \
            -H "x-api-key: ${key}" \
            -H "anthropic-version: 2023-06-01" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"${model}\",\"max_tokens\":1,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}" \
            2>/dev/null || echo "000")
    elif [[ "${name}" == "ollama" ]]; then
        http=$(curl -sS --max-time 5 -o "${resp_file}" -w "%{http_code}" \
            "${base_url%/v1}/api/tags" 2>/dev/null || echo "000")
    elif [[ "${name}" == "9router" ]]; then
        # 9Router: cek dashboard dulu, kalau hidup berarti gateway aktif
        http=$(curl -sS --max-time 5 -o "${resp_file}" -w "%{http_code}" \
            "${base_url}/models" \
            -H "Authorization: Bearer ${key}" 2>/dev/null || echo "000")
        if [[ "${http}" == "404" ]] || [[ "${http}" == "000" ]]; then
            # Fallback: cek root dashboard
            http=$(curl -sS --max-time 3 -o "${resp_file}" -w "%{http_code}" \
                "${base_url%/v1}/" 2>/dev/null || echo "000")
        fi
    else
        http=$(curl -sS --max-time 15 -o "${resp_file}" -w "%{http_code}" \
            "${base_url}/chat/completions" \
            -H "Authorization: Bearer ${key}" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"ping\"}],\"max_tokens\":1}" \
            2>/dev/null || echo "000")
    fi

    case "${http}" in
        200|201)
            log_ok "Provider ${name} merespons dengan baik (HTTP ${http})."
            rm -f "${resp_file}"
            return 0
            ;;
        401|403)
            log_err "Provider ${name} menolak API key (HTTP ${http})."
            log_hint "Body: $(head -c 200 "${resp_file}")"
            rm -f "${resp_file}"
            return 1
            ;;
        404|400)
            log_warn "Provider ${name} merespons HTTP ${http}. Mungkin nama model salah."
            log_hint "Body: $(head -c 200 "${resp_file}")"
            rm -f "${resp_file}"
            return 2
            ;;
        429)
            log_warn "Rate limit (HTTP 429), tapi key kemungkinan valid."
            rm -f "${resp_file}"
            return 0
            ;;
        000)
            log_err "Tidak bisa terhubung ke ${base_url}. Cek koneksi internet."
            rm -f "${resp_file}"
            return 1
            ;;
        *)
            log_warn "Provider ${name} merespons HTTP ${http} (tidak terduga)."
            log_hint "Body: $(head -c 200 "${resp_file}")"
            rm -f "${resp_file}"
            return 2
            ;;
    esac
}

# =============================================================================
#  TULIS CONFIG.YAML BERDASARKAN PROVIDER AKTIF
# =============================================================================
write_config_yaml() {
    local primary_name="$1" primary_model="$2"
    log_info "Menulis ${CONFIG_FILE}..."

    if [[ -f "${CONFIG_FILE}" ]]; then
        local backup="${CONFIG_FILE}.bak.$(date +%s)"
        cp "${CONFIG_FILE}" "${backup}"
        log_hint "Backup config lama: ${backup}"
    fi

    {
        echo "# File ini dikelola otomatis oleh install.sh"
        echo "# Diubah pada $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        echo "provider: ${primary_name}"
        echo "model: ${primary_model}"
        echo
        echo "providers:"

        local entry name label base_url env_key
        while IFS='|' read -r pname pmodel; do
            [[ -z "${pname}" ]] && continue
            base_url=$(provider_info "${pname}" 3 || echo "")
            env_key=$(provider_info "${pname}" 4 || echo "")

            # Untuk custom, baca dari file khusus
            if [[ "${pname}" == "custom" ]]; then
                base_url=$(env_get "CUSTOM_BASE_URL" || echo "")
                env_key="CUSTOM_API_KEY"
            fi

            echo "  ${pname}:"
            if [[ "${pname}" == "anthropic" ]]; then
                echo "    type: anthropic"
            else
                echo "    type: openai_compatible"
            fi
            [[ -n "${base_url}" ]] && echo "    base_url: ${base_url}"
            [[ -n "${env_key}" ]]  && echo "    api_key_env: ${env_key}"
            echo "    model: ${pmodel}"
        done < <(providers_active_list)

        # Fallback chain
        if [[ -f "${FALLBACK_FILE}" ]] && [[ -s "${FALLBACK_FILE}" ]]; then
            echo
            echo "fallback:"
            while IFS= read -r fp; do
                [[ -z "${fp}" ]] && continue
                echo "  - ${fp}"
            done < "${FALLBACK_FILE}"
        fi
    } > "${CONFIG_FILE}"

    log_ok "Config tertulis."
}

# =============================================================================
#  AKSI MENU: SETUP WIZARD PERTAMA KALI
# =============================================================================
action_setup_wizard() {
    show_banner
    echo -e "${C_BOLD}${C_GREEN}═══ SETUP WIZARD PERTAMA KALI ═══${C_RESET}"
    echo
    echo -e "Wizard ini akan memandu kamu langkah demi langkah:"
    echo -e "  1. Memeriksa & memasang prasyarat sistem"
    echo -e "  2. Memasang Hermes Agent (resmi Nous Research)"
    echo -e "  3. Mengisi minimal 1 API key provider LLM"
    echo -e "  4. (Opsional) Setup Telegram Bot"
    echo -e "  5. (Opsional) Setup fallback antar provider"
    echo
    if ! prompt_yes_no "Lanjutkan setup?" "y"; then
        return 0
    fi

    ensure_os_prereqs
    install_hermes_official || { log_err "Gagal install Hermes. Cek log."; press_enter; return 1; }

    echo
    log_step "Tambah provider LLM pertama"
    echo -e "  ${C_DIM}Kamu wajib mengisi minimal SATU provider supaya Hermes bisa jalan.${C_RESET}"
    echo
    action_add_provider_inner || true

    # Tawarkan tambah provider lain
    while prompt_yes_no "Mau tambah provider lain (untuk fallback)?" "n"; do
        action_add_provider_inner || true
    done

    # Telegram
    echo
    if prompt_yes_no "Setup Telegram Bot sekarang?" "n"; then
        action_setup_telegram
    fi

    # Fallback
    local active_count
    active_count=$(providers_active_list | wc -l)
    if (( active_count > 1 )); then
        echo
        if prompt_yes_no "Atur urutan fallback antar provider sekarang?" "y"; then
            action_setup_fallback
        fi
    fi

    echo
    log_step "Setup selesai"
    log_ok "Hermes Agent siap digunakan."
    show_summary
    press_enter
}

# =============================================================================
#  AKSI MENU: TAMBAH PROVIDER (inner = bagian yang bisa dipakai berulang)
# =============================================================================
action_add_provider_inner() {
    # Tampilkan daftar provider
    local labels=()
    local names=()
    while IFS= read -r n; do names+=("${n}"); done < <(list_provider_names)
    while IFS= read -r l; do labels+=("${l}"); done < <(list_provider_labels)

    local idx
    idx=$(prompt_choice "Pilih provider yang ingin ditambah:" "${labels[@]}")
    local pname="${names[$((idx-1))]}"
    local plabel="${labels[$((idx-1))]}"

    echo
    log_info "Provider terpilih: ${C_BOLD}${plabel}${C_RESET}"

    local base_url env_key default_model rekomendasi
    base_url=$(provider_info "${pname}" 3)
    env_key=$(provider_info "${pname}" 4)
    default_model=$(provider_info "${pname}" 5)
    rekomendasi=$(provider_info "${pname}" 6)

    # Custom provider butuh input base_url & env_key
    if [[ "${pname}" == "custom" ]]; then
        base_url=$(prompt_required "Base URL" "https://api.example.com/v1")
        env_set "CUSTOM_BASE_URL" "${base_url}"
        env_key="CUSTOM_API_KEY"
        default_model=$(prompt_required "Nama model default")
    fi

    # Petunjuk daftar key
    echo
    case "${pname}" in
        openai)     log_hint "Daftar key: https://platform.openai.com/api-keys (format: sk-...)" ;;
        anthropic)  log_hint "Daftar key: https://console.anthropic.com/settings/keys (format: sk-ant-...)" ;;
        grok)       log_hint "Daftar key: https://console.x.ai/ (format: xai-...)" ;;
        groq)       log_hint "Daftar key: https://console.groq.com/keys (format: gsk_...)" ;;
        openrouter) log_hint "Daftar key: https://openrouter.ai/keys (format: sk-or-...)" ;;
        gemini)     log_hint "Daftar key: https://aistudio.google.com/apikey" ;;
        deepseek)   log_hint "Daftar key: https://platform.deepseek.com/api_keys (format: sk-...)" ;;
        mistral)    log_hint "Daftar key: https://console.mistral.ai/api-keys/" ;;
        together)   log_hint "Daftar key: https://api.together.ai/settings/api-keys" ;;
        ollama)     log_hint "Ollama jalan lokal — biasanya tidak butuh API key. Pastikan 'ollama serve' aktif." ;;
        9router)
            log_hint "9Router = gateway lokal yang me-routing ke 60+ provider (Claude, GPT, Gemini, dll.)"
            log_hint "Dashboard: http://localhost:20128/dashboard  ·  Web: https://9router.com"
            log_hint "Repo: https://github.com/decolua/9router"
            ensure_9router_running || true
            ;;
    esac

    local api_key
    if [[ "${pname}" == "ollama" ]]; then
        api_key=$(prompt_optional "API key (boleh kosong untuk Ollama lokal)" "ollama")
    elif [[ "${pname}" == "9router" ]]; then
        echo
        log_hint "9Router lokal biasanya TIDAK butuh API key (langsung pakai 'sk-9router-local')."
        log_hint "Tapi kalau kamu set master key di dashboard 9Router → tab Settings → API Auth,"
        log_hint "isi key itu di sini. Kalau tidak, biarkan default."
        api_key=$(prompt_optional "API key 9Router" "sk-9router-local")
    else
        api_key=$(prompt_secret "API key untuk ${plabel}")
        if [[ -z "${api_key}" ]]; then
            log_warn "API key kosong, batal menambah provider."
            return 1
        fi
    fi

    echo
    log_hint "Model rekomendasi: ${rekomendasi}"
    local model
    model=$(prompt_optional "Nama model" "${default_model}")

    # Verifikasi
    echo
    if prompt_yes_no "Tes koneksi ke ${plabel} sekarang?" "y"; then
        if ! verify_api_key "${base_url}" "${api_key}" "${model}" "${pname}"; then
            log_warn "Verifikasi gagal. Tetap simpan? (kamu bisa benerin nanti via menu)"
            if ! prompt_yes_no "Tetap simpan walau gagal verify?" "n"; then
                return 1
            fi
        fi
    fi

    # Simpan
    env_set "${env_key}" "${api_key}"
    providers_active_add "${pname}" "${model}"

    # Set sebagai primary jika belum ada primary
    local primary
    primary=$(env_get "HERMES_PRIMARY_PROVIDER" || echo "")
    if [[ -z "${primary}" ]]; then
        env_set "HERMES_PRIMARY_PROVIDER" "${pname}"
        env_set "HERMES_PRIMARY_MODEL" "${model}"
        log_info "Provider ini ditandai sebagai PRIMARY."
    else
        if prompt_yes_no "Jadikan ${plabel} sebagai provider utama (primary)?" "n"; then
            env_set "HERMES_PRIMARY_PROVIDER" "${pname}"
            env_set "HERMES_PRIMARY_MODEL" "${model}"
        fi
    fi

    # Tulis ulang config.yaml
    primary=$(env_get "HERMES_PRIMARY_PROVIDER")
    local primary_model
    primary_model=$(env_get "HERMES_PRIMARY_MODEL")
    write_config_yaml "${primary}" "${primary_model}"

    log_ok "Provider ${plabel} berhasil ditambahkan."
}

action_add_provider() {
    show_banner
    echo -e "${C_BOLD}${C_GREEN}═══ TAMBAH / UBAH PROVIDER LLM ═══${C_RESET}"
    echo
    action_add_provider_inner || true
    press_enter
}

# =============================================================================
#  AKSI MENU: SETUP TELEGRAM
# =============================================================================
action_setup_telegram() {
    show_banner
    echo -e "${C_BOLD}${C_GREEN}═══ SETUP TELEGRAM BOT ═══${C_RESET}"
    echo
    echo -e "Untuk pakai gateway Telegram kamu butuh 2 hal:"
    echo -e "  1. ${C_BOLD}Bot Token${C_RESET}  → chat ${C_CYAN}@BotFather${C_RESET} di Telegram, ketik /newbot"
    echo -e "  2. ${C_BOLD}Chat ID${C_RESET}    → chat ${C_CYAN}@userinfobot${C_RESET} untuk dapat angka Chat ID"
    echo

    local current_token current_chat
    current_token=$(env_get "TELEGRAM_BOT_TOKEN" || echo "")
    current_chat=$(env_get "TELEGRAM_CHAT_ID" || echo "")

    if [[ -n "${current_token}" ]]; then
        log_info "Telegram sudah pernah disetup sebelumnya."
        log_hint "Token saat ini: ${current_token:0:10}...${current_token: -4}"
        log_hint "Chat ID saat ini: ${current_chat}"
        echo
        if ! prompt_yes_no "Mau ganti dengan yang baru?" "n"; then
            press_enter
            return 0
        fi
    fi

    local token chat_id
    token=$(prompt_required "TELEGRAM BOT TOKEN" "format: 123456:AA...")
    chat_id=$(prompt_required "TELEGRAM CHAT ID" "angka, bisa diawali tanda minus")

    # Tes kirim
    if prompt_yes_no "Coba kirim pesan tes ke Telegram?" "y"; then
        log_info "Mengirim pesan tes..."
        local resp
        resp=$(curl -sS --max-time 10 \
            "https://api.telegram.org/bot${token}/sendMessage" \
            -d "chat_id=${chat_id}" \
            -d "text=Halo dari Hermes Installer! Kalau pesan ini sampai, setup Telegram kamu sukses." \
            2>/dev/null || echo "")
        if echo "${resp}" | grep -q '"ok":true'; then
            log_ok "Pesan tes terkirim! Cek Telegram kamu."
        else
            log_warn "Tes gagal. Respons: $(echo "${resp}" | head -c 200)"
            log_hint "Pastikan token & chat ID benar, dan kamu sudah /start bot-mu."
            if ! prompt_yes_no "Tetap simpan?" "y"; then
                return 1
            fi
        fi
    fi

    env_set "TELEGRAM_BOT_TOKEN" "${token}"
    env_set "TELEGRAM_CHAT_ID" "${chat_id}"
    log_ok "Telegram tersimpan di ${ENV_FILE}"
    press_enter
}

# =============================================================================
#  AKSI MENU: SETUP FALLBACK
# =============================================================================
action_setup_fallback() {
    show_banner
    echo -e "${C_BOLD}${C_GREEN}═══ ATUR FALLBACK PROVIDER ═══${C_RESET}"
    echo
    echo -e "Fallback artinya: kalau provider utama error/limit/down,"
    echo -e "Hermes otomatis pindah ke provider berikutnya di urutan."
    echo

    local active=()
    while IFS='|' read -r n m; do
        [[ -n "${n}" ]] && active+=("${n}|${m}")
    done < <(providers_active_list)

    if [[ ${#active[@]} -lt 2 ]]; then
        log_warn "Kamu baru punya ${#active[@]} provider. Tambah minimal 2 dulu."
        press_enter
        return 0
    fi

    echo -e "${C_BOLD}Provider yang sudah aktif:${C_RESET}"
    local i
    for i in "${!active[@]}"; do
        IFS='|' read -r n m <<< "${active[$i]}"
        printf "  ${C_CYAN}%2d)${C_RESET} %s ${C_DIM}(%s)${C_RESET}\n" "$((i+1))" "${n}" "${m}"
    done
    echo
    echo -e "Masukkan urutan fallback berupa nomor dipisahkan koma."
    echo -e "Contoh: ${C_CYAN}1,3,2${C_RESET}  artinya provider 1 utama, jika gagal ke 3, terakhir ke 2."
    echo

    local order
    order=$(prompt_required "Urutan fallback")

    > "${FALLBACK_FILE}"
    IFS=',' read -ra parts <<< "${order}"
    local first=""
    for p in "${parts[@]}"; do
        p="${p// }"
        if [[ "${p}" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= ${#active[@]} )); then
            IFS='|' read -r n m <<< "${active[$((p-1))]}"
            echo "${n}" >> "${FALLBACK_FILE}"
            [[ -z "${first}" ]] && first="${n}"
            log_hint "→ ${n}"
        fi
    done

    if [[ -n "${first}" ]]; then
        local m
        m=$(grep -E "^${first}\|" "${PROVIDERS_FILE}" | head -n1 | cut -d'|' -f2)
        env_set "HERMES_PRIMARY_PROVIDER" "${first}"
        env_set "HERMES_PRIMARY_MODEL" "${m}"
        write_config_yaml "${first}" "${m}"
        log_ok "Fallback chain tersimpan. Provider utama: ${first}"
    fi
    press_enter
}

# =============================================================================
#  AKSI MENU: TAMBAH SKILL
# =============================================================================
action_add_skill() {
    show_banner
    echo -e "${C_BOLD}${C_GREEN}═══ TAMBAH SKILL HERMES ═══${C_RESET}"
    echo
    echo -e "Skill = kemampuan tambahan untuk Hermes (mis. Telegram gateway,"
    echo -e "scrape web, integrasi DB, dll). Bisa berupa:"
    echo
    echo -e "  ${C_CYAN}1)${C_RESET} Skill bawaan Hermes (via 'hermes skill add ...')"
    echo -e "  ${C_CYAN}2)${C_RESET} Skill dari URL Git repo (clone ke ~/.hermes/skills/)"
    echo -e "  ${C_CYAN}3)${C_RESET} Skill kustom kosong (bikin folder + template)"
    echo -e "  ${C_CYAN}4)${C_RESET} Lihat skill yang sudah terpasang"
    echo -e "  ${C_CYAN}5)${C_RESET} Kembali ke menu"
    echo

    local choice
    printf "  ${C_YELLOW}?${C_RESET} Pilih [1-5]: "
    IFS= read -r choice </dev/tty || choice=""
    case "${choice}" in
        1)
            if ! locate_hermes; then
                log_err "Hermes belum terpasang. Lakukan setup wizard dulu."
                press_enter; return 1
            fi
            local sname
            sname=$(prompt_required "Nama skill bawaan" "mis. telegram, web-search, mcp-server")
            log_info "Menjalankan: hermes skill add ${sname}"
            "${HERMES_BIN}" skill add "${sname}" 2>&1 | tee -a "${LOG_FILE}" || \
                log_warn "Perintah gagal — mungkin skill name tidak ada. Cek 'hermes skill list'."
            ;;
        2)
            local repo
            repo=$(prompt_required "URL Git repo skill" "https://github.com/...")
            local dest
            dest="${SKILLS_DIR}/$(basename "${repo}" .git)"
            if [[ -d "${dest}" ]]; then
                log_warn "Folder ${dest} sudah ada."
                if prompt_yes_no "Overwrite (rm -rf lalu clone ulang)?" "n"; then
                    rm -rf "${dest}"
                else
                    return 0
                fi
            fi
            log_info "Cloning ${repo} → ${dest}"
            git clone --depth 1 "${repo}" "${dest}" || { log_err "Gagal clone."; press_enter; return 1; }
            log_ok "Skill terpasang di ${dest}"
            log_hint "Baca README di folder skill untuk cara aktivasi."
            ;;
        3)
            local sname dest
            sname=$(prompt_required "Nama skill kustom (huruf kecil, tanpa spasi)")
            dest="${SKILLS_DIR}/${sname}"
            mkdir -p "${dest}"
            cat > "${dest}/skill.yaml" <<EOF
# Skill kustom: ${sname}
name: ${sname}
version: 0.1.0
description: Tulis deskripsi skill kamu di sini
entrypoint: ./run.sh
EOF
            cat > "${dest}/run.sh" <<'EOF'
#!/usr/bin/env bash
# Skill entrypoint - ganti dengan logikamu sendiri
echo "Halo dari skill kustom!"
EOF
            chmod +x "${dest}/run.sh"
            log_ok "Template skill kosong dibuat di ${dest}"
            log_hint "Edit skill.yaml & run.sh sesuai kebutuhan kamu."
            ;;
        4)
            echo
            echo -e "${C_BOLD}Skill di ${SKILLS_DIR}:${C_RESET}"
            if [[ -d "${SKILLS_DIR}" ]] && [[ -n "$(ls -A "${SKILLS_DIR}" 2>/dev/null)" ]]; then
                ls -1 "${SKILLS_DIR}" | sed 's/^/  • /'
            else
                echo -e "  ${C_DIM}(belum ada skill terpasang)${C_RESET}"
            fi
            if locate_hermes; then
                echo
                echo -e "${C_BOLD}Skill terdaftar di Hermes:${C_RESET}"
                "${HERMES_BIN}" skill list 2>/dev/null || echo -e "  ${C_DIM}(perintah 'hermes skill list' tidak tersedia)${C_RESET}"
            fi
            ;;
        5|*) return 0 ;;
    esac
    press_enter
}

# =============================================================================
#  AKSI MENU: UBAH KEPRIBADIAN AGENT (SOUL.md)
# =============================================================================
# SOUL.md adalah file Markdown di ~/.hermes/SOUL.md yang menjadi system prompt
# layer pertama untuk Hermes. Mengubah file ini = mengubah identitas, gaya
# bicara, keahlian, dan aturan perilaku agent.
# Ref: https://hermes-agent.nousresearch.com/docs/user-guide/features/personality

soul_preset_default() {
    cat <<'EOF'
# Identitas

Kamu adalah Hermes, asisten AI yang dibuat oleh Nous Research.
Kamu adalah software engineer dan researcher yang ahli.
Kamu menghargai ketepatan, kejelasan, dan efisiensi.

## Gaya bicara

- Jelaskan dengan ringkas dan langsung ke poin
- Pakai contoh kode kalau relevan
- Akui ketidaktahuan dengan jujur — jangan mengarang

## Keahlian

- Software engineering (semua bahasa populer)
- DevOps & infrastructure
- Riset teknologi & analisis arsitektur

## Aturan

- Selalu konfirmasi sebelum menjalankan perintah destruktif
- Jelaskan dampak command sebelum eksekusi
EOF
}

soul_preset_indo_friendly() {
    cat <<'EOF'
# Identitas

Kamu adalah Budi, asisten AI berbahasa Indonesia yang ramah dan sopan.
Kamu seperti teman dekat yang juga jago programming.

## Gaya bicara

- Selalu pakai Bahasa Indonesia, kecuali user pakai bahasa lain
- Panggil user dengan "Kak" atau sesuai nama yang user kasih
- Pakai emoji secukupnya supaya akrab (jangan berlebihan)
- Sertakan analogi sederhana untuk konsep teknis
- Kalau tidak yakin, jujur bilang "Wah, ini saya kurang paham, Kak"

## Keahlian

- Programming (Python, JavaScript, Go, Bash)
- Sysadmin Linux & DevOps
- Menjelaskan hal teknis ke pemula dengan bahasa awam
- Debugging error dengan sabar

## Aturan

- JANGAN PERNAH jalankan perintah destruktif (rm -rf, dd, mkfs) tanpa konfirmasi user
- Selalu jelaskan dampak setiap command sebelum eksekusi
- Hindari jargon teknis kalau bisa pakai bahasa awam
- Pertanyakan asumsi user yang sepertinya keliru, dengan sopan
EOF
}

soul_preset_indo_pro() {
    cat <<'EOF'
# Identitas

Kamu adalah Hermes, senior engineer Indonesia yang langsung-ke-poin.
Kamu nggak suka basa-basi panjang. Profesional tapi tetap manusiawi.

## Gaya bicara

- Bahasa Indonesia formal-santai (campur kata Inggris untuk istilah teknis OK)
- Tidak pakai sapaan berlebihan, langsung ke solusi
- Jawab dalam poin-poin kalau bisa
- Berikan trade-off & alternatif kalau ada keputusan teknis

## Keahlian

- Architecture design (microservices, monolith, event-driven)
- Production debugging & incident response
- Security & best practices
- Code review yang tegas tapi konstruktif

## Aturan

- Tidak menulis kode yang belum kamu pahami sepenuhnya
- Selalu sebut asumsi-mu di awal
- Tunjukkan trade-off kalau memilih satu pendekatan
- Hindari over-engineering — pilih solusi paling sederhana yang berfungsi
EOF
}

soul_preset_devops_strict() {
    cat <<'EOF'
# Identitas

Kamu adalah DevOps SRE expert yang ketat soal keamanan & reliability.
Setiap perintah dianggap berpotensi production-impacting kecuali terbukti sebaliknya.

## Gaya bicara

- Tegas, lugas, no-nonsense
- Selalu jelaskan blast radius setiap action
- Sertakan rollback plan untuk perubahan signifikan

## Keahlian

- Linux sysadmin (systemd, networking, security)
- Container & orchestration (Docker, Kubernetes)
- CI/CD pipeline & GitOps
- Monitoring, alerting, incident response

## Aturan WAJIB

- WAJIB konfirmasi 2x untuk: rm -rf, dd, mkfs, drop database, force push, sudo destructive ops
- WAJIB suggest dry-run mode dulu kalau tool-nya support
- WAJIB cek backup sebelum modifikasi data persisten
- DILARANG menjalankan command yang user belum review
- DILARANG mengubah file di /etc/ tanpa show diff dulu
EOF
}

soul_preset_creative_writer() {
    cat <<'EOF'
# Identitas

Kamu adalah Hermes, asisten kreatif yang membantu menulis konten,
brainstorm ide, dan menyusun narasi yang menarik dalam Bahasa Indonesia.

## Gaya bicara

- Hangat, imajinatif, suportif
- Pakai analogi dan metafora untuk menjelaskan
- Tawarkan beberapa alternatif untuk setiap tugas kreatif
- Ajukan pertanyaan klarifikasi kalau brief-nya ambigu

## Keahlian

- Copywriting (marketing, social media, email)
- Storytelling & worldbuilding
- Editing & proofreading Bahasa Indonesia
- Brainstorm ide konten

## Aturan

- Jaga orisinalitas — jangan pernah menjiplak
- Sebut sumber kalau pakai data atau kutipan eksternal
- Jelaskan tone & target audience yang kamu asumsikan
EOF
}

action_personality() {
    show_banner
    echo -e "${C_BOLD}${C_GREEN}═══ UBAH KEPRIBADIAN AGENT (SOUL.md) ═══${C_RESET}"
    echo
    echo -e "Kepribadian Hermes diatur lewat file ${C_BOLD}~/.hermes/SOUL.md${C_RESET}."
    echo -e "Isinya jadi system prompt LAYER PERTAMA — paling berpengaruh"
    echo -e "ke gaya bicara, keahlian, dan aturan perilaku agent."
    echo
    log_hint "Lokasi: ${SOUL_FILE}"
    if [[ -f "${SOUL_FILE}" ]]; then
        local size_lines
        size_lines=$(wc -l < "${SOUL_FILE}" 2>/dev/null || echo 0)
        log_ok "File saat ini sudah ada (${size_lines} baris)."
    else
        log_warn "File belum ada — Hermes pakai default identity."
    fi
    echo
    echo -e "  ${C_CYAN}1)${C_RESET} ${C_BOLD}Pilih dari preset siap pakai${C_RESET}"
    echo -e "  ${C_CYAN}2)${C_RESET} Edit manual (pakai \$EDITOR / nano / vi)"
    echo -e "  ${C_CYAN}3)${C_RESET} Lihat isi SOUL.md saat ini"
    echo -e "  ${C_CYAN}4)${C_RESET} Backup SOUL.md saat ini"
    echo -e "  ${C_CYAN}5)${C_RESET} ${C_RED}Hapus SOUL.md (kembali ke default Hermes)${C_RESET}"
    echo -e "  ${C_CYAN}6)${C_RESET} Kembali ke menu"
    echo

    local choice
    printf "  ${C_YELLOW}?${C_RESET} Pilih [1-6]: "
    IFS= read -r choice </dev/tty || choice=""

    case "${choice}" in
        1) personality_choose_preset ;;
        2) personality_edit_manual ;;
        3) personality_show ;;
        4) personality_backup ;;
        5) personality_delete ;;
        6|*) return 0 ;;
    esac
    press_enter
}

personality_choose_preset() {
    echo
    local idx
    idx=$(prompt_choice "Pilih preset kepribadian:" \
        "Default Hermes (English, technical)" \
        "Budi - Asisten Indonesia ramah & sopan" \
        "Hermes ID Pro - Senior engineer langsung-ke-poin" \
        "DevOps Strict - SRE ketat soal keamanan" \
        "Creative Writer - Asisten kreatif Bahasa Indonesia")

    # Backup dulu kalau sudah ada
    if [[ -f "${SOUL_FILE}" ]]; then
        local bak="${SOUL_FILE}.bak.$(date +%s)"
        cp "${SOUL_FILE}" "${bak}"
        log_hint "Backup file lama: ${bak}"
    fi

    case "${idx}" in
        1) soul_preset_default        > "${SOUL_FILE}" ;;
        2) soul_preset_indo_friendly  > "${SOUL_FILE}" ;;
        3) soul_preset_indo_pro       > "${SOUL_FILE}" ;;
        4) soul_preset_devops_strict  > "${SOUL_FILE}" ;;
        5) soul_preset_creative_writer > "${SOUL_FILE}" ;;
    esac

    log_ok "SOUL.md tertulis ke ${SOUL_FILE}"
    log_hint "Preview 10 baris pertama:"
    echo -e "${C_DIM}"
    head -n 10 "${SOUL_FILE}" | sed 's/^/    /'
    echo -e "${C_RESET}"
    log_hint "Restart sesi Hermes (atau buka chat baru) untuk pakai persona ini."

    if prompt_yes_no "Mau langsung edit lagi (custom)?" "n"; then
        personality_edit_manual
    fi
}

personality_edit_manual() {
    # Buat file dulu kalau belum ada
    if [[ ! -f "${SOUL_FILE}" ]]; then
        log_info "File belum ada — buat baru dengan template default."
        soul_preset_default > "${SOUL_FILE}"
    fi

    local editor="${EDITOR:-}"
    if [[ -z "${editor}" ]]; then
        for cand in nano vim vi micro; do
            if command -v "${cand}" >/dev/null 2>&1; then
                editor="${cand}"
                break
            fi
        done
    fi

    if [[ -z "${editor}" ]]; then
        log_err "Tidak ada editor yang tersedia (\$EDITOR/nano/vim/vi/micro)."
        log_hint "Edit manual: ${SOUL_FILE}"
        return 1
    fi

    log_info "Membuka editor '${editor}' untuk ${SOUL_FILE}..."
    log_hint "Save & quit kalau sudah selesai. Untuk nano: Ctrl+O lalu Ctrl+X."
    sleep 1
    "${editor}" "${SOUL_FILE}" </dev/tty
    log_ok "SOUL.md disimpan."
    log_hint "Restart sesi Hermes untuk pakai persona baru."
}

personality_show() {
    echo
    if [[ ! -f "${SOUL_FILE}" ]]; then
        log_warn "SOUL.md belum ada. Hermes pakai default identity."
        log_hint "Pakai opsi 1 untuk mulai dari preset, atau opsi 2 untuk bikin manual."
        return 0
    fi
    hr
    echo -e "${C_BOLD}Isi ${SOUL_FILE}:${C_RESET}"
    hr
    cat "${SOUL_FILE}"
    hr
}

personality_backup() {
    if [[ ! -f "${SOUL_FILE}" ]]; then
        log_warn "Tidak ada SOUL.md untuk di-backup."
        return 0
    fi
    local bak="${SOUL_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "${SOUL_FILE}" "${bak}"
    log_ok "Backup tersimpan: ${bak}"
}

personality_delete() {
    if [[ ! -f "${SOUL_FILE}" ]]; then
        log_warn "Tidak ada SOUL.md untuk dihapus."
        return 0
    fi
    if ! prompt_yes_no "Yakin hapus SOUL.md (Hermes balik ke default identity)?" "n"; then
        log_info "Dibatalkan."
        return 0
    fi
    local bak="${SOUL_FILE}.deleted.$(date +%s)"
    mv "${SOUL_FILE}" "${bak}"
    log_ok "SOUL.md dihapus (disimpan sebagai ${bak} buat jaga-jaga)."
    log_hint "Restart Hermes — sekarang pakai default identity."
}

# =============================================================================
#  AKSI MENU: JALANKAN GATEWAY (Telegram)
# =============================================================================
action_run_gateway() {
    show_banner
    echo -e "${C_BOLD}${C_GREEN}═══ JALANKAN GATEWAY ═══${C_RESET}"
    echo

    local token chat
    token=$(env_get "TELEGRAM_BOT_TOKEN" || echo "")
    chat=$(env_get "TELEGRAM_CHAT_ID" || echo "")

    if [[ -z "${token}" ]]; then
        log_warn "Telegram belum disetup. Setup dulu lewat menu."
        press_enter; return 1
    fi

    if ! locate_hermes; then
        log_err "Hermes belum terpasang. Jalankan setup wizard dulu."
        press_enter; return 1
    fi

    echo -e "  ${C_BOLD}Bot Token :${C_RESET} ${token:0:10}...${token: -4}"
    echo -e "  ${C_BOLD}Chat ID   :${C_RESET} ${chat}"
    echo
    echo -e "Pilih cara jalankan gateway:"
    echo -e "  ${C_CYAN}1)${C_RESET} Foreground (interaktif, log ke layar)"
    echo -e "  ${C_CYAN}2)${C_RESET} Background (nohup, log ke ~/.hermes/gateway.log)"
    echo -e "  ${C_CYAN}3)${C_RESET} Sebagai service systemd (perlu sudo, persistent)"
    echo -e "  ${C_CYAN}4)${C_RESET} Stop gateway yang sedang jalan"
    echo -e "  ${C_CYAN}5)${C_RESET} Cek status gateway"
    echo -e "  ${C_CYAN}6)${C_RESET} Kembali"
    echo

    local choice
    printf "  ${C_YELLOW}?${C_RESET} Pilih [1-6]: "
    IFS= read -r choice </dev/tty || choice=""

    # Set env supaya child process Hermes bisa baca
    set -a
    # shellcheck source=/dev/null
    [[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"
    set +a

    case "${choice}" in
        1)
            log_info "Menjalankan gateway di foreground. Tekan Ctrl+C untuk berhenti."
            "${HERMES_BIN}" gateway start --channel telegram 2>&1 | tee -a "${LOG_FILE}" || \
                log_warn "Perintah gateway gagal. Versi Hermes mungkin pakai sintaks lain."
            ;;
        2)
            local pidfile="${HERMES_DIR}/gateway.pid"
            local logfile="${HERMES_DIR}/gateway.log"
            if [[ -f "${pidfile}" ]] && kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
                log_warn "Gateway sudah jalan (PID $(cat "${pidfile}"))."
            else
                nohup "${HERMES_BIN}" gateway start --channel telegram > "${logfile}" 2>&1 &
                echo $! > "${pidfile}"
                log_ok "Gateway dijalankan di background (PID $(cat "${pidfile}"))."
                log_hint "Lihat log: tail -f ${logfile}"
            fi
            ;;
        3)
            create_systemd_service
            ;;
        4)
            local pidfile="${HERMES_DIR}/gateway.pid"
            if [[ -f "${pidfile}" ]] && kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
                kill "$(cat "${pidfile}")" && rm -f "${pidfile}"
                log_ok "Gateway dihentikan."
            else
                log_warn "Tidak ada gateway aktif (atau dijalankan via systemd)."
                log_hint "Untuk systemd: sudo systemctl stop hermes-gateway"
            fi
            ;;
        5)
            local pidfile="${HERMES_DIR}/gateway.pid"
            if [[ -f "${pidfile}" ]] && kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
                log_ok "Gateway aktif (PID $(cat "${pidfile}"))."
            else
                log_warn "Gateway TIDAK aktif (background)."
            fi
            if command -v systemctl >/dev/null 2>&1; then
                if systemctl is-active --quiet hermes-gateway 2>/dev/null; then
                    log_ok "Service systemd hermes-gateway: AKTIF"
                else
                    log_hint "Service systemd hermes-gateway: tidak aktif/ tidak terpasang"
                fi
            fi
            ;;
        *) return 0 ;;
    esac
    press_enter
}

create_systemd_service() {
    if ! command -v systemctl >/dev/null 2>&1; then
        log_err "systemd tidak tersedia di sistem ini."
        return 1
    fi
    local SUDO=""
    [[ "${EUID}" -ne 0 ]] && SUDO="sudo"

    local service_file="/etc/systemd/system/hermes-gateway.service"
    log_info "Membuat ${service_file}..."

    ${SUDO} tee "${service_file}" >/dev/null <<EOF
[Unit]
Description=Hermes Agent Telegram Gateway
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${HOME}
EnvironmentFile=${ENV_FILE}
ExecStart=${HERMES_BIN} gateway start --channel telegram
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    ${SUDO} systemctl daemon-reload
    ${SUDO} systemctl enable --now hermes-gateway
    log_ok "Service hermes-gateway aktif & auto-start saat reboot."
    log_hint "Cek status : sudo systemctl status hermes-gateway"
    log_hint "Lihat log  : sudo journalctl -u hermes-gateway -f"
    log_hint "Stop       : sudo systemctl stop hermes-gateway"
}

# =============================================================================
#  AKSI MENU: CEK INFO / STATUS
# =============================================================================
show_summary() {
    hr
    echo -e "${C_BOLD}${C_CYAN}RINGKASAN KONFIGURASI HERMES${C_RESET}"
    hr

    if locate_hermes; then
        echo -e "  ${C_BOLD}Binary    :${C_RESET} ${C_GREEN}${HERMES_BIN}${C_RESET}"
        local ver
        ver=$("${HERMES_BIN}" --version 2>/dev/null | head -n1 || echo "tidak diketahui")
        echo -e "  ${C_BOLD}Versi     :${C_RESET} ${ver}"
    else
        echo -e "  ${C_BOLD}Binary    :${C_RESET} ${C_RED}belum terpasang${C_RESET}"
    fi

    echo -e "  ${C_BOLD}Folder    :${C_RESET} ${HERMES_DIR}"
    echo -e "  ${C_BOLD}Env file  :${C_RESET} ${ENV_FILE} $(test -f "${ENV_FILE}" && echo "${C_GREEN}(ada)${C_RESET}" || echo "${C_RED}(tidak ada)${C_RESET}")"
    echo -e "  ${C_BOLD}Config    :${C_RESET} ${CONFIG_FILE} $(test -f "${CONFIG_FILE}" && echo "${C_GREEN}(ada)${C_RESET}" || echo "${C_RED}(tidak ada)${C_RESET}")"

    local primary primary_model
    primary=$(env_get "HERMES_PRIMARY_PROVIDER" || echo "")
    primary_model=$(env_get "HERMES_PRIMARY_MODEL" || echo "")
    if [[ -n "${primary}" ]]; then
        echo -e "  ${C_BOLD}Primary   :${C_RESET} ${C_GREEN}${primary}${C_RESET} ${C_DIM}(${primary_model})${C_RESET}"
    else
        echo -e "  ${C_BOLD}Primary   :${C_RESET} ${C_YELLOW}belum ditentukan${C_RESET}"
    fi

    echo
    echo -e "${C_BOLD}Provider aktif:${C_RESET}"
    if [[ -f "${PROVIDERS_FILE}" ]] && [[ -s "${PROVIDERS_FILE}" ]]; then
        while IFS='|' read -r n m; do
            [[ -z "${n}" ]] && continue
            printf "  ${C_GREEN}✓${C_RESET} %-12s ${C_DIM}→ %s${C_RESET}\n" "${n}" "${m}"
        done < "${PROVIDERS_FILE}"
    else
        echo -e "  ${C_DIM}(belum ada)${C_RESET}"
    fi

    echo
    echo -e "${C_BOLD}Urutan fallback:${C_RESET}"
    if [[ -f "${FALLBACK_FILE}" ]] && [[ -s "${FALLBACK_FILE}" ]]; then
        local i=1
        while IFS= read -r p; do
            [[ -z "${p}" ]] && continue
            printf "  %d. %s\n" "${i}" "${p}"
            ((i++))
        done < "${FALLBACK_FILE}"
    else
        echo -e "  ${C_DIM}(tidak ada — pakai primary saja)${C_RESET}"
    fi

    echo
    echo -e "${C_BOLD}Telegram:${C_RESET}"
    local tg_token tg_chat
    tg_token=$(env_get "TELEGRAM_BOT_TOKEN" || echo "")
    tg_chat=$(env_get "TELEGRAM_CHAT_ID" || echo "")
    if [[ -n "${tg_token}" ]]; then
        echo -e "  ${C_GREEN}✓${C_RESET} Token   : ${tg_token:0:10}...${tg_token: -4}"
        echo -e "  ${C_GREEN}✓${C_RESET} Chat ID : ${tg_chat}"
    else
        echo -e "  ${C_DIM}(belum disetup)${C_RESET}"
    fi

    echo
    echo -e "${C_BOLD}Kepribadian (SOUL.md):${C_RESET}"
    if [[ -f "${SOUL_FILE}" ]]; then
        local soul_lines first_line
        soul_lines=$(wc -l < "${SOUL_FILE}" 2>/dev/null || echo 0)
        first_line=$(grep -m1 -v '^[[:space:]]*$' "${SOUL_FILE}" 2>/dev/null | head -c 60 || echo "")
        echo -e "  ${C_GREEN}✓${C_RESET} Custom (${soul_lines} baris)"
        [[ -n "${first_line}" ]] && echo -e "    ${C_DIM}↳ ${first_line}...${C_RESET}"
    else
        echo -e "  ${C_DIM}(default Hermes — belum dikustomisasi)${C_RESET}"
    fi

    echo
    echo -e "${C_BOLD}Skill terpasang:${C_RESET}"
    if [[ -d "${SKILLS_DIR}" ]] && [[ -n "$(ls -A "${SKILLS_DIR}" 2>/dev/null)" ]]; then
        ls -1 "${SKILLS_DIR}" | sed 's/^/  • /'
    else
        echo -e "  ${C_DIM}(belum ada)${C_RESET}"
    fi
    hr
}

action_show_info() {
    show_banner
    show_summary
    echo
    echo -e "${C_BOLD}Perintah berguna:${C_RESET}"
    echo -e "  ${C_CYAN}hermes \"halo\"${C_RESET}              tes prompt cepat"
    echo -e "  ${C_CYAN}hermes --help${C_RESET}              lihat semua perintah"
    echo -e "  ${C_CYAN}cat ${ENV_FILE}${C_RESET}    lihat secrets"
    echo -e "  ${C_CYAN}cat ${CONFIG_FILE}${C_RESET}  lihat config"
    press_enter
}

# =============================================================================
#  AKSI MENU: UPDATE
# =============================================================================
action_update() {
    show_banner
    echo -e "${C_BOLD}${C_GREEN}═══ UPDATE HERMES AGENT ═══${C_RESET}"
    echo

    if ! locate_hermes; then
        log_err "Hermes belum terpasang. Lakukan setup wizard dulu."
        press_enter; return 1
    fi

    log_info "Mencoba 'hermes update'..."
    set +e
    "${HERMES_BIN}" update 2>&1 | tee -a "${LOG_FILE}"
    local rc=${PIPESTATUS[0]}
    set -e

    if [[ ${rc} -ne 0 ]]; then
        log_warn "'hermes update' gagal/tidak tersedia. Mencoba reinstall via one-liner..."
        if prompt_yes_no "Jalankan ulang installer resmi (akan timpa binary)?" "y"; then
            curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh \
                | bash 2>&1 | tee -a "${LOG_FILE}"
        fi
    else
        log_ok "Update selesai."
    fi
    "${HERMES_BIN}" --version 2>/dev/null || true
    press_enter
}

# =============================================================================
#  AKSI MENU: RESET
# =============================================================================
action_reset() {
    show_banner
    echo -e "${C_BOLD}${C_RED}═══ RESET / HAPUS KONFIGURASI ═══${C_RESET}"
    echo
    log_warn "AKSI INI BERBAHAYA. Akan menghapus:"
    echo -e "  • ${ENV_FILE} (semua API key & secrets)"
    echo -e "  • ${CONFIG_FILE}"
    echo -e "  • ${PROVIDERS_FILE}"
    echo -e "  • ${FALLBACK_FILE}"
    echo
    echo -e "Tidak menghapus: binary hermes, folder skills/."
    echo
    if ! prompt_yes_no "Yakin mau RESET semua konfigurasi?" "n"; then
        log_info "Dibatalkan."
        press_enter; return 0
    fi
    local confirm
    confirm=$(prompt_required "Ketik HAPUS untuk konfirmasi")
    if [[ "${confirm}" != "HAPUS" ]]; then
        log_info "Konfirmasi tidak cocok. Dibatalkan."
        press_enter; return 0
    fi

    rm -f "${ENV_FILE}" "${CONFIG_FILE}" "${PROVIDERS_FILE}" "${FALLBACK_FILE}"
    log_ok "Konfigurasi dihapus."
    press_enter
}

# =============================================================================
#  MENU UTAMA
# =============================================================================
main_menu() {
    while true; do
        show_banner
        echo -e "${C_BOLD}${C_WHITE}MENU UTAMA${C_RESET}"
        hr
        echo -e "  ${C_CYAN}1)${C_RESET} ${C_BOLD}Setup Pertama Kali${C_RESET}      ${C_DIM}(install + wizard lengkap)${C_RESET}"
        echo -e "  ${C_CYAN}2)${C_RESET} Tambah / ubah API key provider"
        echo -e "  ${C_CYAN}3)${C_RESET} Setup Telegram Bot"
        echo -e "  ${C_CYAN}4)${C_RESET} Atur fallback antar provider"
        echo -e "  ${C_CYAN}5)${C_RESET} Tambah skill baru"
        echo -e "  ${C_CYAN}6)${C_RESET} Jalankan / kelola gateway Telegram"
        echo -e "  ${C_CYAN}7)${C_RESET} Cek info & status"
        echo -e "  ${C_CYAN}8)${C_RESET} Update Hermes Agent"
        echo -e "  ${C_CYAN}9)${C_RESET} ${C_RED}Reset semua konfigurasi${C_RESET}"
        echo -e "  ${C_CYAN}p)${C_RESET} ${C_BOLD}Ubah kepribadian agent${C_RESET} ${C_DIM}(SOUL.md)${C_RESET}"
        echo -e "  ${C_CYAN}0)${C_RESET} Keluar"
        hr

        # Status indicator singkat
        local status_line=""
        if locate_hermes; then
            status_line="${C_GREEN}●${C_RESET} Hermes terpasang"
        else
            status_line="${C_RED}●${C_RESET} Hermes belum terpasang"
        fi
        local pcount=0
        [[ -f "${PROVIDERS_FILE}" ]] && pcount=$(wc -l < "${PROVIDERS_FILE}")
        status_line="${status_line}  ·  ${pcount} provider aktif"
        if [[ -n "$(env_get TELEGRAM_BOT_TOKEN 2>/dev/null || true)" ]]; then
            status_line="${status_line}  ·  ${C_GREEN}TG ✓${C_RESET}"
        fi
        echo -e "  ${C_DIM}Status:${C_RESET} ${status_line}"
        echo

        printf "  ${C_YELLOW}?${C_RESET} Pilih nomor menu: "
        local choice
        IFS= read -r choice </dev/tty || choice="0"

        case "${choice}" in
            1) action_setup_wizard ;;
            2) action_add_provider ;;
            3) action_setup_telegram ;;
            4) action_setup_fallback ;;
            5) action_add_skill ;;
            6) action_run_gateway ;;
            7) action_show_info ;;
            8) action_update ;;
            9) action_reset ;;
            p|P|persona|personality|soul) action_personality ;;
            0|q|Q|exit|quit)
                echo
                echo -e "${C_GREEN}Sampai jumpa! Selamat ngoprek bareng Hermes. 🚀${C_RESET}"
                echo
                exit 0
                ;;
            *)
                log_warn "Pilihan tidak dikenal."
                sleep 1
                ;;
        esac
    done
}

# =============================================================================
#  ENTRY POINT
# =============================================================================
main() {
    # Pastikan ada terminal interaktif
    if [[ ! -t 0 ]] && [[ ! -r /dev/tty ]]; then
        log_err "Script ini butuh terminal interaktif. Jalankan langsung di shell, bukan via pipe non-interaktif."
        exit 1
    fi

    # Peringatan root
    if [[ "${EUID}" -eq 0 ]]; then
        echo
        log_warn "Kamu menjalankan script sebagai ROOT."
        log_warn "Hermes akan terpasang ke /root/.hermes/. Sebaiknya gunakan user biasa."
        if ! prompt_yes_no "Tetap lanjut sebagai root?" "n"; then
            exit 0
        fi
    fi

    # Jika dapat argumen, jalankan aksi langsung tanpa menu (mode CLI)
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --setup|setup)        action_setup_wizard ;;
            --provider|provider)  action_add_provider ;;
            --telegram|telegram)  action_setup_telegram ;;
            --fallback|fallback)  action_setup_fallback ;;
            --skill|skill)        action_add_skill ;;
            --gateway|gateway)    action_run_gateway ;;
            --info|info|status)   action_show_info ;;
            --update|update)      action_update ;;
            --reset|reset)        action_reset ;;
            --personality|--persona|persona|personality|soul) action_personality ;;
            --help|-h|help)
                show_banner
                echo "Pemakaian: bash install.sh [perintah]"
                echo
                echo "Tanpa argumen → tampilkan menu interaktif."
                echo
                echo "Perintah:"
                echo "  setup       Setup wizard pertama kali"
                echo "  provider    Tambah/ubah provider LLM"
                echo "  telegram    Setup Telegram bot"
                echo "  fallback    Atur urutan fallback"
                echo "  skill       Tambah skill"
                echo "  gateway     Jalankan/kelola gateway"
                echo "  info        Cek status & info"
                echo "  update      Update Hermes"
                echo "  reset       Hapus semua konfigurasi"
                echo "  persona     Ubah kepribadian agent (SOUL.md)"
                exit 0
                ;;
            *)
                log_err "Perintah tidak dikenal: $1"
                exit 1
                ;;
        esac
        exit 0
    fi

    # Mode default: menu interaktif
    main_menu
}

main "$@"
