#!/usr/bin/env bash iatest=$(expr index "$-" i)

#######################################################
# SOURCED ALIAS'S AND SCRIPTS
#######################################################
# Auto-start Hyprland on tty1
# if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
#   exec Hyprland
# fi

# start fastfetch on terminal open if uptime > 5 min (300s)
if [[ $iatest -gt 0 ]] && [ -f /usr/bin/fastfetch ]; then
    ut=$(uptime -r 2>/dev/null | awk '{print int($2)}')
    if [ "$ut" -gt 300 ]; then
        fastfetch
    fi
fi

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Enable bash programmable completion features in interactive shells
if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

#######################################################
# EXPORTS
#######################################################

# Disable the bell
if [[ $iatest -gt 0 ]]; then bind "set bell-style visible"; fi

# Expand the history size
export HISTFILESIZE=10000
export HISTSIZE=500
export HISTTIMEFORMAT="%F %T" # add timestamp to history

# Don't put duplicate lines in the history and do not add lines that start with a space
export HISTCONTROL=erasedups:ignoredups:ignorespace

# Check the window size after each command and, if necessary, update the values of LINES and COLUMNS
shopt -s checkwinsize

# Causes bash to append to history instead of overwriting it so if you start a new terminal, you have old session history
shopt -s histappend
PROMPT_COMMAND='history -a'

# set up XDG folders
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# Seeing as other scripts will use it might as well export it
export LINUXTOOLBOXDIR="$HOME/linuxtoolbox"

# Allow ctrl-S for history navigation (with ctrl-R)
[[ $- == *i* ]] && stty -ixon

# Ignore case on auto-completion
# Note: bind used instead of sticking these in .inputrc
if [[ $iatest -gt 0 ]]; then bind "set completion-ignore-case on"; fi

# Show auto-completion list automatically, without double tab
if [[ $iatest -gt 0 ]]; then bind "set show-all-if-ambiguous On"; fi

# Set the default editor
export EDITOR=nvim
export VISUAL=nvim
alias spico='sudo pico'
alias snano='sudo nano'

# To have colors for ls and all grep commands such as grep, egrep and zgrep
export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=00;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'
#export GREP_OPTIONS='--color=auto' #deprecated

# Check if ripgrep is installed
if command -v rg &> /dev/null; then
    # Alias grep to rg if ripgrep is installed
    alias grep='rg'
else
    # Alias grep to /usr/bin/grep with GREP_OPTIONS if ripgrep is not installed
    alias grep="/usr/bin/grep $GREP_OPTIONS"
fi
unset GREP_OPTIONS

# Color for manpages in less makes manpages a little easier to read
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

# fzf env varible for better look
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --color=16"
#######################################################
# MACHINE SPECIFIC ALIAS'S
#######################################################

# Alias's for SSH
# alias SERVERNAME='ssh YOURWEBSITE.com -l USERNAME -p PORTNUMBERHERE'

# Alias's to change the directory
alias web='cd /var/www/html'

# Alias's to mount ISO files
# mount -o loop /home/NAMEOFISO.iso /home/ISOMOUNTDIR/
# umount /home/NAMEOFISO.iso
# (Both commands done as root only.)

#######################################################
# GENERAL ALIAS'S
#######################################################
# To temporarily bypass an alias, we precede the command with a \
# EG: the ls command is aliased, but to use the normal ls command you would type \ls

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias vibrc='nvim ~/.bashrc'
alias vibrh='nvim ~/.bash_history'
alias date='date "+%Y-%m-%d %A %T %Z"'

# Alias's to modified commands
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -I --preserve-root'
alias mkdir='mkdir -p'
alias ps='ps auxf'
alias pingg='ping -c 5 google.com'
alias less='less -R'
alias cls='clear'
alias apt-get='sudo apt-get'
alias multitail='multitail --no-repeat -c'
alias freshclam='sudo freshclam'
alias vi='nvim'
alias svi='sudo nvim'
alias vis='nvim "+set si"'
alias yayf="yay -Slq | fzf --multi --preview 'yay -Sii {1}' --preview-window=down:75% | xargs -ro yay -S"

# Change directory aliases
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# cd into the old directory
alias bd='cd "$OLDPWD"'

# Remove a directory and all files
alias rmd='/bin/rm  --recursive --force --verbose '

# Alias's for multiple directory listing commands
# alias la='ls -Alh'                # show hidden files
# alias ls='ls -laFh --color=always --group-directories-first' # add colors and file type extensions
alias l='lsd'
alias la='lsd -a'
alias ls='lsd -l --group-directories-first'
alias lx='ls -lXBh'                           # sort by extension
alias lk='ls -lSrh'                           # sort by size
alias lc='ls -ltcrh'                          # sort by change time
alias lu='ls -lturh'                          # sort by access time
alias lr='ls -lRh'                            # recursive ls
alias lst='ls -ltrh'                          # sort by date
alias lm='ls -alh |more'                      # pipe through 'more'
alias lw='ls -xAh'                            # wide listing format
alias ll='ls -Fls'                            # long listing format
alias labc='ls -lap'                          # alphabetical sort
alias lf="ls -l | egrep -v '^d'"              # files only
alias ldir="ls -l | egrep '^d'"               # directories only
alias lla='lsd -la --group-directories-first' # List and Hidden Files

# alias chmod commands
alias mx='chmod a+x'
alias 000='chmod -R 000'
alias 644='chmod -R 644'
alias 666='chmod -R 666'
alias 755='chmod -R 755'
alias 777='chmod -R 777'

# Search command line history
alias h="history | grep "

# Search running processes
alias p="ps aux | grep "
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"

# Search files in the current folder
alias f="find . | grep "

# Count all files (recursively) in the current folder
alias countfiles="for t in files links directories; do echo \`find . -type \${t:0:1} | wc -l\` \$t; done 2> /dev/null"

# To see if a command is aliased, a file, or a built-in command
alias checkcommand="type -t"

# Show open ports
alias openports='netstat -nape --inet'

# Alias's for safe and forced reboots
alias shutd='sudo shutdown now'
alias reboot='sudo shutdown -r now'
alias rebootf='sudo shutdown -r -n now'
alias sleep='systemctl suspend'

# Alias's to show disk space and space used in a folder
alias diskspace="du -S | sort -n -r |more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

# Show all logs in /var/log
alias logs="sudo find /var/log -type f -exec file {} \; | grep 'text' | cut -d' ' -f1 | sed -e's/:$//g' | grep -v '[0-9]$' | xargs tail -f"

# SHA1
alias sha1='openssl sha1'

alias clickpaste='sleep 3; xdotool type "$(xclip -o -selection clipboard)"'

# KITTY - alias to be able to use kitty features when connecting to remote servers(e.g use tmux on remote server)
alias kssh="kitty +kitten ssh"

alias docker-clean=' \
    docker container prune -f ; \
    docker image prune -f ; \
    docker network prune -f ; \
    docker volume prune -f '

alias linuxutil="curl -fsSL https://christitus.com/linux | sh"

#######################################################
# SPECIAL FUNCTIONS
#######################################################
sdocker() {
    local ARG1="${1:-start}"

    if [ $ARG1 == "stop" ]; then
        systemctl disable docker.service
        systemctl stop docker.service
        systemctl disable docker.socket
        systemctl stop docker.socket
    else
        systemctl enable docker.service
        systemctl start docker.service
        systemctl enable docker.socket
        systemctl start docker.socket
    fi
}

# Extracts any archive(s) (if unp isn't installed)
extract() {
    for archive in "$@"; do
        if [ -f "$archive" ]; then
            # Get the filename without the directory path
            base=$(basename "$archive")

            case "$base" in
            *.tar.bz2)
                folder="${base%.tar.bz2}"
                mkdir -p "$folder"
                tar xvjf "$archive" -C "$folder"
            ;;
            *.tar.gz)
                folder="${base%.tar.gz}"
                mkdir -p "$folder"
                tar xvzf "$archive" -C "$folder"
            ;;
            *.bz2)
                folder="${base%.bz2}"
                mkdir -p "$folder"
                # Single compressed files stream output to a new file inside the folder
                bunzip2 -c "$archive" > "$folder/$folder"
            ;;
            *.rar)
                folder="${base%.rar}"
                mkdir -p "$folder"
                # rar needs a trailing slash to identify the destination as a directory
                rar x "$archive" "$folder/"
            ;;
            *.gz)
                folder="${base%.gz}"
                mkdir -p "$folder"
                gunzip -c "$archive" > "$folder/$folder"
            ;;
            *.tar)
                folder="${base%.tar}"
                mkdir -p "$folder"
                tar xvf "$archive" -C "$folder"
            ;;
            *.tbz2)
                folder="${base%.tbz2}"
                mkdir -p "$folder"
                tar xvjf "$archive" -C "$folder"
            ;;
            *.tgz)
                folder="${base%.tgz}"
                mkdir -p "$folder"
                tar xvzf "$archive" -C "$folder"
            ;;
            *.zip)
                folder="${base%.zip}"
                mkdir -p "$folder"
                unzip "$archive" -d "$folder"
            ;;
            *.Z)
                folder="${base%.Z}"
                mkdir -p "$folder"
                uncompress -c "$archive" > "$folder/$folder"
            ;;
            *.7z)
                folder="${base%.7z}"
                mkdir -p "$folder"
                # 7z requires no space between -o and the directory name
                7z x "$archive" -o"$folder"
            ;;
            *)
                echo "don't know how to extract '$archive'..."
            ;;
            esac
        else
            echo "'$archive' is not a valid file!"
        fi
    done
}
# Searches for text in all files in the current folder
ftext() {
    # -i case-insensitive
    # -I ignore binary files
    # -H causes filename to be printed
    # -r recursive search
    # -n causes line number to be printed
    # optional: -F treat search term as a literal, not a regular expression
    # optional: -l only print filenames and not the matching lines ex. grep -irl "$1" *
    grep -iIHrn --color=always "$1" . | less -r
}

# Copy file with a progress bar
cpp() {
    set -e
    strace -q -ewrite cp -- "${1}" "${2}" 2>&1 |
        awk '{
            count += $NF
            if (count % 10 == 0) {
                percent = count / total_size * 100
                printf "%3d%% [", percent
                for (i=0;i<=percent;i++) {
                    printf "="
                    printf ">"
                    for (i=percent;i<100;i++) {
                        printf " "
                        printf "]\r"
                    }
                }
            }
        }
        END { print "" }'
    total_size="$(stat -c '%s' "${1}")" count=0
}

# Copy and go to the directory
cpg() {
    if [ -d "$2" ]; then
        cp "$1" "$2" && cd "$2"
    else
        cp "$1" "$2"
    fi
}

# Move and go to the directory
mvg() {
    if [ -d "$2" ]; then
        mv "$1" "$2" && cd "$2"
    else
        mv "$1" "$2"
    fi
}

# Create and go to the directory
mkdirg() {
    mkdir -p "$1"
    cd "$1"
}

# Goes up a specified number of directories  (i.e. up 4)
up() {
    local d=""
    limit=$1
    for ((i = 1; i <= limit; i++)); do
        d=$d/..
    done
    d=$(echo $d | sed 's/^\///')
    if [ -z "$d" ]; then
        d=..
    fi
    cd $d
}

# Automatically do an ls after each cd, z, or zoxide
cd() {
    if [ -n "$1" ]; then
        builtin cd "$@" && ls
    else
        builtin cd ~ && ls
    fi
}

# Returns the last 2 fields of the working directory
pwdtail() {
    pwd | awk -F/ '{nlast = NF -1;print $nlast"/"$NF}'
}

# IP address lookup
alias whatismyip="whatsmyip"
function whatsmyip () {
    # Internal IP Lookup.
    if command -v ip &> /dev/null; then
        echo -n "Internal IP: "
        ip addr show wlan0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
    else
        echo -n "Internal IP: "
        ifconfig wlan0 | grep "inet " | awk '{print $2}'
    fi

    # External IP Lookup
    echo -n "External IP: "
    curl -4 ifconfig.me
}

# View Apache logs
apachelog() {
    if [ -f /etc/httpd/conf/httpd.conf ]; then
        cd /var/log/httpd && ls -xAh && multitail --no-repeat -c -s 2 /var/log/httpd/*_log
    else
        cd /var/log/apache2 && ls -xAh && multitail --no-repeat -c -s 2 /var/log/apache2/*.log
    fi
}

# Edit the Apache configuration
apacheconfig() {
    if [ -f /etc/httpd/conf/httpd.conf ]; then
        sudo nvim /etc/httpd/conf/httpd.conf
    elif [ -f /etc/apache2/apache2.conf ]; then
        sudo nvim /etc/apache2/apache2.conf
    else
        echo "Error: Apache config file could not be found."
        echo "Searching for possible locations:"
        sudo updatedb && locate httpd.conf && locate apache2.conf
    fi
}

# Edit the PHP configuration file
phpconfig() {
    if [ -f /etc/php.ini ]; then
        sudo nvim /etc/php.ini
    elif [ -f /etc/php/php.ini ]; then
        sudo nvim /etc/php/php.ini
    elif [ -f /etc/php5/php.ini ]; then
        sudo nvim /etc/php5/php.ini
    elif [ -f /usr/bin/php5/bin/php.ini ]; then
        sudo nvim /usr/bin/php5/bin/php.ini
    elif [ -f /etc/php5/apache2/php.ini ]; then
        sudo nvim /etc/php5/apache2/php.ini
    elif [ -f ~/.config/herd-lite/bin/php.ini ]; then
        sudo nvim ~/.config/herd-lite/bin/php.ini 
    else
        echo "Error: php.ini file could not be found."
        echo "Searching for possible locations:"
        sudo updatedb && locate php.ini
    fi
}

# Edit the MySQL configuration file
mysqlconfig() {
    if [ -f /etc/my.cnf ]; then
        sudo nvim /etc/my.cnf
    elif [ -f /etc/mysql/my.cnf ]; then
        sudo nvim /etc/mysql/my.cnf
    elif [ -f /usr/local/etc/my.cnf ]; then
        sudo nvim /usr/local/etc/my.cnf
    elif [ -f /usr/bin/mysql/my.cnf ]; then
        sudo nvim /usr/bin/mysql/my.cnf
    elif [ -f ~/my.cnf ]; then
        sudo nvim ~/my.cnf
    elif [ -f ~/.my.cnf ]; then
        sudo nvim ~/.my.cnf
    else
        echo "Error: my.cnf file could not be found."
        echo "Searching for possible locations:"
        sudo updatedb && locate my.cnf
    fi
}


# Trim leading and trailing spaces (for scripts)
trim() {
    local var=$*
    var="${var#"${var%%[![:space:]]*}"}" # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}" # remove trailing whitespace characters
    echo -n "$var"
}

# GitHub Titus Additions
gcom() {
    git add .
    git commit -m "$1"
}

lazyg() {
    git add .
    git commit -m "$1"
    git push
}

function hb {
    if [ $# -eq 0 ]; then
        echo "No file path specified."
        return
    elif [ ! -f "$1" ]; then
        echo "File path does not exist."
        return
    fi

    uri="http://bin.christitus.com/documents"
    response=$(curl -s -X POST -d @"$1" "$uri")
    if [ $? -eq 0 ]; then
        hasteKey=$(echo $response | jq -r '.key')
        echo "http://bin.christitus.com/$hasteKey"
    else
        echo "Failed to upload the document."
    fi
}

# Search from Home directory
fh() {
    local dir
    local cmd
    if command -v fd >/dev/null 2>&1; then cmd="fd";
    elif command -v fdfind >/dev/null 2>&1; then cmd="fdfind";
    fi
    if [[ -n "$cmd" ]]; then
        dir=$($cmd . /mnt/disk2/mythings . ~ --type d --hidden 2>/dev/null | fzf)
    else
        dir=$(find /mnt/disk2/mythings -maxdepth 6 -type d 2>/dev/null | fzf)
    fi

    # [ -n "$dir" ] ensures we only 'cd' if fzf actually returned a path
    [ -n "$dir" ] && cd "$dir"
}

# Search from Root (/) directory
fr() {
    local dir
    local cmd
    if command -v fd >/dev/null 2>&1; then cmd="fd";
    elif command -v fdfind >/dev/null 2>&1; then cmd="fdfind";
    fi
    if command -v fd >/dev/null 2>&1; then
        # Added --one-file-system to avoid hanging on network mounts or huge external drives
        dir=$($cmd . / --type d --hidden --one-file-system --exclude '{proc,dev,sys,run,tmp}' 2>/dev/null | fzf)
    else
        dir=$(find / -maxdepth 6 -type d 2>/dev/null | fzf)
    fi

    [ -n "$dir" ] && cd "$dir"
}

ytdlv() {
    local H=1080
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        H="$1"
        shift
    fi

    local DIR="/mnt/disk2/img-mp3-mp4/videos/youtube"
    if [[ -n "$1" && "$1" != http* ]]; then
        DIR="$1"
        shift
    fi

    mkdir -p "$DIR"

    ~/Downloads/yt-dlp \
        -f "bestvideo[height<=${H}]+bestaudio/best[height<=${H}]" \
        --cookies-from-browser brave \
        --extractor-args "youtube:player_client=default,-android_sdkless" \
        --embed-subs --sub-langs "en.*" \
        --merge-output-format mp4 \
        --download-archive "${DIR}/archive.txt" \
        --downloader-args "ffmpeg_i:-reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5" \
        -o "${DIR}/%(title).60s.%(ext)s" \
        "$@"
}

# how to use func ytdlm:
# option 1: ytdlm ~/Downloads/my_artwork.png https://youtube.com/watch...
# option 2: ytdlm 1 /my/music/folder art.jpg https://youtube.com/watch...
# option 3: ytdlm /my/music/folder ~/Pictures/album_art.jpg
ytdlm() {
    local dir="/mnt/disk2/img-mp3-mp4/musics"
    local crop_pos=2
    local gravity="Center"
    local custom_cover=""

    while [[ $# -gt 0 ]]; do
        if [[ "$1" =~ ^[123]$ ]]; then
            crop_pos="$1"
            shift
        elif [[ -f "$1" && "$1" =~ \.(jpg|jpeg|png|webp|JPG|JPEG|PNG|WEBP)$ ]]; then
            custom_cover="$1"
            shift
        elif [[ -n "$1" && "$1" != http* && "$1" != -* && -d "$1" ]]; then
            dir="$1"
            shift
        else
            # Break on the first yt-dlp argument or URL
            break
        fi
    done

    case "$crop_pos" in
        1) gravity="West" ;;   # Left
        2) gravity="Center" ;; # Center
        3) gravity="East" ;;   # Right
    esac

    local imgcmd
    if command -v magick >/dev/null 2>&1; then
        imgcmd="magick"
    elif command -v convert >/dev/null 2>&1; then
        imgcmd="convert"
    else
        echo "Error: Install ImageMagick (magick or convert command not found)" >&2
        return 1
    fi

    mkdir -p -- "$dir"

    local ytdlp_args=(
        -f 'ba[acodec^=mp3]/ba/b'
        -x --audio-format mp3
        -o "${dir}/%(title)s.%(ext)s"
    )

    # Only instruct yt-dlp to download a thumbnail if no custom cover is provided
    if [[ -z "$custom_cover" ]]; then
        ytdlp_args+=( --write-thumbnail --convert-thumbnails jpg )
    fi

    local target_files=()

    # If URLs/arguments are provided, download them and track ONLY the new files
    if [[ $# -gt 0 ]]; then
        local ref_file="${dir}/.ytdlm_run_time"
        touch "$ref_file"

        yt-dlp "${ytdlp_args[@]}" "$@"

        while IFS= read -r -d '' file; do
            target_files+=("$file")
        done < <(find "$dir" -maxdepth 1 -name "*.mp3" -newer "$ref_file" -print0)

        \rm -f "$ref_file"
    fi

    if [[ ${#target_files[@]} -eq 0 ]]; then
        echo "No new MP3 files were downloaded or found to process."
        return 0
    fi

    local mp3 base jpg webp thumb
    for mp3 in "${target_files[@]}"; do
        base="${mp3%.mp3}"
        jpg="${base}.jpg"
        webp="${base}.webp"
        thumb=""

        # Determine which image to use for the cover art
        if [[ -n "$custom_cover" && -f "$custom_cover" ]]; then
            thumb="${base}_custom.jpg"
            "$imgcmd" "$custom_cover" "$thumb" || continue
        elif [[ -f "$jpg" ]]; then
            thumb="$jpg"
        elif [[ -f "$webp" ]]; then
            thumb="${base}_tmp.jpg"
            "$imgcmd" "$webp" "$thumb" || continue
        else
            continue # No thumbnail found and no custom cover provided
        fi

        "$imgcmd" "$thumb"             \
            -fuzz 5% -trim +repage     \
            -filter Lanczos            \
            -resize '1080x1080^'       \
            -gravity "$gravity"        \
            -extent 1080x1080          \
            -quality 100               \
            "$thumb" || { echo "Failed to crop $thumb"; continue; }

        ffmpeg -y -v quiet -i "$mp3" -i "$thumb" -map 0:0 -map 1:0 -c copy \
            -id3v2_version 3 -metadata:s:v title="Album cover" \
            -metadata:s:v comment="Cover (front)" \
            -disposition:v attached_pic "${base}_tmp.mp3"

        if [[ -f "${base}_tmp.mp3" ]]; then
            mv -f "${base}_tmp.mp3" "$mp3"
            \rm -f "$jpg" "$webp" "${base}_tmp.jpg" "${base}_custom.jpg"
        else
            echo "Warning: FFmpeg failed to embed artwork for $mp3"
            \rm -f "${base}_tmp.jpg" "${base}_custom.jpg"
        fi
    done

    if [[ -d "$HOME/.cache/thumbnails" ]]; then
        \rm -rf "$HOME/.cache/thumbnails"/*
        echo "System thumbnails cache cleared."
    fi

    echo "Done!"
}

runPlaylist() {
    local dir="/mnt/disk2/img-mp3-mp4/musics"

    if [ ! -d "$dir" ]; then
        echo "Directory not found."
        return 1
    fi

    rm -f "$dir/playlist.m3u"

    shopt -s nullglob nocaseglob
    local files=("$dir"/*.mp3 "$dir"/*.mp4 "$dir"/*.m4a "$dir"/*.flac "$dir"/*.wav)
    shopt -u nullglob nocaseglob

    if ((${#files[@]} == 0)); then
        echo "Directory is empty."
        return 1
    fi

    printf '%s\n' "${files[@]}" > "$dir/playlist.m3u"

    mpv --terminal=yes --loop-playlist=inf "$dir/playlist.m3u"
    # mpv --loop-playlist=inf --shuffle "$dir/playlist.m3u"
}

vmrss() { grep VmRSS /proc/"$1"/status; }

caveman_skill_copy() {
    cat ~/.config/opencode/skills/caveman+review/SKILL.md | wl-copy
}

trunclog() {
    local files=("$@")
    ((${#files[@]} == 0)) && mapfile -t files < <(fd -H -e log . '/' 2>/dev/null)
        for f in "${files[@]}"; do
            local sz=$(wc -c < "$f")
            printf "[Before %d] %s\n" "$sz" "$f"
            ((sz > 10240)) && sudo truncate -s 10240 "$f"
            printf "[After >%d]\n" $(wc -c < "$f")
        done
}

#######################################################
# Set the ultimate amazing command prompt
#######################################################

alias hug="systemctl --user restart hugo"
alias lanm="systemctl --user restart lan-mouse"

# Check if the shell is interactive
if [[ $- == *i* ]]; then
    # Bind Ctrl+f to insert 'zi' followed by a newline
    bind '"\C-f":"zi\n"'
fi

eval "$(starship init bash)"
eval "$(zoxide init bash)"

#######################################################
# EXPORTS ENV
#######################################################
export ANDROID_SDK_ROOT="$HOME/opt_at_home/Android/Sdk/"
export ANDROID_AVD_HOME="$HOME/.config/.android/avd"
export PHP_INI_SCAN_DIR="$HOME/.config/herd-lite/bin:$PHP_INI_SCAN_DIR"
export JAVA_HOME="$HOME/opt_at_home/jdk-21-0-11/"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/opt_at_home/SDL3/include:$PATH"
export PATH="$HOME/opt_at_home/flutter/bin:$PATH"
export PATH="$HOME/.config/herd-lite/bin:$PATH"
# export PATH="$HOME/opt_at_home/platform-tools/:$PATH"
export PATH="$PATH:$ANDROID_SDK_ROOT/platform-tools
                  :$ANDROID_SDK_ROOT/cmdline-tools/latest/bin
                  :$ANDROID_SDK_ROOT/emulator"
export PATH="$JAVA_HOME/bin:$PATH"
export PATH="$HOME/.pub-cache/bin:$PATH"
export LIBVIRT_DEFAULT_URI="qemu:///system"
export DOTNET_ROOT="$HOME/.dotnet"
export DOTNET_ROOT_X64="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"
