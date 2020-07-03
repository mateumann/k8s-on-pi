## Autocompletion
zstyle ':completion::complete:*' use-cache 1
zstyle ':completion:*:descriptions' format '%B%F{15}%K{5}%{ %}%d%{ %}%k%f%b'
zstyle ':completion:*:warnings' format '%F{13}Sorry, no matches for: %d%f'


## History file configuration
[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zsh_history"
[ "$HISTSIZE" -lt 50000 ] && HISTSIZE=50000
[ "$SAVEHIST" -lt 20000 ] && SAVEHIST=20000

## History command configuration
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_dups       # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space
setopt hist_verify            # show command with history expansion to user before running it
setopt share_history          # share command history data
