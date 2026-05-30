# arnavterminal-shell-integration (bashrc)
#
# Differences vs zsh integration:
# - We emulate login-shell init manually (/etc/profile, profile files) because
#   bash ignores --rcfile when started with -l.
# - Pre-exec marker uses PS0 (bash 4.4+). On older bash (macOS default 3.2) we
#   skip it — a fragile DEBUG-trap alternative would clobber the user's own
#   traps and interact badly with debuggers.

if [ -z "$__arnavterminal_HOOKS_LOADED" ]; then
  __arnavterminal_HOOKS_LOADED=1

  [ -f /etc/profile ] && source /etc/profile
  [ -f /etc/bashrc ] && source /etc/bashrc
  if [ -f "$HOME/.bash_profile" ]; then
    source "$HOME/.bash_profile"
  elif [ -f "$HOME/.bash_login" ]; then
    source "$HOME/.bash_login"
  elif [ -f "$HOME/.profile" ]; then
    source "$HOME/.profile"
  fi
  # .bashrc may have been sourced already by .bash_profile; sourcing again is
  # safe for idempotent rc files (the common case). If yours has side effects
  # on reload, guard with a flag.
  [ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"

  _arnavterminal_urlencode() {
    local LC_ALL=C s="$1" i c
    for (( i=0; i<${#s}; i++ )); do
      c="${s:i:1}"
      case "$c" in
        [a-zA-Z0-9/._~-]) printf '%s' "$c" ;;
        *) printf '%%%02X' "'$c" ;;
      esac
    done
  }

  _arnavterminal_precmd() {
    local _arnavterminal_ret=$?
    printf '\e]133;D;%s\e\\' "$_arnavterminal_ret"
    printf '\e]7;file://%s%s\e\\' "${HOSTNAME:-$(uname -n 2>/dev/null)}" "$(_arnavterminal_urlencode "$PWD")"
    if [ -z "$__arnavterminal_PS1_INJECTED" ]; then
      PS1='\[\e]133;B\e\\\]'"$PS1"
      __arnavterminal_PS1_INJECTED=1
    fi
    printf '\e]133;A\e\\'
  }

  case ":${PROMPT_COMMAND:-}:" in
    *":_arnavterminal_precmd:"*) ;;
    *) PROMPT_COMMAND="_arnavterminal_precmd${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
  esac

  # Pre-exec marker via PS0 (bash 4.4+). PS0 is expanded just before a command
  # runs — cleaner than a DEBUG trap, which would clobber user traps and fire
  # on every command including inside PROMPT_COMMAND.
  if [ "${BASH_VERSINFO[0]:-0}" -gt 4 ] \
     || { [ "${BASH_VERSINFO[0]:-0}" -eq 4 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 4 ]; }; then
    PS0='\[\e]133;C\e\\\]'"${PS0:-}"
  fi

  if [[ "$OSTYPE" == "darwin"* ]]; then
    _os=$(sw_vers -productName)
    _os_ver=$(sw_vers -productVersion)
    SYS_OS="${_os} ${_os_ver}"
    SYS_CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
    SYS_GPU=$(system_profiler SPDisplaysDataType 2>/dev/null | awk -F': ' '/Chipset Model/ {print $2}' | head -n1)
    mem=$(sysctl -n hw.memsize 2>/dev/null)
    if [ -n "$mem" ]; then
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
    for ((i=0; i<10; i++)); do
      idx=$(( (9 - i + frame) % 10 ))
      col="${colors[$idx]}"
      printf "\e[%sm%s\e[0m%s\n" "$col" "${art[$i]}" "${sysinfo[$i]}"
    done
    sleep 0.04
    if [ "$frame" -lt 14 ]; then
      printf '\e[10A'
    fi
  done
  printf '\e[?25h\n'

  _arnavterminal_precmd
fi
:
