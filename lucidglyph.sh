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
VERSION="0.9.1"
SRC_DIR=src

# Display the header with project name and version on start
SHOW_HEADER=${SHOW_HEADER:=true}

# Marker for tracking appended content
MARKER_START="### START OF LUCIDGLYPH $VERSION CONTENT ###"
MARKER_END="### END OF LUCIDGLYPH $VERSION CONTENT ###"

# environment
ENVIRONMENT_DIR="$SRC_DIR/environment"
DEST_ENVIRONMENT="/etc/environment"

# fontconfig
FONTCONFIG_DIR="$SRC_DIR/fontconfig"
DEST_FONTCONFIG_DIR="/etc/fonts/conf.d"
#                    ("<NAME>" "<PRIORITY>")
FONTCONFIG_GRAYSCALE=("lucidglyph-grayscale.conf" 11)
FONTCONFIG_DROID_SANS=("lucidglyph-droid-sans.conf" 70)

# Metadata location
DEST_SHARED_DIR="/usr/share/lucidglyph"
DEST_SHARED_DIR_OLD="/usr/share/freetype-envision"
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
declare -A local_info


require_root () {
    if [[ $(/usr/bin/id -u) -ne 0 ]]; then
        printf "${C_RED}This action requires the root privileges${C_RESET}\n"
        exit 1
    fi
}

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
            local_info["$key"]="$value"
        else
            printf "${C_YELLOW}Warning: Skipping invalid info file line '$line'${C_RESET}\n"
        fi
    done < "$DEST_SHARED_DIR/$DEST_INFO_FILE"
}

# Check for old versions and adapt the script logics
# TODO Remove on 1.0.0
backward_compatibility () {
    if (( ! ${#local_info[@]} )); then
        if [[ -f "$DEST_SHARED_DIR_OLD/$DEST_INFO_FILE" ]]; then
            # Load the 0.7.0 state file
            local temp="$DEST_SHARED_DIR"
            DEST_SHARED_DIR="$DEST_SHARED_DIR_OLD"
            load_info_file
            DEST_SHARED_DIR="$temp"
        elif ls $DEST_FONTCONFIG_DIR/*freetype-envision* > /dev/null 2>&1; then
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

check_system () {
    if [[ $( uname -s ) != Linux* ]]; then
        printf "$C_YELLOW"
        cat <<EOF
You are trying to run this script on the unsupported platform.
Proceed at your own risk.

EOF
        printf "$C_RESET"
        if ! ask_confirmation "Do you wish to continue?"; then
            exit 1
        fi
    fi
}

# Call the locally stored uninstaller from target machine
call_uninstaller () {
    local shared_dir="$DEST_SHARED_DIR"

    if verlt ${local_info[version]} "0.8.0"; then
        # Backwards compatibility with version 0.7.0
        # (Before the project rename)
        # TODO: Remove on 1.0.0
        shared_dir="$DEST_SHARED_DIR_OLD"
    fi

    if [[ ! -f "$shared_dir/$DEST_UNINSTALL_FILE" ]]; then
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
Usage: $0 [COMMAND]

Carefully tuned adjustments designed to improve font rendering on Linux

COMMANDS:
  install  Install or upgrade the project
  remove   Remove the installed project
  help     Show this help message
EOF
}

cmd_install () {
    load_info_file
    backward_compatibility

    if [[ ${local_info[version]} == "$VERSION" ]]; then
        printf "${C_GREEN}Current version is already installed.${C_RESET}\n"
        exit 1
    elif [[ ! -z ${local_info[version]} ]]; then
        printf "${C_GREEN}Detected $NAME version ${local_info[version]} on the target system.${C_RESET}\n"
        require_root
        if ask_confirmation "Do you wish to upgrade to version $VERSION?"; then
            call_uninstaller
        else
            exit 1
        fi
    else
        require_root
    fi

    printf "Setting up\n"
    printf -- "- Storing the installation metadata "
    mkdir -p "$DEST_SHARED_DIR"
    touch "$DEST_SHARED_DIR/$DEST_INFO_FILE"
    touch "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
    chmod +x "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
    printf "${C_GREEN}Done${C_RESET}\n"

    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_INFO_FILE"
version="$VERSION"
EOF
    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
#!/bin/bash
set -e
printf "Using uninstaller for version ${C_BOLD}$VERSION${C_RESET}\n"
printf -- "- Removing the metadata "
rm -rf "$DEST_SHARED_DIR"
printf "${C_GREEN}Done${C_RESET}\n"
EOF

    printf -- "- Appending the environment entries "
    {
        echo "$MARKER_START"
        for f in $ENVIRONMENT_DIR/*.sh; do
            cat "$f"
        done
        echo "$MARKER_END"
    } >> "$DEST_ENVIRONMENT"

    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
printf -- "- Cleaning the environment entries "
sed -i "/$MARKER_START/,/$MARKER_END/d" "$DEST_ENVIRONMENT"
printf "${C_GREEN}Done${C_RESET}\n"
EOF
    printf "${C_GREEN}Done${C_RESET}\n"

    printf -- "- Installing the fontconfig rules "
    install -m 644 \
        "$FONTCONFIG_DIR/${FONTCONFIG_GRAYSCALE[0]}" \
        "$DEST_FONTCONFIG_DIR/${FONTCONFIG_GRAYSCALE[1]}-${FONTCONFIG_GRAYSCALE[0]}"
    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
printf -- "- Removing the fontconfig rules "
rm -f "$DEST_FONTCONFIG_DIR/${FONTCONFIG_GRAYSCALE[1]}-${FONTCONFIG_GRAYSCALE[0]}"
printf "${C_GREEN}Done${C_RESET}\n"
EOF

    install -m 644 \
        "$FONTCONFIG_DIR/${FONTCONFIG_DROID_SANS[0]}" \
        "$DEST_FONTCONFIG_DIR/${FONTCONFIG_DROID_SANS[1]}-${FONTCONFIG_DROID_SANS[0]}"
    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
rm -f "$DEST_FONTCONFIG_DIR/${FONTCONFIG_DROID_SANS[1]}-${FONTCONFIG_DROID_SANS[0]}"
EOF
    printf "${C_GREEN}Done${C_RESET}\n"

    cat <<EOF >> "$DEST_SHARED_DIR/$DEST_UNINSTALL_FILE"
printf "${C_BOLD}Successful removal${C_RESET}\n"
EOF

    printf "${C_GREEN}Success!${C_RESET} Reboot to apply the changes.\n"
}

cmd_remove () {
    load_info_file
    backward_compatibility

    if (( ! ${#local_info[@]} )); then
        printf "${C_RED}Project is not installed.${C_RESET}\n"
        exit 1
    fi

    require_root
    printf "Removing\n"
    call_uninstaller

    printf "${C_GREEN}Success!${C_RESET} Reboot to apply the changes.\n"
}


# Main logics

[[ $SHOW_HEADER = true ]] && show_header
check_system

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
