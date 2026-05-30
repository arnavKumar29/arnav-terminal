# arnavterminal-shell-integration (zshrc)
#
# Emits OSC 7 (cwd) + OSC 133 A/B/C/D (prompt-start / prompt-end / pre-exec /
# command-done-with-exit-code) so the host can detect command boundaries and
# track cwd without re-parsing the prompt. `status` is a read-only special in
# zsh, so we shadow $? into `_arnavterminal_ret`.

{
  _arnavterminal_user_zdotdir="${arnavterminal_USER_ZDOTDIR:-$HOME}"
  [ -f "$_arnavterminal_user_zdotdir/.zshrc" ] && source "$_arnavterminal_user_zdotdir/.zshrc"
  unset _arnavterminal_user_zdotdir
}

# Re-source guard within a single shell (e.g. user runs `source ~/.zshrc`).
# This is NOT exported, so each nested zsh installs its own hooks — desired,
# since every interactive shell needs its own prompt integration.
if [[ -z "$__arnavterminal_HOOKS_LOADED" ]]; then
  __arnavterminal_HOOKS_LOADED=1
  autoload -Uz add-zsh-hook 2>/dev/null

  # URL-encode $PWD byte-wise so multi-byte paths stay valid in the `file://`
  # URI emitted via OSC 7. `no_multibyte` forces ${s[i]} to index bytes (not
  # code points), and LC_ALL=C keeps the [a-zA-Z0-9...] class single-byte.
  _arnavterminal_urlencode() {
    emulate -L zsh
    setopt localoptions no_multibyte
    local LC_ALL=C s="$1" i byte
    for (( i=1; i<=${#s}; i++ )); do
      byte="${s[i]}"
      case "$byte" in
        [a-zA-Z0-9/._~-]) printf '%s' "$byte" ;;
        *) printf '%%%02X' "'$byte" ;;
      esac
    done
  }

  _arnavterminal_precmd() {
    local _arnavterminal_ret=$?
    printf '\e]133;D;%s\e\\' "$_arnavterminal_ret"
    printf '\e]7;file://%s%s\e\\' "${HOST}" "$(_arnavterminal_urlencode "$PWD")"
    # Re-inject prompt-end marker in case a framework rebuilt PS1 (p10k, starship).
    if [[ "$PS1" != *$'\e]133;B\e\\'* ]]; then
      PS1=$'%{\e]133;B\e\\%}'"$PS1"
    fi
    printf '\e]133;A\e\\'
  }

  _arnavterminal_preexec() {
    local cmd="${1//[[:cntrl:]]/ }"
    printf '\e]133;C;%s\e\\' "${cmd[1,256]}"
  }

  if (( $+functions[add-zsh-hook] )); then
    add-zsh-hook precmd _arnavterminal_precmd
    add-zsh-hook preexec _arnavterminal_preexec
  fi

  if [[ "$OSTYPE" == "darwin"* ]]; then
    _os=$(sw_vers -productName)
    _os_ver=$(sw_vers -productVersion)
    SYS_OS="${_os} ${_os_ver}"
    SYS_CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
    SYS_GPU=$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Chipset Model/ {print $2}' | head -n1)
    mem=$(sysctl -n hw.memsize 2>/dev/null)
    if [[ -n "$mem" ]]; then
      SYS_RAM="$((mem / 1073741824)).0 GB"
    else
      SYS_RAM="Unknown"
    fi
  else
    SYS_OS=$(cat /etc/os-release 2>/dev/null | grep '^PRETTY_NAME' | cut -d'"' -f2)
    SYS_CPU=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -n1 | cut -d':' -f2 | xargs)
    SYS_GPU=$(lspci 2>/dev/null | grep -i vga | awk -F': ' '{print $2}' | head -n1)
    SYS_RAM=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
  fi

  SYS_OS=${SYS_OS:-"Unknown OS"}
  SYS_CPU=${SYS_CPU:-"Unknown CPU"}
  SYS_GPU=${SYS_GPU:-"Unknown GPU"}
  SYS_RAM=${SYS_RAM:-"Unknown RAM"}

  sysinfo=(
    ""
    "  OS:  ${SYS_OS}"
    "  CPU: ${SYS_CPU}"
    "  RAM: ${SYS_RAM}"
    "  GPU: ${SYS_GPU}"
    "" "" "" "" ""
  )

  art=(
    "          **********          "
    "       ****************       "
    "      ****          ****      "
    "                    ****      "
    "       *****************      "
    "      ******************      "
    "     ****           ****      "
    "     ****           ****      "
    "      ******************  ****"
    "       ****************    ****"
  )

  colors=("38;5;175" "38;5;140" "38;5;116" "38;5;150" "38;5;186" "38;5;175" "38;5;140" "38;5;116" "38;5;150" "38;5;186")

  printf '\e[?25l'
  for ((frame=0; frame<15; frame++)); do
    for ((i=1; i<=10; i++)); do
      idx=$(( (10 - i + frame) % 10 + 1 ))
      col="${colors[$idx]}"
      printf "\e[%sm%s\e[0m%s\n" "$col" "${art[$i]}" "${sysinfo[$i]}"
    done
    sleep 0.04
    if [[ "$frame" -lt 14 ]]; then
      printf '\e[10A'
    fi
  done
  printf '\e[?25h\n'

  _arnavterminal_precmd
fi
:
