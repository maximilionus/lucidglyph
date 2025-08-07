#!/bin/bash

# Main script to install and control lucidglyph.
# Copyright (C) 2023-2025  Max Gashutin <maximilionuss@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

set -e

NAME="lucidglyph"
VERSION="0.11.1"
SRC_DIR=src

# Display the header with project name and version on start
SHOW_HEADER=${SHOW_HEADER:=true}

# Marker for tracking appended content
MARKER_START="### START OF LUCIDGLYPH $VERSION CONTENT ###"
MARKER_WARNING="# !! DO NOT PUT ANY USER CONFIGURATIONS INSIDE THIS BLOCK !!"
MARKER_END="### END OF LUCIDGLYPH $VERSION CONTENT ###"

# Filesystem
DEST_CONF="${DESTDIR:-}${DEST_CONF:-/etc}"
DEST_USR="${DESTDIR:-}${DEST_USR:-/usr}"

DEST_CONF_USR="${DESTDIR:-$HOME}${DEST_CONF_USR:-/.config}"
DEST_USR_USR="${DESTDIR:-$HOME}${DEST_USR_USR:-/.local}"

# environment
ENVIRONMENT_DIR="$SRC_DIR/environment"
DEST_ENVIRONMENT="$DEST_CONF/environment"

# fontconfig
FONTCONFIG_DIR="$SRC_DIR/fontconfig"
DEST_FONTCONFIG_DIR="$DEST_CONF/fonts/conf.d"
DEST_FONTCONFIG_DIR_USR="$DEST_CONF_USR/fontconfig/conf.d"

# Metadata location
DEST_SHARED_DIR="$DEST_USR/share/lucidglyph"
DEST_SHARED_DIR_OLD="$DEST_USR/share/freetype-envision"  # TODO: Remove on 1.0.0
DEST_SHARED_DIR_USR="$DEST_USR_USR/share/lucidglyph"
DEST_INFO_FILE="info"
DEST_UNINSTALL_FILE="uninstaller.sh"

# Colors
C_RESET="\e[0m"
C_BOLD="\e[1m"
C_DIM="\e[2m"
C_GREEN="\e[0;32m"
C_YELLOW="\e[0;33m"
C_RED="\e[0;31m"

# Global variables
declare -A INSTALL_METADATA
declare IS_PER_USER=false


# Check if version $2 >= $1
verlte() {
    [  "$1" = "`echo -e \"$1\n$2\" | sort -V | head -n1`" ]
}

# Check if version $2 > $1
verlt() {
    [ "$1" = "$2" ] && return 1 || verlte $1 $2
}

ask_confirmation() {
    notification="$1"
    read -p "$notification (Y/n): "
    printf "\n"
    [[ ! $REPLY =~ ^[Nn]$ ]]
}

check_root () {
    if [[ $(/usr/bin/id -u) != 0 ]] && ! $IS_PER_USER; then
        printf "${C_RED}This action requires the root privileges${C_RESET}\n"
        exit 1
    elif [[ $(/usr/bin/id -u) == 0 ]] && $IS_PER_USER; then
        printf "${C_YELLOW}"
        cat <<EOF
Warning: You are trying to run the per-user operational mode under the root
user. This is probably a mistake, as it will result in the utility only working
with root user configurations.
EOF
        printf "${C_RESET}"
    fi
}

# Get configuration path the for current user's shell.
# Prefers *profile over *rc.
#
# USAGE
#     shell_conf="$(get_shell_conf)"
get_shell_conf() {
    local shell="$(basename $SHELL 2>/dev/null)"
    case "$shell" in
        bash)
            echo "${DESTDIR:-$HOME}/.bash_profile"
            ;;
        zsh)
            echo "${DESTDIR:-$HOME}/.zprofile"
            ;;
        # fish)  # TODO: Implement fish handling
        #     echo "${DESTDIR:-$HOME}/.config/fish/config.fish"
        #     ;;
        ksh)
            echo "${DESTDIR:-$HOME}/.profile"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Parse and load the installation information
