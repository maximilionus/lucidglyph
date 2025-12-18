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
shopt -s nullglob


NAME="lucidglyph"
VERSION="0.13.0"

# Display the header with project name and version on start
SHOW_HEADER=${SHOW_HEADER:-true}

# Filesystem configuration
SRC_DIR="src"
MODULES_DIR="$SRC_DIR/modules"

DEST_CONF="${DESTDIR:-}${DEST_CONF:-/etc}"
DEST_USR="${DESTDIR:-}${DEST_USR:-/usr/local}"
DEST_USR_OLD_BEFORE_0_13_0="${DESTDIR:-}/usr"  # TODO: Remove in 1.0.0

DEST_CONF_USR="${DESTDIR:-$HOME}${DEST_CONF_USR:-/.config}"
DEST_USR_USR="${DESTDIR:-$HOME}${DEST_USR_USR:-/.local}"

# Metadata group
#     Installation information and uninstaller script.
#
#     Disable this group when used in package manager.
DISABLE_METADATA=${DISABLE_METADATA:-}

DEST_LIB_DIR="$DEST_USR/lib/lucidglyph"
DEST_SHARED_DIR="$DEST_USR/share/lucidglyph"
DEST_SHARED_DIR_OLD_BEFORE_0_8_0="$DEST_USR_OLD_BEFORE_0_13_0/share/freetype-envision"  # TODO: Remove in 1.0.0
DEST_SHARED_DIR_OLD_BEFORE_0_13_0="$DEST_USR_OLD_BEFORE_0_13_0/share/lucidglyph"  # TODO: Remove in 1.0.0
DEST_SHARED_DIR_USR="$DEST_USR_USR/share/lucidglyph"
M_INFO_FILE="info" # TODO: Remove in 1.0.0
M_VERSION_FILE="version"
M_MODULES_BLACKLIST_FILE="modules_blacklist"
M_DEST_UNINSTALL_FILE="uninstaller.sh"

# Environment group
#     Variables that need to be exported to the system environment.
DISABLE_ENVIRONMENT=${DISABLE_ENVIRONMENT:-} # TODO: Remove in 1.0.0

ENVIRONMENT_DIR="$MODULES_DIR/environment"
DEST_ENVIRONMENT="$DEST_CONF/environment"

# Fontconfig group
DISABLE_FONTCONFIG=${DISABLE_FONTCONFIG:-} # TODO: Remove in 1.0.0

FONTCONFIG_DIR="$MODULES_DIR/fontconfig"
DEST_FONTCONFIG_DIR="$DEST_CONF/fonts/conf.d"
DEST_FONTCONFIG_DIR_USR="$DEST_CONF_USR/fontconfig/conf.d"

# Colors
C_RESET="\e[0m"
C_BOLD="\e[1m"
C_DIM="\e[2m"
C_WHITE="\e[0;37m"
C_GREEN="\e[0;32m"
C_YELLOW="\e[0;33m"
C_RED="\e[0;31m"

# Marker for tracking the appended content
MARKER_START="### START OF LUCIDGLYPH $VERSION CONTENT ###"
MARKER_WARNING="# !! DO NOT PUT ANY USER CONFIGURATIONS INSIDE THIS BLOCK !!"
MARKER_END="### END OF LUCIDGLYPH $VERSION CONTENT ###"

# Global variables
declare G_IS_PER_USER=false
declare -a G_MODULES_BLACKLIST=()       # Hardcoded system module blacklist
declare -a G_MODULES_BLACKLIST_USER=()  # User blacklist. Populated through `--blacklist` option.

declare G_M_VERSION
declare -a G_M_MODULES_BLACKLIST


# Check if version $1 > $2
ver_gt() {
    [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]]
}

