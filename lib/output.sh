#!/usr/bin/env bash
# Output Functions

# BASH Colors
setup_bash_colors(){
  export fgblk fgred fggrn fgylw fgblu fgpur fgcyn fgwht
  fgblk="$(tput setaf 0 || true)"     # Black - Regular
  fgred="$(tput setaf 1 || true)"     # Red
  fggrn="$(tput setaf 2 || true)"     # Green
  fgylw="$(tput setaf 3 || true)"     # Yellow
  fgblu="$(tput setaf 4 || true)"     # Blue
  fgpur="$(tput setaf 5 || true)"     # Purple
  fgcyn="$(tput setaf 6 || true)"     # Cyan
  fgwht="$(tput setaf 7 || true)"     # White

  export bfgblk bfgred bfggrn bfgylw bfgblu bfgpur bfgcyn bfgwht
  bfgblk="$(tput setaf 8 || true)"    # Black - Bright
  bfgred="$(tput setaf 9 || true)"    # Red
  bfggrn="$(tput setaf 10 || true)"   # Green
  bfgylw="$(tput setaf 11 || true)"   # Yellow
  bfgblu="$(tput setaf 12 || true)"   # Blue
  bfgpur="$(tput setaf 13 || true)"   # Purple
  bfgcyn="$(tput setaf 14 || true)"   # Cyan
  bfgwht="$(tput setaf 15 || true)"   # White

  export bgblk bgred bggrn bgylw bgblu bgpur bgcyn bgwht
  bgblk="$(tput setab 0 || true)"     # Black - Background
  bgred="$(tput setab 1 || true)"     # Red
  bggrn="$(tput setab 2 || true)"     # Green
  bgylw="$(tput setab 3 || true)"     # Yellow
  bgblu="$(tput setab 4 || true)"     # Blue
  bgpur="$(tput setab 5 || true)"     # Purple
  bgcyn="$(tput setab 6 || true)"     # Cyan
  bgwht="$(tput setab 7 || true)"     # White

  export bbgblk bbgred bbggrn bbgylw bbgblu bbgpur bbgcyn bbgwht
  bbgblk="$(tput setab 8  || true)"   # Black - Background - Bright
  bbgred="$(tput setab 9  || true)"   # Red
  bbggrn="$(tput setab 10 || true)"   # Green
  bbgylw="$(tput setab 11 || true)"   # Yellow
  bbgblu="$(tput setab 12 || true)"   # Blue
  bbgpur="$(tput setab 13 || true)"   # Purple
  bbgcyn="$(tput setab 14 || true)"   # Cyan
  bbgwht="$(tput setab 15 || true)"   # White

  export normal mkbolb undrln noundr mkblnk revers
  normal="$(tput sgr0  || true)"      # text reset
  mkbold="$(tput bold  || true)"      # make bold
  undrln="$(tput smul  || true)"      # underline
  noundr="$(tput rmul  || true)"      # remove underline
  mkblnk="$(tput blink || true)"      # make blink
  revers="$(tput rev   || true)"      # reverse
}

# Logging stuff.
is_silent() { [[ ${SILENT:-} == true ]] ;}
is_color()  { [[ ${TERM:-screen-256color} =~ color ]] && setup_bash_colors ;}
e_header()  { is_silent || { is_color && printf "\n${mkbold}${bfgwht}%s${normal}\n" "$@" || printf "\n%s\n" "$@" ;} ;}
e_footer()  { is_silent || { is_color && printf "\n${mkbold}${bfgwht}%s${normal}\n" "$@" || printf "  ➜  %s\n" "$@";} ;}
e_ok()      { is_silent || { is_color && printf "  ${bfggrn}✔${normal}  %s\n" "$@" || printf "  ✔  %s\n" "$@" ;} ;}
e_error()   { is_silent || { is_color && printf "  ${fgred}✖${normal}  %s\n" "$@" >&2 || printf "  ✖  %s\n" "$@";} ;}
e_warn()    { is_silent || { is_color && printf "  ${fgylw}${normal}  %s\n" "$@" || printf "    %s\n" "$@";} ;}
e_info()    { is_silent || { is_color && printf "  ${fgcyn}➜${normal}  %s\n" "$@" || printf "  ➜  %s\n" "$@";} ;}
e_abort()   { e_error "$1"; return "${2:-1}" ;}
e_finish()  { e_ok "Finished ${BASH_SOURCE[0]} at $(/bin/date "+%F %T")"; }