load_info_file () {
    if [[ ! -f $DEST_SHARED_DIR/$DEST_INFO_FILE ]]; then
        return 0
    fi

    while read -r line; do
        # Parse all key="value"
        regex='^([a-zA-Z_][a-zA-Z0-9_]*)="([^"]*)"$'

        if [[ $line =~ $regex ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            INSTALL_METADATA["$key"]="$value"
        else
            printf "${C_YELLOW}Warning: Skipping invalid info file line '$line'${C_RESET}\n"
        fi
    done < "$DEST_SHARED_DIR/$DEST_INFO_FILE"
}

# Check for old versions and adapt the script logics
# TODO Remove on 1.0.0
backward_compatibility () {
    # Not required for per-user mode
    if $IS_PER_USER; then return 0; fi

    if (( ! ${#INSTALL_METADATA[@]} )); then
        if [[ -f "$DEST_SHARED_DIR_OLD/$DEST_INFO_FILE" ]]; then
            # Load the 0.7.0 state file
            local temp="$DEST_SHARED_DIR"
            DEST_SHARED_DIR="$DEST_SHARED_DIR_OLD"
            load_info_file
            DEST_SHARED_DIR="$temp"
        elif compgen -G "$DEST_FONTCONFIG_DIR/*freetype-envision*" > /dev/null \
            || compgen -G "$DEST_FONTCONFIG_DIR/*$NAME*" > /dev/null; then
            cat <<EOF
Project is already installed on the system, presumably with package manager or
an installation script of the version below '0.7.0', that does not support the
automatic removal. You have to uninstall it using the original installation
method first.
EOF
            exit 1
        fi
    fi
}

# Call the locally stored uninstaller from target machine
call_uninstaller () {
    local shared_dir="$DEST_SHARED_DIR"

    if verlt ${INSTALL_METADATA[version]} "0.8.0"; then
        # Backward compatibility with version 0.7.0
        # (Before the project rename)
        # TODO: Remove on 1.0.0
        shared_dir="$DEST_SHARED_DIR_OLD"
    fi

    if [[ ! -f $shared_dir/$DEST_UNINSTALL_FILE ]]; then
        printf "${C_RED}Uninstaller script not found, installation corrupted${C_RESET}"
        exit 1
    fi

    "$shared_dir/$DEST_UNINSTALL_FILE"
}

show_header () {
    printf "${C_BOLD}$NAME, version $VERSION${C_RESET}\n"
}

cmd_help () {
    cat <<EOF
usage: $0 [OPTIONS] [COMMAND]

Tuning the Linux font rendering stack for a more visually pleasing output.

For further information and usage details, please refer to the project
documentation.

COMMANDS:
  install  Install, reinstall or upgrade the project
  remove   Remove the installed project
  help     Show this help message

OPTIONS:
  -s, --system (default)  Operate in system mode
  -u, --user              Operate in user mode (experimental feature)
EOF
}

cmd_install () {
    load_info_file
    backward_compatibility

    if [[ ${INSTALL_METADATA[version]} == $VERSION ]]; then
        printf "${C_GREEN}Current version is already installed.${C_RESET}\n"

        if ask_confirmation "Do you wish to reinstall it?"; then
            check_root
            call_uninstaller
        else
            exit 0
        fi
    elif [[ ! -z ${INSTALL_METADATA[version]} ]]; then
        printf "${C_GREEN}Detected $NAME version ${INSTALL_METADATA[version]} on the target system.${C_RESET}\n"

        if ask_confirmation "Do you wish to upgrade to version $VERSION?"; then
            check_root
            call_uninstaller
        else
            exit 1
        fi
    else
        check_root
    fi

    printf "Setting up\n"
    printf -- "- %-40s%s" "Storing the installation metadata"
    mkdir -p "$DEST_SHARED_DIR"
    touch "$DEST_SHARED_DIR/$DEST_INFO_FILE"
    touch "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
    chmod +x "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
    printf "${C_GREEN}Done${C_RESET}\n"

    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_INFO_FILE"
version="$VERSION"
is_user_mode="$IS_PER_USER"
EOF
    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
#!/bin/bash
set -e
printf "Using uninstaller for version ${C_BOLD}$VERSION${C_RESET}\n"
printf -- "- %-40s%s" "Removing the installation metadata "
rm -rf "$DEST_SHARED_DIR"
EOF
    if $IS_PER_USER; then
        cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
rm -d "$(dirname $DEST_SHARED_DIR)" 2>/dev/null || true
rm -d "$(dirname $(dirname $DEST_SHARED_DIR))" 2>/dev/null || true
EOF
    fi
    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
printf "${C_GREEN}Done${C_RESET}\n"
EOF

    printf -- "- %-40s%s" "Appending the environment entries "

    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
printf -- "- %-40s%s" "Cleaning the environment entries "
sed -i "/$MARKER_START/,/$MARKER_END/d" "$DEST_ENVIRONMENT"
EOF
    if $IS_PER_USER; then
        cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
[[ ! -s $DEST_ENVIRONMENT ]] && rm -f "$DEST_ENVIRONMENT"
EOF
    fi
    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
printf "${C_GREEN}Done${C_RESET}\n"
EOF

    if ! $IS_PER_USER; then [[ ! -d $DEST_CONF ]] && mkdir -p "$DEST_CONF"; fi

    {
        printf "$MARKER_START\n"
        printf "$MARKER_WARNING\n"

        prefix=""
        if $IS_PER_USER; then
            case "$SHELL" in
                # *fish)  prefix="set --export " ;;  # TODO
                *)      prefix="export " ;;
            esac
        fi

        for f in $ENVIRONMENT_DIR/*.conf; do
            printf "$prefix"
            cat "$f"
        done

        printf "$MARKER_END\n"
    } >> "$DEST_ENVIRONMENT"

    printf "${C_GREEN}Done${C_RESET}\n"

    printf -- "- %-40s%s" "Installing the fontconfig rules "
    mkdir -p "$DEST_FONTCONFIG_DIR"

    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
printf -- "- %-40s%s" "Removing the fontconfig rules "
EOF

    for f in $FONTCONFIG_DIR/*.conf; do
        install -m 644 "$f" "$DEST_FONTCONFIG_DIR/$(basename $f)"
        cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
rm -f "$DEST_FONTCONFIG_DIR/$(basename $f)"
EOF
    done

    if $IS_PER_USER; then
        cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
rm -d "$DEST_FONTCONFIG_DIR" 2>/dev/null || true
rm -d "$(dirname $DEST_FONTCONFIG_DIR)" 2>/dev/null || true
rm -d "$(dirname $(dirname $DEST_FONTCONFIG_DIR))" 2>/dev/null || true
EOF
    fi

    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
printf "${C_GREEN}Done${C_RESET}\n"
EOF
    printf "${C_GREEN}Done${C_RESET}\n"
    printf "${C_GREEN}Success!${C_RESET} Reboot to apply the changes.\n"
}

cmd_remove () {
    load_info_file
    backward_compatibility

    if (( ! ${#INSTALL_METADATA[@]} )); then
        printf "${C_RED}Project is not installed.${C_RESET}\n"
        exit 1
    fi

    check_root
    printf "Removing\n"
    call_uninstaller

    printf "${C_GREEN}Success!${C_RESET} Reboot to apply the changes.\n"
}


# Execution

[[ $SHOW_HEADER = true ]] && show_header

# Parse optional args
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--system)
            IS_PER_USER=false
            shift
            ;;
        -u|--user)
            IS_PER_USER=true
            shift
            ;;
        -*|--*)
            printf "${C_YELLOW}Unknown option${C_RESET} $1\n"
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}"
unset POSITIONAL_ARGS

# Deprecate short commands.
# TODO: Remove in 1.0.0
case "$1" in
    i|r|h)
        printf "$C_YELLOW"
        cat <<EOF
--------
Warning: Arguments 'i', 'r' and 'h' (short commands) are considered deprecated
from version '0.5.0' and will be removed in '1.0.0' project release.
--------
EOF
        printf "$C_RESET"
        ;;
esac

# Deprecate project modes
# TODO: Remove in 1.0.0
if [[ $2 =~ ^(normal|full)$ ]]; then
    printf "$C_YELLOW"
    cat <<EOF
--------
Warning: Arguments 'normal' and 'full' (mode selection) are considered
deprecated from version '0.7.0' and will be removed in '1.0.0' project release.

Only one mode is available from now on. Please avoid providing the second
argument.

Whatever argument is specified in this call now will result in a normal mode
installation.
--------
EOF
    printf "$C_RESET"
fi

# Check system compatibility
if [[ $( uname -s ) != Linux* ]]; then
    printf "$C_YELLOW"
    cat <<EOF
Warning: You are trying to run this script on the unsupported platform. Proceed
at your own risk.

EOF
    printf "$C_RESET"
    if ! ask_confirmation "Do you wish to continue?"; then
        exit 1
    fi
fi

if $IS_PER_USER; then
    shell_config="$(get_shell_conf)"
    if [[ -z $shell_config ]]; then
        printf "${C_RED}"
        cat <<EOF
Per-user operational mode is only supported on bash, zsh and ksh shells.
EOF
        printf "${C_RESET}"
        exit 1
    fi

    DEST_ENVIRONMENT="$shell_config"
    DEST_FONTCONFIG_DIR="$DEST_FONTCONFIG_DIR_USR"
    DEST_SHARED_DIR="$DEST_SHARED_DIR_USR"
fi


# Parse main args
case $1 in
    # "i" is deprecated
    # TODO: Remove in 1.0.0
    i|install)
        cmd_install
        ;;
    # "r" is deprecated
    # TODO: Remove in 1.0.0
    r|remove)
        cmd_remove
        ;;
    # "h" is deprecated
    # TODO: Remove in 1.0.0
    h|""|help)
        cmd_help
        ;;
    *)
        printf "${C_RED}Unknown command${C_RESET} $1\n"
        printf "Use ${C_BOLD}help${C_RESET} command to get usage information\n"
        exit 1
esac
