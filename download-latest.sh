#!/bin/sh

# COLORS
RED="\033[31m"
GREEN="\033[32m"
DEFAULT="\033[0m"

# GLOBALS
REGEXP_SEMVER='v[^0-9]*\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\)\([0-9A-Za-z-]*\)'
BINARY_NAME='meilisearch'

# semverParseInto and semverLT from https://github.com/cloudflare/semver_bash/blob/master/semver.sh

# usage: semverParseInto version major minor patch special
# version: the string version
# major, minor, patch, special: will be assigned by the function
semverParseInto() {
    local RE='[^0-9]*\([0-9]*\)[.]\([0-9]*\)[.]\([0-9]*\)\([0-9A-Za-z-]*\)'
    #MAJOR
    eval $2=`echo $1 | sed -e "s#$RE#\1#"`
    #MINOR
    eval $3=`echo $1 | sed -e "s#$RE#\2#"`
    #MINOR
    eval $4=`echo $1 | sed -e "s#$RE#\3#"`
    #SPECIAL
    eval $5=`echo $1 | sed -e "s#$RE#\4#"`
}

# usage: semverLT version1 version2
semverLT() {
    local MAJOR_A=0
    local MINOR_A=0
    local PATCH_A=0
    local SPECIAL_A=0

    local MAJOR_B=0
    local MINOR_B=0
    local PATCH_B=0
    local SPECIAL_B=0

    semverParseInto $1 MAJOR_A MINOR_A PATCH_A SPECIAL_A
    semverParseInto $2 MAJOR_B MINOR_B PATCH_B SPECIAL_B

    if [ $MAJOR_A -lt $MAJOR_B ]; then
        return 0
    fi
    if [ $MAJOR_A -le $MAJOR_B ] && [ $MINOR_A -lt $MINOR_B ]; then
        return 0
    fi
    if [ $MAJOR_A -le $MAJOR_B ] && [ $MINOR_A -le $MINOR_B ] && [ $PATCH_A -lt $PATCH_B ]; then
        return 0
    fi
    if [ "_$SPECIAL_A"  == "_" ] && [ "_$SPECIAL_B"  == "_" ] ; then
        return 1
    fi
    if [ "_$SPECIAL_A"  == "_" ] && [ "_$SPECIAL_B"  != "_" ] ; then
        return 1
    fi
    if [ "_$SPECIAL_A"  != "_" ] && [ "_$SPECIAL_B"  == "_" ] ; then
        return 0
    fi
    if [ "_$SPECIAL_A" < "_$SPECIAL_B" ]; then
        return 0
    fi

    return 1
}

success_usage() {
    printf "$GREEN%s\n$DEFAULT" "MeiliSearch binary successfully downloaded as '$BINARY_NAME' file."
    echo ''
    echo 'Run it:'
    echo '    $ ./meilisearch'
    echo 'Usage:'
    echo '    $ ./meilisearch --help'
}

failure_usage() {
    printf "$RED%s\n$DEFAULT" 'ERROR: MeiliSearch binary is not available for your OS distribution yet.'
    echo ''
    echo 'However, you can easily compile the binary from the source files.'
    echo 'Follow the steps on the docs: https://docs.meilisearch.com/advanced_guides/binary.html#how-to-compile-meilisearch'
}

# OS DETECTION
echo 'Detecting OS distribution...'
os_name=$(uname -s)
if [ "$os_name" != "Darwin" ]; then
    os_name=$(cat /etc/os-release | grep '^ID=' | tr -d '"' | cut -d '=' -f 2)
fi
echo "OS distribution detected: $os_name"
case "$os_name" in
'Darwin')
    os='macos'
    ;;
'ubuntu' | 'debian')
    os='linux'
    ;;
*)
    failure_usage
    exit 1
esac

# GET LATEST VERSION
tags=$(curl -s 'https://api.github.com/repos/meilisearch/MeiliSearch/tags' \
    | grep "$REGEXP_SEMVER" \
    | grep 'name' \
    | tr -d '"' | tr -d ',' | cut -d 'v' -f 2)

latest=""
for tag in $tags; do
    if [ "$latest" = "" ]; then
        latest="$tag"
    else
        semverLT $tag $latest
        if [ $? -eq 1 ]; then
            latest="$tag"
        fi
    fi
done

# DOWNLOAD THE LATEST
echo "Downloading MeiliSearch binary v$latest for $os..."
release_file="meilisearch-$os-amd64"
link="https://github.com/meilisearch/MeiliSearch/releases/download/v$latest/$release_file"
curl -OL "$link"
mv "$release_file" "$BINARY_NAME"
chmod 744 "$BINARY_NAME"
success_usage
