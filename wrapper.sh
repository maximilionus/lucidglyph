#!/bin/bash

# Wrapper for the lucidglyph project that will download and unpack all the
# necessary files for the latest or user-specified version, and execute the
# script, passing all the provided arguments.
#
# User can specify the project version with VERSION environmental variable.

set -e

NAME="lucidglyph"
NAME_OLD="freetype-envision"
VERSION="${VERSION:-}"
VERSION_MIN_SUPPORTED="0.2.0"
DOWNLOAD_LATEST_URL="https://api.github.com/repos/maximilionus/$NAME/releases/latest"
DOWNLOAD_SELECTED_URL="https://api.github.com/repos/maximilionus/$NAME/tarball/v$VERSION"
CURL_FLAGS="-s --show-error --fail -L"

# Check if version $2 >= $1
verlte() {
    [  "$1" = "`echo -e \"$1\n$2\" | sort -V | head -n1`" ]
}

# Check if version $2 > $1
verlt() {
    [ "$1" = "$2" ] && return 1 || verlte $1 $2
}


printf "Web wrapper for the $NAME\n"

deprecation_date="2025-09-01" 
deprecation_epoch=$(date -d "$deprecation_date" +%s)
current_epoch=$(date +%s)
days_left=$(( (deprecation_epoch - current_epoch) / 86400 ))

printf "\e[0;31m"
cat <<EOF
[Wrapper] Important security notice
    Due to potential security issues, this wrapper is now obsolete and will be
    removed on $deprecation_date (yyyy-mm-dd)!

    Days until this link is no longer available -> $days_left <-

    Please refrain from using this script and install the project directly by
    downloading the release from:

    https://github.com/maximilionus/lucidglyph/releases/latest

    Thank you :)
EOF
printf "\e[0m"

if (( days_left < 0 )); then
    exit 1
else
    read -p "Do you still wish to proceed? (y/N): "
    printf "\n"
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

TMP_DIR=$( mktemp -d )
if [[ ! -d $TMP_DIR ]]; then
    cat <<EOF
[Wrapper] Critical Error
    Failed to initialize temporary directory.

    Please check if "mktemp" command is available and functions properly on
    your system.
EOF
    exit 1
else
    trap 'rm -rf -- "$TMP_DIR"' EXIT
fi

cd "$TMP_DIR"

download_url=""
if [[ -z $VERSION ]]; then
    download_url=$(curl $CURL_FLAGS "$DOWNLOAD_LATEST_URL"  \
        | grep "tarball_url"                                \
        | tr -d ' ",;'                                      \
        | sed 's/tarball_url://')
else
    if verlt $VERSION $VERSION_MIN_SUPPORTED; then
        cat <<EOF
[Wrapper] This version is not supported by wrapper script,
          minimal supported version is: $VERSION_MIN_SUPPORTED"
EOF
        exit 1
    elif verlt $VERSION "0.8.0"; then
        # Backwards compatibility for versions below 0.8.0
        # TODO: Remove after 1.0.0 release
        NAME="$NAME_OLD"
    fi

    download_url="$DOWNLOAD_SELECTED_URL"
fi

curl $CURL_FLAGS -o "$NAME.tar.gz" "$download_url"

mkdir unpacked
tar -xzf "$NAME.tar.gz" --strip-components=1 -C unpacked
cd unpacked

elevate=""
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    printf "Root access is required for project management\n"
    elevate="sudo"

    if ! command -v $elevate 2>&1 >/dev/null; then
        printf "Can not request elevation since $elevate is missing on the system!\n"
        exit 1
    fi
fi

printf "\n"
$elevate ./"$NAME.sh" "$@"
