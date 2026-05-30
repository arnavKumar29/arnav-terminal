# arnavterminal-shell-integration (zprofile)
#
# See zshenv.zsh for the rationale on the trailing `:`.
{
  _arnavterminal_user_zdotdir="${arnavterminal_USER_ZDOTDIR:-$HOME}"
  [ -f "$_arnavterminal_user_zdotdir/.zprofile" ] && source "$_arnavterminal_user_zdotdir/.zprofile"
  unset _arnavterminal_user_zdotdir
}
:
