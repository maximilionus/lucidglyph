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

set -eo pipefail


NAME="lucidglyph"
VERSION="0.13.0"
SRC_DIR=src

# Display the header with project name and version on start
SHOW_HEADER=${SHOW_HEADER:-true}
BLACKLISTED_MODULES="${BLACKLISTED_MODULES:-}"

# Filesystem configuration
DEST_CONF="${DESTDIR:-}${DEST_CONF:-/etc}"
DEST_USR="${DESTDIR:-}${DEST_USR:-/usr/local}"
DEST_USR_OLD_BEFORE_0_13_0="${DESTDIR:-}/usr"  # TODO: Remove on 1.0.0

DEST_CONF_USR="${DESTDIR:-$HOME}${DEST_CONF_USR:-/.config}"
DEST_USR_USR="${DESTDIR:-$HOME}${DEST_USR_USR:-/.local}"

# Metadata group
#     Installation information and uninstaller script.
#
#     Disable this group when used in package manager.
ENABLE_METADATA=${ENABLE_METADATA:=true}  # Set this env variable to false
                                          # to completely disable this group.

DEST_LIB_DIR="$DEST_USR/lib/lucidglyph"
DEST_SHARED_DIR="$DEST_USR/share/lucidglyph"
DEST_SHARED_DIR_OLD_BEFORE_0_8_0="$DEST_USR_OLD_BEFORE_0_13_0/share/freetype-envision"  # TODO: Remove on 1.0.0
DEST_SHARED_DIR_OLD_BEFORE_0_13_0="$DEST_USR_OLD_BEFORE_0_13_0/share/lucidglyph"  # TODO: Remove on 1.0.0
DEST_SHARED_DIR_USR="$DEST_USR_USR/share/lucidglyph"
DEST_INFO_FILE="info"
DEST_UNINSTALL_FILE="uninstaller.sh"

# Environment group
#     Variables that need to be exported to the system environment.
ENABLE_ENVIRONMENT=${ENABLE_ENVIRONMENT:=true}  # Set this env variable to false
                                                # to completely disable this group.
ENVIRONMENT_DIR="$SRC_DIR/environment"
DEST_ENVIRONMENT="$DEST_CONF/environment"

# Fontconfig group
ENABLE_FONTCONFIG=${ENABLE_FONTCONFIG:=true}  # Set this env variable to false
                                              # to completely disable this group.
FONTCONFIG_DIR="$SRC_DIR/fontconfig"
DEST_FONTCONFIG_DIR="$DEST_CONF/fonts/conf.d"
DEST_FONTCONFIG_DIR_USR="$DEST_CONF_USR/fontconfig/conf.d"

# Colors
C_RESET="\e[0m"
C_BOLD="\e[1m"
C_DIM="\e[2m"
C_GREEN="\e[0;32m"
C_YELLOW="\e[0;33m"
C_RED="\e[0;31m"

# Marker for tracking the appended content
MARKER_START="### START OF LUCIDGLYPH $VERSION CONTENT ###"
MARKER_WARNING="# !! DO NOT PUT ANY USER CONFIGURATIONS INSIDE THIS BLOCK !!"
MARKER_END="### END OF LUCIDGLYPH $VERSION CONTENT ###"

# Global variables
declare -A G_INFO
declare -a blacklisted_modules=()  # Internal module blacklist
declare G_IS_PER_USER=false


# Check if version $2 >= $1
verlte() {
    [  "$1" = "`echo -e \"$1\n$2\" | sort -V | head -n1`" ]
}

# Check if version $2 > $1
verlt() {
    [ "$1" = "$2" ] && return 1 || verlte $1 $2
}

ask_confirmation() {
    message="$1"
    read -p "$message (Y/n): "
    printf "\n"
    [[ ! $REPLY =~ ^[Nn]$ ]]
}

show_header () {
    printf "${C_BOLD}$NAME, version $VERSION${C_RESET}\n"
}

check_root () {
    if [[ $(/usr/bin/id -u) != 0 ]] &&  [[ $G_IS_PER_USER == false ]]; then
        printf "${C_RED}This action requires the root privileges${C_RESET}\n"
        exit 1
    elif [[ $(/usr/bin/id -u) == 0 ]] && [[ $G_IS_PER_USER == true ]]; then
        printf "${C_YELLOW}"
        cat <<EOF
Warning: You are attempting to perform a per-user operation as the root user.
This is probably a mistake, as it will cause the utility to work with the root
user instead of the regular user. Please confirm that this is intentional.
EOF
        printf "${C_RESET}"

        if ! ask_confirmation "Do you wish to continue?"; then
            exit 1
        fi
    fi
}

load_mod_blacklist() {
    if (( ${#blacklisted_modules[@]} != 0 )); then
        printf "${C_DIM}Internally blacklisted modules:\n"
        printf '    %s\n' "${blacklisted_modules[@]}"
        printf "$C_RESET"
    fi

    if [[ -n "$BLACKLISTED_MODULES" ]]; then
        read -r -a user_blacklist <<< "$BLACKLISTED_MODULES"
        blacklisted_modules=("${blacklisted_modules[@]}" "${user_blacklist[@]}")

        printf "${C_DIM}Externally blacklisted modules:\n"
        printf '    %s\n' "${user_blacklist[@]}"
        printf "$C_RESET"
    fi
}

# Check if the module is blacklisted both internally and externally.
#
# ARGUMENTS:
# 1 - Relative path to the module file (with or without $SRC_DIR).
is_mod_blacklisted() {
    local module="${1#$SRC_DIR/}"

    for i in "${blacklisted_modules[@]}"; do
        if  [[ "$i" == "$module" ]]; then
            return 0
        fi
    done

    return 1
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
    local info_file_path="$DEST_SHARED_DIR/$DEST_INFO_FILE"

    [[ $ENABLE_METADATA == false ]] && return 0

    if [[ ! -f "$info_file_path" ]]; then
        # Backwards compatibility
        # TODO: Remove on 1.0.0
        if [[ -f "$DEST_SHARED_DIR_OLD_BEFORE_0_13_0/$DEST_INFO_FILE" ]]; then
            # Load the <0.13.0 info file
            info_file_path="$DEST_SHARED_DIR_OLD_BEFORE_0_13_0/$DEST_INFO_FILE"
        elif [[ -f "$DEST_SHARED_DIR_OLD_BEFORE_0_8_0/$DEST_INFO_FILE" ]]; then
            # Load the 0.7.0 state (info) file
            info_file_path="$DEST_SHARED_DIR_OLD_BEFORE_0_8_0/$DEST_INFO_FILE"
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

    [[ ! -f "$info_file_path" ]] && return 0

    # Parse the local file
    while read -r line; do
        # Parse all key="value"
        regex='^([a-zA-Z_][a-zA-Z0-9_]*)="([^"]*)"$'

        if [[ $line =~ $regex ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            G_INFO["$key"]="$value"
        else
            printf "${C_YELLOW}Warning: Skipping the invalid metadata entry:${C_RESET} \"$line\".\n"
        fi
    done < "$info_file_path"

    # Preserve the settings from previous install, only on upgrade
    #
    # TODO: Needs improvement in detecting user-provided env. variables, so it
    # doesn't forcefully overwrite them with info file ones.
    [[ -n "${G_INFO[ext_blacklisted_modules]}" ]] &&
        BLACKLISTED_MODULES="${G_INFO[ext_blacklisted_modules]}"

    ENABLE_ENVIRONMENT="${G_INFO[enable_environment]:-$ENABLE_ENVIRONMENT}"
    ENABLE_FONTCONFIG="${G_INFO[enable_fontconfig]:-$ENABLE_FONTCONFIG}"
}

# Append the redirected content to metadata files.
# Only works if ENABLE_METADATA is set to true.
append_metadata () {
    local mode="$1"

    [[ $ENABLE_METADATA == false ]] && return 0

    local path=""
    case "$mode" in
        info) path="$DEST_SHARED_DIR/$DEST_INFO_FILE" ;;
        uninstall) path="$DEST_LIB_DIR/$DEST_UNINSTALL_FILE" ;;
        *) printf "${C_YELLOW}Warning: append_metadata wrong argument.${C_RESET}" ;;
    esac

    cat >> "$path"
}

install_metadata () {
    printf -- "- %-40s%s" "Storing the installation metadata"

    if [[ $ENABLE_METADATA == false ]]; then
        printf "${C_YELLOW}Disabled${C_RESET}\n"
        return 0
    fi

    mkdir -p "$DEST_SHARED_DIR"
    touch "$DEST_SHARED_DIR/$DEST_INFO_FILE"

    mkdir -p "$DEST_LIB_DIR"
    touch "$DEST_LIB_DIR/$DEST_UNINSTALL_FILE"
    chmod +x "$DEST_LIB_DIR/$DEST_UNINSTALL_FILE"
    printf "${C_GREEN}Done${C_RESET}\n"

    append_metadata info <<EOF
version="$VERSION"
ext_blacklisted_modules="${BLACKLISTED_MODULES[@]}"
enable_environment="$ENABLE_ENVIRONMENT"
enable_fontconfig="$ENABLE_FONTCONFIG"
EOF
    append_metadata uninstall <<EOF
#!/bin/bash
set -e
printf "Using uninstaller for version ${C_BOLD}$VERSION${C_RESET}\n"
printf -- "- %-40s%s" "Removing the installation metadata "
rm -rf "$DEST_SHARED_DIR"
rm -rf "$DEST_LIB_DIR"
EOF
    # Get parent since shared dir already removed
    [[ $G_IS_PER_USER == true ]] && append_metadata uninstall <<EOF
rmdir --ignore-fail-on-non-empty -p "$(dirname $DEST_SHARED_DIR)"
EOF
    append_metadata uninstall <<EOF
printf "${C_GREEN}Done${C_RESET}\n"
EOF
}

install_environment () {
    printf -- "- %-40s%s" "Appending the environment entries "

    if [[ $ENABLE_ENVIRONMENT == false ]]; then
        printf "${C_YELLOW}Disabled${C_RESET}\n"
        return 0
    fi

    append_metadata uninstall <<EOF
printf -- "- %-40s%s" "Cleaning the environment entries "
sed -i "/$MARKER_START/,/$MARKER_END/d" "$DEST_ENVIRONMENT"
EOF
    [[ $G_IS_PER_USER == true ]] && append_metadata uninstall <<EOF
[[ ! -s $DEST_ENVIRONMENT ]] && rm -f "$DEST_ENVIRONMENT"
EOF
    append_metadata uninstall <<EOF
printf "${C_GREEN}Done${C_RESET}\n"
EOF

    if [[ $G_IS_PER_USER == false ]] && [[ ! -d $DEST_CONF ]]; then mkdir -p "$DEST_CONF"; fi

    {
        printf "$MARKER_START\n"
        printf "$MARKER_WARNING\n"

        prefix=""
        if [[ $G_IS_PER_USER == true ]]; then
            case "$SHELL" in
                # *fish)  prefix="set --export " ;;  # TODO
                *)      prefix="export " ;;
            esac
        fi

        for f in $ENVIRONMENT_DIR/*.conf; do
            if is_mod_blacklisted "$f"; then continue; fi

            printf "$prefix"
            cat "$f"
        done

        printf "$MARKER_END\n"
    } >> "$DEST_ENVIRONMENT"

    printf "${C_GREEN}Done${C_RESET}\n"
}

install_fontconfig () {
    printf -- "- %-40s%s" "Installing the fontconfig rules "

    if [[ $ENABLE_FONTCONFIG == false ]]; then
        printf "${C_YELLOW}Disabled${C_RESET}\n"
        return 0
    fi

    mkdir -p "$DEST_FONTCONFIG_DIR"

    append_metadata uninstall <<EOF
printf -- "- %-40s%s" "Removing the fontconfig rules "
EOF

    for f in $FONTCONFIG_DIR/*.conf; do
        if is_mod_blacklisted "$f"; then continue; fi

        install -m 644 "$f" "$DEST_FONTCONFIG_DIR/$(basename $f)"
        append_metadata uninstall <<EOF
rm -f "$DEST_FONTCONFIG_DIR/$(basename $f)"
EOF
    done

    [[ $G_IS_PER_USER == true ]] && append_metadata uninstall <<EOF
rmdir --ignore-fail-on-non-empty -p "$DEST_FONTCONFIG_DIR"
EOF

    append_metadata uninstall <<EOF
printf "${C_GREEN}Done${C_RESET}\n"
EOF
    printf "${C_GREEN}Done${C_RESET}\n"
}

# Call the locally stored uninstaller from target machine
call_uninstaller () {
    local lib_dir="$DEST_LIB_DIR"

    # TODO: Remove on 1.0.0
    if [[ ${G_INFO[version]} == "0.7.0" ]]; then
        # Backward compatibility with version 0.7.0
        #
        # Before the project rename
        lib_dir="$DEST_SHARED_DIR_OLD_BEFORE_0_8_0"
    elif verlt ${G_INFO[version]} "0.13.0"; then
        # Backward compatibility with versions below 0.13.0
        #
        # Uses old path to system shared dir
        lib_dir="$DEST_SHARED_DIR_OLD_BEFORE_0_13_0"
    fi


    if [[ ! -f "$lib_dir/$DEST_UNINSTALL_FILE" ]]; then
        printf "${C_RED}Uninstaller script not found, installation corrupted${C_RESET}\n"
        exit 1
    fi

    # Mitigate the symlink corruption issue that exists in 0.10.0-0.11.1
    # per-user mode.
    #
    # https://github.com/maximilionus/lucidglyph/issues/19
    #
    # TODO: Remove on 1.0.0
    if [[ $G_IS_PER_USER == true ]] && verlt ${G_INFO[version]} "0.12.0"
    then
        sed -i 's/rm -d/rmdir/g' "$lib_dir/$DEST_UNINSTALL_FILE"
    fi

    "$lib_dir/$DEST_UNINSTALL_FILE"
}

cmd_help () {
    cat <<EOF
usage: $0 [OPTIONS] [COMMAND]

Tuning the Linux font rendering stack for a more visually pleasing output.

For further information and usage details, please refer to the project
documentation provided in the README file.

COMMANDS:
  install  Install, re-install or upgrade the project
  remove   Remove the installed project
  help     Show this help message

OPTIONS:
  -s, --system (default)  Operate in system-wide mode
  -u, --user              Operate in per-user mode (experimental feature)

ENVIRONMENT VARIABLES - MODULES:
Note: Variables marked with "(stored)" will be preserved on project update.

  ENABLE_METADATA     Module group responsible for storing the information for
                      further operations like upgrades and uninstalls.
                      Default: true.

  (stored)
  ENABLE_ENVIRONMENT  Module group responsible for appending the environment
                      entries for global configurations of some software.
                      Default: true.

  (stored)
  ENABLE_FONTCONFIG   Module group that contains the set of Fontconfig rules.
                      Default: true.

ENVIRONMENT VARIABLES - UTILITY:
  SHOW_HEADER    Show the script header on execution.
                 Default: true.

  DESTDIR        Overwrite the target directory for script to work with.
                 Default: unset.

  DEST_CONF,     Set the paths to configuration directories.
  DEST_CONF_USR  Default: "/etc" for system-wide and "~/.config" for
                 per-user.

  DEST_USR,      Set the paths to shared directories.
  DEST_USR_USR   Default: "/usr/local" for system-wide and "~/.local/share" for
                 per-user.
EOF
}

cmd_install () {
    load_info_file
    load_mod_blacklist

    if [[ ${G_INFO[version]} == $VERSION ]]; then
        printf "${C_GREEN}Current version is already installed.${C_RESET}\n"

        if ask_confirmation "Do you wish to reinstall it?"; then
            check_root
            call_uninstaller
        else
            exit 0
        fi
    elif [[ ! -z ${G_INFO[version]} ]]; then
        printf "${C_GREEN}Detected $NAME version ${G_INFO[version]} on the target system.${C_RESET}\n"

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
    install_metadata
    install_environment
    install_fontconfig

    printf "\n${C_BOLD}${C_GREEN}Success!${C_RESET} ${C_BOLD}Reboot to apply the changes.${C_RESET}\n"
    printf "\n${C_DIM}"
    cat <<EOF
See the "Notes" section in README file for a more thorough explanation of the
potential problems that might need manual intervention or are just not fixable
currently.
EOF
    printf "${C_RESET}"
}

cmd_remove () {
    if [[ $ENABLE_METADATA == false ]]; then
        printf "${C_RED}"
        cat <<EOF
Functionality not available with disabled metadata
EOF
        printf "${C_RESET}"
        exit 1
    fi

    load_info_file

    if (( ! ${#G_INFO[@]} )); then
        printf "${C_RED}Project is not installed.${C_RESET}\n"
        exit 1
    fi

    check_root
    printf "Removing\n"
    call_uninstaller

    printf "${C_GREEN}Success!${C_RESET} Reboot to apply the changes.\n"
}


# Execution
cd "$(dirname "$0")"

[[ $SHOW_HEADER == true ]] && show_header

# Parse optional args
positional_args=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--system)
            G_IS_PER_USER=false
            shift
            ;;
        -u|--user)
            G_IS_PER_USER=true
            shift
            ;;
        -*|--*)
            printf "${C_YELLOW}Unknown option${C_RESET} $1\n"
            exit 1
            ;;
        *)
            positional_args+=("$1")
            shift
            ;;
    esac
done

# Set the positional arguments back for further usage
set -- "${positional_args[@]}"
unset positional_args

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

# Note
#
# While this project supports the fully functional Korn Shell (ksh)
# installations, it's quite impossible to run the installer itself through ksh
# since it relies on a huge amount of modern bash functionality. So... You can
# not install the project without actually having modern bash shell available on
# target system :)
if [[ $G_IS_PER_USER == true ]]; then
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
    DEST_LIB_DIR="$DEST_SHARED_DIR_USR" # I hate this. But it works. For now.
fi


# Parse main args
case "$1" in
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
