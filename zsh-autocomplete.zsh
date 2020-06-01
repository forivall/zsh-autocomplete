() {
  emulate -LR zsh -o noshortloops -o warncreateglobal

  [[ ! -v _autocomplete__options ]] && export _autocomplete__options=(
    ALWAYS_TO_END COMPLETE_ALIASES EXTENDED_GLOB GLOB_COMPLETE GLOB_DOTS LIST_PACKED
    no_CASE_GLOB no_COMPLETE_IN_WORD no_LIST_BEEP
  )

  [[ ! -v functions ]] && zmodload -i zsh/parameter
  [[ ! -v functions[add-zsh-hook] ]] && autoload -Uz add-zsh-hook

  functions[_autocomplete.add-zsh-hook]=$functions[add-zsh-hook]
  add-zsh-hook() {
    emulate -LR zsh -o noshortloops -o warncreateglobal

    # Prevent `_zsh_autosuggest_start` from being added.
    if [[ ${@[(ie)_zsh_autosuggest_start]} -gt ${#@} ]]
    then
      _autocomplete.add-zsh-hook "$@" > /dev/null
    fi
  }

  add-zsh-hook precmd _autocomplete.main.hook
}

_autocomplete.main.hook() {
  emulate -LR zsh -o noshortloops -o warncreateglobal

  # Remove itself after being called.
  add-zsh-hook -d precmd _autocomplete.main.hook

  # Initialize completion system, if it hasn't been done yet.
  # `zsh/complist` should be loaded _before_ `compinit`.
  if ! (zle -l menu-select && bindkey -l menuselect > /dev/null)
  then
    zmodload -i zsh/complist
    autoload -Uz compinit
    compinit
  elif ! [[ -v compprefuncs && -v comppostfuncs ]]
  then
    autoload -Uz compinit
    compinit
  fi

  [[ ! -v functions[min] ]] && autoload -Uz zmathfunc && zmathfunc

  [[ ! -v ZLE_REMOVE_SUFFIX_CHARS ]] && export ZLE_REMOVE_SUFFIX_CHARS=$' \t\n;&'
  export ZSH_AUTOSUGGEST_USE_ASYNC=1
  export ZSH_AUTOSUGGEST_MANUAL_REBIND=1
  [[ ! -v ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS ]] \
  && typeset -g -a ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS=(
    forward-char vi-forward-char vi-find-next-char vi-find-next-char-skip
    forward-word emacs-forward-word
    vi-forward-word vi-forward-word-end vi-forward-blank-word vi-forward-blank-word-end
	)
  [[ ! -v FZF_COMPLETION_TRIGGER ]] && export FZF_COMPLETION_TRIGGER=''
  [[ ! -v fzf_default_completion ]] && export fzf_default_completion='list-expand'
  [[ ! -v FZF_DEFAULT_OPTS ]] && export FZF_DEFAULT_OPTS='--bind=ctrl-space:abort,ctrl-k:kill-line'

  [[ ! -v functions[zstyle] ]] && zmodload -i zsh/zutil

  local -a option_tags=( '(|*-)argument-* (|*-)option[-+]* values' 'options' )

  # Remove incompatible styles.
  zstyle -d '*' single-ignored

  zstyle ':completion:*' completer _oldlist _list _expand _complete _match _ignored
  zstyle ':completion:*' menu 'yes select=long-list'
  zstyle ':completion:*' matcher-list 'm:{[:lower:]-}={[:upper:]_} r:|?=**'
  zstyle -e ':completion:*:complete:*' ignored-patterns '
    local word=$PREFIX$SUFFIX
    local prefix=${(M)word##*/}
    local suffix=${word##*/}
    if (( ${#suffix} == 0 ))
    then
      reply=( "${prefix}[[:punct:]]*" )
    else
      if [[ $suffix == [[:punct:]]* ]]
      then
        local punct=${(M)suffix##[[:punct:]]##}
        local nextchar=${suffix[${#punct}+1]}
        reply=( "${prefix}[[:punct:]]${punct}*" "^(${prefix}*${punct}${nextchar}*)" )
      else
        reply=( "${prefix}(?~${suffix[1]})*" )
      fi
    fi'
  zstyle -e ':completion:*' glob '
    [[ $PREFIX$SUFFIX == *[\*\(\|\<\[\?\^\#]* ]] && reply=( "true" ) || reply=( "false" )'

  zstyle -e ':completion:*' tag-order '
    reply=( '${(qq@)option_tags}' )
    if [[ $PREFIX$SUFFIX == [-+]* ]]
    then
      reply+=( "-" )
    fi'

  zstyle ':completion:*:expand:*' tag-order '! all-expansions original'

  zstyle -e ':completion:*' max-errors '
    reply=( $(( min(2, (${#PREFIX} + ${#SUFFIX}) / 2 - 1) )) numeric )'

  zstyle ':completion:*' expand prefix suffix
  zstyle ':completion:*' list-suffixes false
  zstyle ':completion:*' path-completion false
  zstyle ':completion:*:(-command-|cd|z):*' list-suffixes true
  zstyle ':completion:*:(-command-|cd|z):*' path-completion true

  zstyle ':completion:*' file-patterns \
    '*(#q^-/):all-files:file *(-/):directories:directory' '%p:globbed-files:"file or directory"'
  zstyle ':completion:*:-command-:*' file-patterns \
    '*(-/):directories:directory %p(#q^-/):globbed-files:executable' '*:all-files:file'
  zstyle ':completion:*:z:*' file-patterns '%p(-/):directories:directory'

  local directory_tags=( local-directories directory-stack named-directories directories )
  zstyle ':completion:*' group-order all-files directories globbed-files
  zstyle ':completion:*:-command-:*' group-order globbed-files directories all-files
  zstyle ':completion:*:(all-files|globbed-files)' group-name ''
  zstyle ':completion:*:('${(j:|:)directory_tags}')' group-name 'directories'
  zstyle ':completion:*:('${(j:|:)directory_tags}')' matcher 'm:{[:lower:]}={[:upper:]}'

  if zstyle -t ':autocomplete:' groups 'always'
  then
    zstyle ':completion:*' format '%F{yellow}%d:%f'
    zstyle ':completion:*' group-name ''
  fi

  zstyle ':completion:*:corrections' format '%F{green}%d:%f'
  zstyle ':completion:*:expansions' format '%F{yellow}%d:%f'
  zstyle ':completion:*:expansions' group-name ''
  zstyle ':completion:*:messages' format '%F{yellow}%d%f'
  zstyle ':completion:*:original' format '%F{yellow}%d:%f'
  zstyle ':completion:*:warnings' format '%F{red}%d%f'
  zstyle ':completion:*' auto-description '%F{yellow}%d%f'

  zstyle ':completion:*' add-space true
  zstyle ':completion:*' list-separator ''
  zstyle ':completion:*' use-cache true

  zstyle ':completion:(complete-word|menu-select):*' old-list always

  zstyle ':completion:correct-word:*' accept-exact true
  zstyle ':completion:correct-word:*' glob false
  zstyle ':completion:correct-word:*' matcher-list ''
  zstyle ':completion:correct-word:*:git-*:argument-*:*' tag-order '-'

  zstyle ':completion:list-choices:*' completer _expand _complete _ignored
  zstyle ':completion:list-choices:*' glob false
  zstyle ':completion:list-choices:*' menu ''

  zstyle ':completion:expand-word:*' completer _expand_alias _expand

  zstyle ':completion:list-expand:*' completer _expand _complete _ignored _approximate
  zstyle ':completion:list-expand:complete:*' ignored-patterns ''
  zstyle ':completion:list-expand:*' tag-order ''
  zstyle -e ':completion:list-expand:*' max-errors '
    reply="$(( min(7, (${#PREFIX} + ${#SUFFIX}) / 2 - 1) )) numeric"'
  zstyle ':completion:list-expand:*' list-suffixes true
  zstyle ':completion:list-expand:*' path-completion true
  zstyle ':completion:list-expand:*' format '%F{yellow}%d:%f'
  zstyle ':completion:list-expand:*' group-name ''

  if [[ ! -v key ]]
  then
    # This file can be generated with `autoload -U zkbd && zkbd`.
    # See http://zsh.sourceforge.net/Doc/Release/User-Contributions.html#Keyboard-Definition
    if [[ -r ${ZDOTDIR:-$HOME}/.zkbd/${TERM}-${VENDOR} ]]
    then
      source ${ZDOTDIR:-$HOME}/.zkbd/${TERM}-${VENDOR}
    fi

    if [[ ! -v key ]]
    then
      typeset -g -A key
    fi
  fi

  [[ ! -v terminfo ]] && zmodload -i zsh/terminfo
  if [[ -z $key[Up] ]]; then
    if [[ -n $terminfo[kcuu1] ]]; then key[Up]=$terminfo[kcuu1]; else key[Up]='^[OA'; fi
  fi
  if [[ -z $key[Down] ]]; then
    if [[ -n $terminfo[kcud1] ]]; then key[Down]=$terminfo[kcud1]; else key[Down]='^[OB'; fi
  fi
  if [[ -z $key[Tab] ]]; then
    if [[ -n $terminfo[ht] ]]; then key[Tab]=$terminfo[ht]; else key[Tab]='^I'; fi
  fi
  if [[ -z $key[BackTab] ]]; then
    if [[ -n $terminfo[kcbt] ]]; then key[BackTab]=$terminfo[kcbt]; else key[BackTab]='^[[Z'; fi
  fi

  # Make `terminfo` codes work.
  [[ ! -v functions[add-zle-hook-widget] ]] && autoload -Uz add-zle-hook-widget
  add-zle-hook-widget line-init _autocomplete.application-mode.hook
  add-zle-hook-widget line-finish _autocomplete.raw-mode.hook
  _autocomplete.application-mode.hook() {
    echoti smkx
  }
  _autocomplete.raw-mode.hook() {
    echoti rmkx
  }

  # Hard-code these values, because they are not generated by `zkbd` nor defined in `terminfo`.
  if [[ -z $key[Return] ]]; then key[Return]='^M'; fi
  if [[ -z $key[LineFeed] ]]; then key[LineFeed]='^J'; fi
  if [[ -z $key[ControlSpace] ]]; then key[ControlSpace]='^@'; fi
  if [[ -z $key[DeleteList] ]]; then key[DeleteList]='^D'; fi

  zle -C expand-word menu-select _autocomplete.expand-word.completion-widget

  if zle -l fzf-completion && zle -l fzf-cd-widget
  then
    bindkey $key[ControlSpace] expand-or-complete
    zle -N expand-or-complete _autocomplete.expand-or-complete.zle-widget
    bindkey -M menuselect -s $key[ControlSpace] $key[LineFeed]$key[ControlSpace]
  else
    bindkey $key[ControlSpace] expand-word
  fi

  zle -C menu-select menu-select _autocomplete.menu-select.completion-widget
  if zle -l fzf-history-widget
  then
    bindkey $key[Up] up-line-or-history-search
    zle -N up-line-or-history-search _autocomplete.up-line-or-history-search.zle-widget

    bindkey '^['$key[Up] history-search
    zle -N history-search fzf-history-widget

    bindkey $key[Down] down-line-or-menu-select
    zle -N down-line-or-menu-select _autocomplete.down-line-or-menu-select.zle-widget

    bindkey '^['$key[Down] menu-select
  else
    bindkey $key[ControlSpace] menu-select
  fi

  local tab_completion
  zstyle -s ":autocomplete:tab:" completion tab_completion || tab_completion='accept'
  case $tab_completion in
    'cycle')
      bindkey $key[Tab] menu-complete
      bindkey $key[BackTab] reverse-menu-complete
      ;;
    'select')
      bindkey $key[Tab] menu-select
      bindkey $key[BackTab] reverse-menu-complete
      zle -C reverse-menu-complete menu-select _main_complete
      ;;
    *)
      bindkey $key[BackTab] list-expand
      zle -C list-expand menu-select _autocomplete.list-expand.completion-widget

      local keymap_main=$( bindkey -lL main )
      if [[ $keymap_main == *emacs* ]]
      then
        if [[ ! -v key[Undo] ]]; then key[Undo]='^_'; fi
      elif [[ $keymap_main == *viins* ]]
      then
        if [[ ! -v key[Undo] ]]; then key[Undo]='^[u'; fi
      fi
      if [[ -v key[Undo] ]]
      then
        bindkey -M menuselect $key[Tab] accept-and-hold
        bindkey -M menuselect -s $key[BackTab] $key[DeleteList]$key[Undo]$key[BackTab]
      fi
      ;;
  esac

  if zstyle -t ":autocomplete:space:" magic expand-history
  then
    bindkey ' ' magic-space
    zle -N magic-space
    magic-space() {
      zle .expand-history
      zle .self-insert
    }
  fi
  zle -C correct-word complete-word _autocomplete.correct-word.completion-widget

  # Remove `_zsh_autosuggest_start` in case we failed to prevent it being added.
  add-zsh-hook -d precmd _zsh_autosuggest_start

  # Monkeypatch functions from `zsh-autosuggestions` and syntax highlighting.
  _autocomplete.no-op() {}
  if [[ -v functions[_zsh_highlight] ]]
  then
    functions[_autocomplete._zsh_highlight]=$functions[_zsh_highlight]
    functions[_zsh_highlight]=$functions[_autocomplete.no-op]
  else
    functions[_autocomplete._zsh_highlight]=$functions[_autocomplete.no-op]
  fi
  if [[ -v functions[_zsh_autosuggest_fetch] ]]
  then
    functions[_autocomplete._zsh_autosuggest_fetch]=$functions[_zsh_autosuggest_fetch]
    functions[_zsh_autosuggest_fetch]=$functions[_autocomplete.no-op]
  else
    functions[_autocomplete._zsh_autosuggest_fetch]=$functions[_autocomplete.no-op]
  fi
  if [[ ! -v functions[_zsh_autosuggest_highlight_apply] ]]
  then
    functions[_zsh_autosuggest_highlight_apply]=$functions[_autocomplete.no-op]
  fi

  # Let `zsh-autosuggestions` wrap all widgets before this line, but not the ones after.
  [[ -v functions[_zsh_autosuggest_bind_widgets] ]] && _zsh_autosuggest_bind_widgets

  if [[ $tab_completion == 'accept' ]]
  then
  bindkey $key[Tab] complete-word
  if [[ -v functions[_zsh_autosuggest_invoke_original_widget] ]]
  then
    zle -N complete-word _autocomplete.complete-word.zle-widget
    zle -C _complete_word complete-word _autocomplete.complete-word.completion-widget
  else
    zle -C complete-word complete-word _autocomplete.complete-word.completion-widget
  fi
  fi

  [[ ! -v sysparams ]] && zmodload -i zsh/system
  typeset -g _AUTOCOMPLETE__ASYNC_FD _AUTOCOMPLETE__CHILD_PID
  zle -C async-list-choices list-choices _autocomplete.async-list-choices.completion-widget
  zle -N _autocomplete.async_callback
  zle -C list-choices list-choices _autocomplete.list-choices.completion-widget
  add-zle-hook-widget line-pre-redraw _autocomplete.list-choices.hook
}

_autocomplete.list-choices.hook() {
  setopt localoptions nobanghist noshortloops warncreateglobal $_autocomplete__options

  if (( (PENDING + KEYS_QUEUED_COUNT) == 0 ))
  then
    _autocomplete._zsh_autosuggest_fetch
    zle async-list-choices ${KEYS[-1]} 2> /dev/null
    _autocomplete._zsh_highlight
    _zsh_autosuggest_highlight_apply
  fi
}

_autocomplete.async-list-choices.completion-widget() {
  setopt localoptions nobanghist noshortloops warncreateglobal $_autocomplete__options

	# If we've got a pending request, cancel it
	if [[ -n "$_AUTOCOMPLETE__ASYNC_FD" ]] && { true <&$_AUTOCOMPLETE__ASYNC_FD } 2>/dev/null; then
		# Close the file descriptor and remove the handler
		exec {_AUTOCOMPLETE__ASYNC_FD}<&-
		zle -F $_AUTOCOMPLETE__ASYNC_FD

		# We won't know the pid unless the user has zsh/system module installed
		if [[ -n "$_AUTOCOMPLETE__CHILD_PID" ]]; then
			# Zsh will make a new process group for the child process only if job
			# control is enabled (MONITOR option)
			if [[ -o MONITOR ]]; then
				# Send the signal to the process group to kill any processes that may
				# have been forked by the suggestion strategy
				kill -TERM -$_AUTOCOMPLETE__CHILD_PID 2>/dev/null
			else
				# Kill just the child process since it wasn't placed in a new process
				# group. If the suggestion strategy forked any child processes they may
				# be orphaned and left behind.
				kill -TERM $_AUTOCOMPLETE__CHILD_PID 2>/dev/null
			fi
		fi
	fi

	# Fork a process and open a pipe to read from it
	exec {_AUTOCOMPLETE__ASYNC_FD}< <(
		# Tell parent process our pid
		echo $sysparams[pid]

    local curcontext
    _autocomplete._main_complete list-choices
    echo -E $'\0'$1$'\0'
    echo -E $'\0'$LBUFFER$'\0'
    echo -E $'\0'$RBUFFER$'\0'
    echo "${compstate[nmatches]}"
    echo "${compstate[list_lines]}"
  )

	# Read the pid from the child process
	read _AUTOCOMPLETE__CHILD_PID <&$_AUTOCOMPLETE__ASYNC_FD

	# Install a widget to handle input from the fd
	zle -F -w "$_AUTOCOMPLETE__ASYNC_FD" _autocomplete.async_callback
}

# Called when new data is ready to be read from the pipe
# First arg will be fd ready for reading
# Second arg will be passed in case of error
_autocomplete.async_callback() {
  setopt localoptions nobanghist noshortloops warncreateglobal $_autocomplete__options

  {
  	if [[ -z "$2" || "$2" == "hup" ]]; then

      (( $#BUFFER == 0 )) && return

      local lastkey lbuffer rbuffer
      local -i nmatches list_lines
      read -r -u $1 lastkey
      read -r -u $1 lbuffer
      read -r -u $1 rbuffer
      read -r -u $1 nmatches
      read -r -u $1 list_lines

      [[ $'\0'$LBUFFER$'\0' != $lbuffer || $'\0'$RBUFFER$'\0' != $rbuffer ]] && return

      if [[ ${LBUFFER[-2]} != [\ \/] ]]
      then
        case $lastkey in
          $'\0'' '$'\0')
            if zstyle -T ":autocomplete:space:" magic correct-word && [[ ${LBUFFER[-1]} == ' ' ]]
            then
              zle .backward-delete-char
              zle correct-word
              if [[ ${LBUFFER[-1]} != ' ' ]]
              then
                LBUFFER=$LBUFFER' '
              fi
            fi
            ;;
          $'\0''/'$'\0')
            if zstyle -T ":autocomplete:slash:" magic correct-word && [[ ${LBUFFER[-1]} == '/' ]]
            then
              zle .backward-delete-char
              zle correct-word
              zle .auto-suffix-remove
              LBUFFER=$LBUFFER'/'
            fi
            ;;
        esac
      fi
      zle list-choices $nmatches $list_lines
  	fi
  } always {
    _autocomplete._zsh_highlight
    _zsh_autosuggest_highlight_apply
    zle -R

    if [[ -n "$1" ]] && { true <&$1 } 2>/dev/null
    then
      # Close the fd
      exec {1}<&-

    	# Remove the handler
    	zle -F "$1"
    fi
  }
}

_autocomplete.list-choices.completion-widget() {
  setopt localoptions noshortloops warncreateglobal $_autocomplete__options
  unsetopt GLOB_COMPLETE

  local curcontext
  _autocomplete.curcontext list-choices
  _autocomplete.max_lines
  local max_lines=REPLY

  if [[ -v 1 ]] && (( $1 == 0 ))
  then
    _autocomplete.warning '' # 'No matching completions found.'
  elif [[ -v 2 ]] && (( ($2 + BUFFERLINES + 1) > max_lines ))
  then
    local warning='Too many completions to fit on screen. Press '
    if zle -l fzf-history-widget
    then
      warning+='Down Arrow'
    else
      warning+='Ctrl-Space'
    fi
    warning+=' to open the menu or type more to filter.'
    _autocomplete.warning '...' # $warning
  else
    _autocomplete._main_complete list-choices
  fi
  compstate[list]='list force'
  compstate[insert]=''
}

_autocomplete.warning() {
  setopt localoptions noshortloops nowarncreateglobal $_autocomplete__options

  local format
  zstyle -s ":completion:${curcontext}:warnings" format format
  _setup warnings
  local mesg
  zformat -f mesg "$format" "d:$1" "D:$1"
  compadd -x "$mesg"
}

_autocomplete.correct-word.completion-widget() {
  setopt localoptions noshortloops warncreateglobal $_autocomplete__options
  unsetopt GLOB_COMPLETE

  if [[ ${LBUFFER[-1]} != [[:IDENT:]] || ${RBUFFER[1]} != [[:IFS:]]# ]]
  then
    return 1
  fi

  local curcontext
  _autocomplete.curcontext correct-word
  _main_complete _correct
  if (( compstate[nmatches] > 0 ))
  then
    _main_complete _complete
    compstate[exact]='accept'
  fi
}

_autocomplete.list-expand.completion-widget() {
  setopt localoptions noshortloops warncreateglobal $_autocomplete__options

  local curcontext
  _autocomplete._main_complete list-expand
}

_autocomplete.complete-word.zle-widget() {
  setopt localoptions noshortloops warncreateglobal $_autocomplete__options

  local lbuffer=$LBUFFER
  if [[ $POSTDISPLAY != \0# ]]
  then
    {
      functions[_autocomplete.tmp]=$functions[_zsh_autosuggest_invoke_original_widget]
      _zsh_autosuggest_invoke_original_widget() {
        zle .forward-word
      }
      _zsh_autosuggest_partial_accept
    } always {
      unfunction _zsh_autosuggest_invoke_original_widget
      functions[_zsh_autosuggest_invoke_original_widget]=$functions[_autocomplete.tmp]
      return 0
    }
  fi
  if [[ $lbuffer == $LBUFFER ]]
  then
    zle _complete_word
  fi
}

_autocomplete.complete-word.completion-widget() {
  setopt localoptions noshortloops warncreateglobal $_autocomplete__options

  local curcontext
  local +h -a comppostfuncs=( _autocomplete.insert_first_match )
  _autocomplete._main_complete complete-word
}

_autocomplete.insert_first_match() {
  if [[ -v compstate[old_list] ]]
  then
    compstate[insert]='1'
    if [[ $compstate[context] == (command|redirect) ]]
    then
      compstate[insert]+=' '
    fi
  else
    _autocomplete.handle_long_list
  fi
}

_autocomplete.down-line-or-menu-select.zle-widget() {
  setopt localoptions noshortloops warncreateglobal $_autocomplete__options

  local curcontext
  _autocomplete.curcontext down-line-or-menu-select

  if (( BUFFERLINES == 1 ))
  then
    zle menu-select
  else
    zle .down-line || zle .end-of-line
  fi
}

_autocomplete.menu-select.completion-widget() {
  setopt localoptions noshortloops warncreateglobal $_autocomplete__options

  local curcontext
  _autocomplete._main_complete menu-select
  compstate[insert]='menu'
}

_autocomplete.up-line-or-history-search.zle-widget() {
  setopt localoptions noshortloops warncreateglobal $_autocomplete__options

  local curcontext
  _autocomplete.curcontext up-line-or-history-search

  if (( BUFFERLINES == 1 ))
  then
    zle history-search
  else
    zle .up-line || zle .beginning-of-line
  fi
}

_autocomplete.expand-or-complete.zle-widget() {
  setopt localoptions noshortloops warncreateglobal $_autocomplete__options

  local curcontext
  _autocomplete.curcontext expand-or-complete

  if [[ $BUFFER == [[:IFS:]]# ]]
  then
    zle fzf-cd-widget
    return
  fi

  if [[ ${LBUFFER[-1]} != [[:IFS:]]#
     || ${RBUFFER[1]} != [[:IFS:]]# ]]
  then
    zle .select-in-shell-word
    local lbuffer=$LBUFFER
    if zle expand-word
    then
      return 0
    elif [[ $lbuffer != $LBUFFER ]]
    then
      zle .auto-suffix-remove
      return 0
    fi
  fi

  zle fzf-completion
}

_autocomplete.expand-word.completion-widget() {
  setopt localoptions noshortloops warncreateglobal $_autocomplete__options

  local curcontext
  _autocomplete._main_complete expand-word
  (( compstate[nmatches] == 1)) && compstate[insert]='1'
  (( compstate[nmatches] > 0))
}

_autocomplete.curcontext() {
  emulate -LR zsh -o noshortloops -o warncreateglobal

  typeset -g curcontext
  curcontext="${curcontext:-}"
  if [[ -z "$curcontext" ]]; then
    curcontext="$1:::"
  else
    curcontext="$1:${curcontext#*:}"
  fi
}

_autocomplete._main_complete() {
  setopt localoptions noshortloops warncreateglobal $_autocomplete__options

  _autocomplete.curcontext $1
  shift
  (( $#comppostfuncs == 0 )) && local +h -a comppostfuncs=( _autocomplete.handle_long_list )
  _main_complete "$@"
  (( compstate[nmatches] > 0 ))
}

_autocomplete.handle_long_list() {
  emulate -LR zsh -o noshortloops -o warncreateglobal

  compstate[insert]=''
  compstate[list_max]=0
  _autocomplete.max_lines
  local max_lines=REPLY
  if (( (compstate[list_lines] + BUFFERLINES + 1) > max_lines ))
  then
    compstate[list]=''
    if [[ $WIDGETSTYLE == menu-select ]]
    then
      compstate[insert]='menu'
    fi
  fi
  return 0
}

_autocomplete.max_lines() {
  emulate -LR zsh -o noshortloops -o warncreateglobal

  typeset -g REPLY
  zstyle -s ":autocomplete:$curcontext" max-lines REPLY || REPLY=$LINES
  [[ $REPLY == *% ]] && (( REPLY=(LINES * ${REPLY%%\%} / 100) ))
  (( REPLY=min(LINES, REPLY) ))
}