# Check if version $1 >= $2
ver_ge() {
    [[ "$1" == "$2" ]] && return 0
    ver_gt "$1" "$2"
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
    if [[ "$(/usr/bin/id -u)" != 0 && "$G_IS_PER_USER" == false ]]; then
        printf "${C_RED}Error:${C_RESET} This action requires the root privileges\n" >&2
        exit 1
    elif [[ "$(/usr/bin/id -u)" == 0 && "$G_IS_PER_USER" == true ]]; then
        cat <<EOF
You are attempting to perform a per-user operation as the root user. This is
likely an error, as the utility will then operate with the root user instead of
the regular user. Please confirm that this is intentional.

EOF

        if ! ask_confirmation "Do you wish to continue?"; then
            exit 1
        fi
    fi
}

mod_blacklist_init() {
    if (( ${#G_MODULES_BLACKLIST_USER[@]} == 0 )) \
        && (( "${#G_M_MODULES_BLACKLIST[@]}" > 0 ))
    then
        G_MODULES_BLACKLIST_USER=("${G_M_MODULES_BLACKLIST[@]}")
    fi
}

mod_blacklist_checkup() {
    if (( ${#G_MODULES_BLACKLIST[@]} != 0 )); then
        printf "${C_DIM}Built-in modules blacklist:\n"
        printf -- '- %s\n' "${G_MODULES_BLACKLIST[@]}"
        printf "$C_RESET"
    fi

    (( ${#G_MODULES_BLACKLIST_USER[@]} == 0 )) && return 0

    printf "${C_DIM}User modules blacklist:\n"

    local is_wrong
    for i in "${G_MODULES_BLACKLIST_USER[@]}"; do
        printf -- '- %s' "$i"

        if ! compgen -G "$MODULES_DIR/$i" > /dev/null; then
            printf " ${C_YELLOW}(Warning: module does not exist!)${C_WHITE}"
            is_wrong=1
        fi

        printf "\n"
    done
    printf "$C_RESET"

    if [[ ! -z "$is_wrong" ]]; then
        ask_confirmation "One or more blacklist entries doesn't seem to be correct. Continue?"
    fi
}

# Check if the module is blacklisted by system or user.
#
# ARGUMENTS:
# 1 - Relative path to the module file (with or without $MODULES_DIR).
is_mod_blacklisted() {
    local module="${1#$MODULES_DIR/}"
    local blacklist=("${G_MODULES_BLACKLIST[@]}" "${G_MODULES_BLACKLIST_USER[@]}")

    for i in "${blacklist[@]}"; do
        # Unquoted $i to glob the possible patterns
        if  [[ "$module" == $i ]]; then
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

# Parse and load the old installation information.
# Deprecated in 0.13.0, TODO: Remove in 1.0.0
load_info_file () {
    # Empty the array that could be already loaded
    declare -A info_aarr

    local info_file_path="$DEST_SHARED_DIR/$M_INFO_FILE"

    [[ ! -z $DISABLE_METADATA ]] && return 0

    if [[ ! -f "$info_file_path" ]]; then
        # Backwards compatibility
        # TODO: Remove in 1.0.0
        if [[ -f "$DEST_SHARED_DIR_OLD_BEFORE_0_13_0/$M_INFO_FILE" ]]; then
            # Load the <0.13.0 info file
            info_file_path="$DEST_SHARED_DIR_OLD_BEFORE_0_13_0/$M_INFO_FILE"
        elif [[ -f "$DEST_SHARED_DIR_OLD_BEFORE_0_8_0/$M_INFO_FILE" ]]; then
            # Load the 0.7.0 state (info) file
            info_file_path="$DEST_SHARED_DIR_OLD_BEFORE_0_8_0/$M_INFO_FILE"
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

        if [[ "$line" =~ $regex ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            info_aarr["$key"]="$value"
        else
            printf "${C_YELLOW}Warning: Skipping the invalid metadata entry:${C_RESET} \"$line\".\n"
        fi
    done < "$info_file_path"

    # Compatibility layer, load the values to new format
    G_M_VERSION="${info_aarr[version]}"
}

# Process the local metadata files, loading the values.
load_metadata () {
    [[ ! -z $DISABLE_METADATA ]] && return 0

    # Load the legacy metadata format (before 0.13.0)
    if [[ ! -f "$DEST_SHARED_DIR/$M_VERSION_FILE" ]]; then
        load_info_file
        return 0
    fi

    if [[ ! -d "$DEST_SHARED_DIR" ]]; then return 0; fi

    # Load
    if [[ -f "$DEST_SHARED_DIR/$M_VERSION_FILE" ]]; then
        G_M_VERSION="$(cat $DEST_SHARED_DIR/$M_VERSION_FILE)"
    fi

    if [[ -f "$DEST_SHARED_DIR/$M_MODULES_BLACKLIST_FILE" ]]; then
        # Trim the empty lines with grep so the array can then be counted correctly.
        mapfile -t G_M_MODULES_BLACKLIST < <(grep -v '^$' "$DEST_SHARED_DIR/$M_MODULES_BLACKLIST_FILE")
    fi
}

# Append the redirected content to metadata files.
# Only works if DISABLE_METADATA is unset.
append_metadata () {
    local mode="$1"

    [[ ! -z $DISABLE_METADATA ]] && return 0

    local path=""
    case "$mode" in
        version) path="$DEST_SHARED_DIR/$M_VERSION_FILE" ;;
        modules_blacklist) path="$DEST_SHARED_DIR/$M_MODULES_BLACKLIST_FILE" ;;
        uninstall) path="$DEST_LIB_DIR/$M_DEST_UNINSTALL_FILE" ;;
        *) printf "${C_YELLOW}Warning: append_metadata wrong argument.${C_RESET}" ;;
    esac

    cat >> "$path"
}

install_metadata () {
    printf -- "- %-40s%s" "Storing the installation metadata"

    if [[ ! -z "$DISABLE_METADATA" ]]; then
        printf "${C_YELLOW}Disabled${C_RESET}\n"
        return 0
    fi

    mkdir -p "$DEST_SHARED_DIR"
    touch "$DEST_SHARED_DIR/$M_VERSION_FILE"
    touch "$DEST_SHARED_DIR/$M_MODULES_BLACKLIST_FILE"

    mkdir -p "$DEST_LIB_DIR"
    touch "$DEST_LIB_DIR/$M_DEST_UNINSTALL_FILE"
    chmod +x "$DEST_LIB_DIR/$M_DEST_UNINSTALL_FILE"
    printf "${C_GREEN}Done${C_RESET}\n"

    append_metadata version <<< "$VERSION"
    printf '%s\n' "${G_MODULES_BLACKLIST_USER[@]}" | append_metadata modules_blacklist
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

    # TODO: Remove in 1.0.0
    if [[ ! -z "$DISABLE_ENVIRONMENT" ]]; then
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

    if [[ "$G_IS_PER_USER" == false && ! -d "$DEST_CONF" ]]; then mkdir -p "$DEST_CONF"; fi

    {
        printf "$MARKER_START\n"
        printf "$MARKER_WARNING\n"

        prefix=""
        if [[ "$G_IS_PER_USER" == true ]]; then
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

    # TODO: Remove in 1.0.0
    if [[ ! -z "$DISABLE_FONTCONFIG" ]]; then
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

    if [[ "$G_IS_PER_USER" == false ]]; then
        # TODO: Remove in 1.0.0
        if [[ "$G_M_VERSION" == "0.7.0" ]]; then
            # Backward compatibility with version 0.7.0
            #
            # Before the project rename
            lib_dir="$DEST_SHARED_DIR_OLD_BEFORE_0_8_0"
        elif ver_gt "0.13.0" $G_M_VERSION; then
            # Backward compatibility with versions below 0.13.0
            #
            # Uses old path to system shared dir
            lib_dir="$DEST_SHARED_DIR_OLD_BEFORE_0_13_0"
        fi
    fi

    if [[ ! -f "$lib_dir/$M_DEST_UNINSTALL_FILE" ]]; then
        printf "${C_RED}Error:${C_RESET} Uninstaller script not found, installation corrupted\n" >&2
        exit 1
    fi

    # Mitigate the symlink corruption issue that exists in 0.10.0-0.11.1
    # per-user mode.
    #
    # https://github.com/maximilionus/lucidglyph/issues/19
    #
    # TODO: Remove in 1.0.0
    if [[ "$G_IS_PER_USER" == true ]] && ver_gt "0.12.0" "$G_M_VERSION"
    then
        sed -i 's/rm -d/rmdir/g' "$lib_dir/$M_DEST_UNINSTALL_FILE"
    fi

    "$lib_dir/$M_DEST_UNINSTALL_FILE"
}

cmd_help () {
    cat <<EOF
usage: $0 [OPTIONS] [COMMAND]

Tuning the Linux font rendering stack for a more visually pleasing output.

For further information and usage details, please refer to the project
documentation provided in the README file.

Note: Entries below marked with "Stored" will be preserved between project
updates unless overwritten by the user.

COMMANDS:
  install  Install, reinstall, or upgrade the project
  remove   Remove the installed project
  help     Show this help message

OPTIONS:
  -s, --system (default)  Operate in system-wide mode.
                          Commands: install, remove.

  -u, --user              Operate in per-user mode (experimental feature).
                          Commands: install, remove.

  -b, --blacklist <arg>   Module blacklist pattern. One pattern per option.
                          Pattern should be provided in literal string format
                          (single quotes).
                          Commands: install.
                          Stored.

ENVIRONMENT VARIABLES - MODULES:
  DISABLE_METADATA  Do not store any information for further operations like
                    upgrades or uninstalls. Assign any value to activate.
                    Default: empty (false).

ENVIRONMENT VARIABLES - UTILITY:
  SHOW_HEADER    Show the script header on execution.
                 Default: true.

  DESTDIR        Relocate the whole installation by prepending the path from
                 this variable.
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
    check_root
    load_metadata
    mod_blacklist_init
    mod_blacklist_checkup

    local needs_reinstall
    local confirm_msg
    if [[ "$G_M_VERSION" == "$VERSION" ]]; then
        printf "${C_GREEN}Current version is already installed.${C_RESET}\n"

        needs_reinstall=1
        confirm_msg="Do you wish to reinstall it?"
    elif [[ ! -z "$G_M_VERSION" ]]; then
        printf "${C_GREEN}Detected $NAME version $G_M_VERSION on the target system.${C_RESET}\n"

        needs_reinstall=1
        confirm_msg="Do you wish to upgrade to version $VERSION?"
    fi

    if [[ ! -z "$needs_reinstall" ]]; then
        if ! ask_confirmation "$confirm_msg"; then exit 1; fi

        call_uninstaller
    fi

    printf "Setting up\n"
    install_metadata
    install_environment
    install_fontconfig

    printf "\n${C_BOLD}${C_GREEN}Success!${C_RESET} ${C_BOLD}Reboot to apply the changes.${C_RESET}\n"
    printf "\n${C_DIM}"
    cat <<EOF
See the "Notes" section in the README file for a more thorough explanation of
project modules and potential issues that may arise.
EOF
    printf "${C_RESET}"
}

cmd_remove () {
    if [[ "$DISABLE_METADATA" == false ]]; then
        printf "${C_RED}Error:${C_RESET} Functionality not available with disabled metadata" >&2
        exit 1
    fi

    load_metadata

    if [[ -z "$G_M_VERSION" ]]; then
        printf "${C_RED}Error:${C_RESET} Project is not installed.\n" >&2
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

if [[ "$( uname -s )" != Linux* ]]; then
    cat <<EOF
$(printf "$C_YELLOW")----Warning----$(printf "$C_RESET")
You are trying to run this script on the unsupported platform. Proceed at your
own risk.
$(printf "$C_YELLOW")---------------$(printf "$C_RESET")

EOF
    if ! ask_confirmation "Do you wish to continue?"; then
        exit 1
    fi
fi

# Deprecate short commands.
# TODO: Remove in 1.0.0
case "$1" in
    i|r|h)
        cat <<EOF
$(printf "$C_YELLOW")----Warning----$(printf "$C_RESET")
Arguments "i", "r" and "h" (short commands) are considered deprecated since
version 0.5.0 and will be removed in version 1.0.0.
$(printf "$C_YELLOW")---------------$(printf "$C_RESET")
EOF
        ;;
esac

# Deprecate project modes
# TODO: Remove in 1.0.0
if [[ "$2" =~ ^(normal|full)$ ]]; then
    cat <<EOF
$(printf "$C_YELLOW")----Warning----$(printf "$C_RESET")
Arguments "normal" and "full" (mode selection) are considered deprecated since
version 0.7.0 and will be removed in version 1.0.0.

Only one mode is available from now on. Please avoid providing the second
argument.

Whatever argument is specified in this call now will result in a normal mode
installation.
$(printf "$C_YELLOW")---------------$(printf "$C_RESET")
EOF
fi

# Deprecate old ENABLE_* env. vars
# TODO: Remove in 1.0.0
if [[ "$ENABLE_METADATA" == false ]]; then
    cat <<EOF
$(printf "$C_YELLOW")----Warning----$(printf "$C_RESET")
Environment variable "ENABLE_METADATA" has been replaced by "DISABLE_METADATA",
with the original variable considered deprecated since version 0.13.0 and
marked for removal in version 1.0.0.

From now on, to disable metadata, assign any value to the "DISABLE_METADATA"
environment variable.

Provided variable will now be automatically reassigned correspondingly:
    ENABLE_METADATA=false  -->  DISABLE_METADATA=1
$(printf "$C_YELLOW")---------------$(printf "$C_RESET")
EOF

    if [[ "$ENABLE_METADATA" == false ]]; then
        DISABLE_METADATA=1
        unset ENABLE_METADATA
    fi
fi

if [[ "$ENABLE_ENVIRONMENT" == "false" || ! -z "$DISABLE_ENVIRONMENT" ]] || \
   [[ "$ENABLE_FONTCONFIG" == "false" || ! -z "$DISABLE_FONTCONFIG" ]]
then
    cat <<EOF
$(printf "$C_YELLOW")----Warning----$(printf "$C_RESET")
Environment variables "ENABLE_ENVIRONMENT"/"DISABLE_ENVIRONMENT" and
"ENABLE_FONTCONFIG"/"DISABLE_FONTCONFIG" are considered deprecated since
version 0.13.0 and marked for removal in version 1.0.0.

This feature was replaced with module blacklisting. See README for more
information.
$(printf "$C_YELLOW")---------------$(printf "$C_RESET")
EOF

    if [[ "$ENABLE_ENVIRONMENT" == false ]]; then
        DISABLE_ENVIRONMENT=1
        unset ENABLE_ENVIRONMENT
    fi
    if [[ "$ENABLE_FONTCONFIG" == false ]]; then
        DISABLE_FONTCONFIG=1
        unset ENABLE_FONTCONFIG
    fi
fi

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
            printf "${C_DIM}Operating in per-user mode (experimental).${C_RESET}\n"
            shift
            ;;
        -b|--blacklist)
            if [[ -n "$2" ]]; then
                G_MODULES_BLACKLIST_USER+=("$2")
                shift 2
            else
                printf "${C_RED}Error:${C_RESET} $1 requires a module name\n" >&2
                exit 1
            fi
            ;;
        -*|--*)
            printf "${C_RED}Error:${C_RESET} Unknown option \"$1\"\n" >&2
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

# While this project supports the fully functional Korn Shell (ksh)
# installations, it's quite impossible to run the installer itself through ksh
# since it relies on a huge amount of modern bash functionality :)
if [[ "$G_IS_PER_USER" == true ]]; then
    shell_config="$(get_shell_conf)"
    if [[ -z "$shell_config" ]]; then
        printf "${C_RED}Error:${C_RESET} Per-user operational mode is only supported on bash, zsh and ksh shells.\n"
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
        printf "${C_RED}Error:${C_RESET} Unknown command $1\n" >&2
        printf "Use ${C_BOLD}help${C_RESET} command to get usage information\n" >&2
        exit 1
esac
