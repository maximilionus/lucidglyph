#!/bin/bash

set -e


SRC_DIR=src
VERSION="0.5.0"

# profile.d
PROFILED_DIR="$SRC_DIR/profile.d"
PROFILED_NORMAL="freetype-envision-normal.sh"
PROFILED_FULL="freetype-envision-full.sh"
DEST_PROFILED_FILE="/etc/profile.d/freetype-envision.sh"

# fontconfig
FONTCONFIG_DIR="$SRC_DIR/fontconfig"
DEST_FONTCONFIG_DIR="/etc/fonts/conf.d"
#                    ("<NAME>" "<PRIORITY>")
FONTCONFIG_GRAYSCALE=("freetype-envision-grayscale.conf" 11)
FONTCONFIG_DROID_SANS=("freetype-envision-droid-sans.conf" 70)

# Storing the manual (from script) installation info on target system.
# Disable by setting the STORE_STATE env variable to false, but only do it when
# using some other tool (package manager, etc) for project management, where
# this script is only used to install the project files to target system.
STORE_STATE="${STORE_STATE:-true}"
DEST_CONF_DIR="/etc/freetype-envision"
DEST_STATE_FILE="state"

# Global variables
declare g_selected_mode


__require_root () {
    if [[ $(/usr/bin/id -u) -ne 0 ]]; then
        echo "This action requires the root privileges"
        exit 1
    fi
}

__verify_mode () {
    local sel_mode="${1:-normal}"

    if [[ $sel_mode == "normal" ]]; then
        g_selected_mode=$sel_mode
        echo "-> \"Normal\" mode selected."
    elif [[ $sel_mode == "full" ]]; then
        g_selected_mode=$sel_mode
        echo "-> \"Full\" mode selected."
    else
        echo "Wrong mode, stopping."
        exit 1
    fi
}

__verify_ver () {
    if [[ -f $DEST_CONF_DIR/$DEST_STATE_FILE ]]; then
        # State file exists, checking if the version is same
        declare -A state  # Kind of a namespace to store state vars
        source "$DEST_CONF_DIR/$DEST_STATE_FILE"

        if [[ ${state[version]} != $VERSION ]]; then
            echo "Manually installed project of a previous or newer version is already installed on the system. Remove it with a script of the appropriate version." | fold -sw 80
            exit 1
        fi

        unset state
    else
        if [[ -f $DEST_PROFILED_FILE ]]; then
            # Project files exist on the taget system, but no state file
            echo "Project is already installed on the system, probably with package manager or an installation script for the version below '0.5.0'. Remove it using the original installation method." | fold -sw 80
            exit 1
        fi
    fi
}

show_header () {
    echo "FreeType Envision, version $VERSION"
}

show_help () {
    echo "Usage: ./freetype-envision.sh [COMMAND]"
    echo
    echo "COMMANDS:"
    echo "  i,install <mode> : Install the project."
    echo "  r,remove         : Remove the installed project."
    echo "  h,help           : Show this help message."
    echo "OPTIONS:"
    echo "   mode            : \"normal\" (default),"
    echo "                     \"full\"."
    exit 0
}

project_install () {
    echo "-> Begin project install."
    __verify_ver
    __require_root

    echo "--> Installing the profile.d scripts:"
    if [[ $g_selected_mode == "normal" ]]; then
        install -v -m 644 "$PROFILED_DIR/$PROFILED_NORMAL" "$DEST_PROFILED_FILE"
    elif [[ $g_selected_mode == "full" ]]; then
        install -v -m 644 "$PROFILED_DIR/$PROFILED_FULL" "$DEST_PROFILED_FILE"
    fi

    echo "--> Installing the fontconfig configurations:"
    install -v -m 644 \
        "$FONTCONFIG_DIR/${FONTCONFIG_GRAYSCALE[0]}" \
        "$DEST_FONTCONFIG_DIR/${FONTCONFIG_GRAYSCALE[1]}-${FONTCONFIG_GRAYSCALE[0]}"

    install -v -m 644 \
        "$FONTCONFIG_DIR/${FONTCONFIG_DROID_SANS[0]}" \
        "$DEST_FONTCONFIG_DIR/${FONTCONFIG_DROID_SANS[1]}-${FONTCONFIG_DROID_SANS[0]}"

    if [[ $STORE_STATE = true ]]; then
        echo "--> Storing installation info to '$DEST_CONF_DIR/$DEST_STATE_FILE':"
        mkdir -pv "$DEST_CONF_DIR"
        echo "state[version]='$VERSION'" | tee "$DEST_CONF_DIR/$DEST_STATE_FILE"
        echo "state[mode]='$g_selected_mode'" | tee -a "$DEST_CONF_DIR/$DEST_STATE_FILE"
    fi

    echo "-> Success! Reboot to apply the changes."
}

project_remove () {
    echo "-> Begin project removal."
    __verify_ver
    __require_root

    echo "--> Removing the profile.d scripts:"
    rm -fv "$DEST_PROFILED_FILE"

    echo "--> Removing the fontconfig configurations:"
    rm -fv "$DEST_FONTCONFIG_DIR/${FONTCONFIG_GRAYSCALE[1]}-${FONTCONFIG_GRAYSCALE[0]}"
    rm -fv "$DEST_FONTCONFIG_DIR/${FONTCONFIG_DROID_SANS[1]}-${FONTCONFIG_DROID_SANS[0]}"

    echo "--> Removing the configurations directory:"
    rm -rfv "$DEST_CONF_DIR"

    echo "-> Success! Reboot to apply the changes."
}


# Main logic below
arg_1="$1"
arg_2="$2"

show_header

# Deprecate short commands.
# ! Remove on 1.0.0
case $arg_1 in
    i|r|h)
        echo "Warning: Argument '$1', short command, is considered deprecated and will be removed in '1.0.0' project release." | fold -sw 80
        ;;
esac

case $arg_1 in
    i|install)
        __verify_mode $arg_2
        project_install
        ;;
    r|remove)
        project_remove
        ;;
    h|help)
        show_help
        ;;
    *)
        echo "Error: Invalid argument: \"$1\"."
        echo "Use \"help\" to get the list of commands"
        exit 1
esac
