#!/bin/zsh

ICON_DIR='/mnt/d/ext/customization/icons/metro'

SHORTCUT_LOATIONS=(
    /mnt/c/ProgramData/Microsoft/Windows/Start\ Menu
    ${HOME}'/AppData/Roaming/Microsoft/Windows/Start Menu'
)

CONFIG_FILE='config.json'


# create output dir
mkdir -p out


echo "### FILE TYPES ###"
echo

# generate registry script head
echo 'Windows Registry Editor Version 5.00' > out/ext.reg


for row in `jq -r '.filetypes[] | @base64' "$CONFIG_FILE"`; do
    _value() { echo ${row} | base64 --decode | jq -r ${1} }

    extension=`_value '.extension'`
    openWith=`_value '.openWith'`
    icon=`_value '.icon'`

    iconPath="`cygpath -w "$ICON_DIR/$icon"`"

    sed -e "s|EXTENSION|${extension}|g" \
        -e "s|ICON|${iconPath//\\/\\/}|g" \
        -e "s|APPLICATION|${openWith//\\/\\\\\\\\}|g" \
        template/ext.reg >> out/ext.reg

    # set the new extension as the default program
    ./SetUserFTA ".${extension}" "auto.${extension}"

    echo "[SET]    $icon"
done


# apply registry snippet silently
regedit.exe /s out/ext.reg


echo
echo "### SHORTCUTS ###"
echo


# build a list of shortcuts from all locations
declare -a SHORTCUTS

for location in "$SHORTCUT_LOATIONS[@]"; do
    location=$(realpath "$location")
    SHORTCUTS+=("$location"/**/*.lnk) 2>/dev/null
done


declare -A ICONS

for row in `jq -r '.shortcuts[] | @base64' "$CONFIG_FILE"`; do
    _value() { echo ${row} | base64 --decode | jq -r ${1} }

    pattern=`_value '.pattern'`
    icon=`_value '.icon'`

    ICONS[$pattern]="$value"
done


# set the new icons for each shortcut if it's in the icon manifest
for shortcutPath in "${SHORTCUTS[@]}"; do
    # get the name without the prefix
    shortcut="${shortcutPath##*Start Menu/Programs/}"

    # iterate keys and attempt pattern matching against shortcut
    for key in ${(k)ICONS[@]}; do
        if [[ "$shortcut" =~ "$key" ]]; then

            ICON=${ICONS[$key]}

            SHORTCUT_PATH=$(cygpath -w "$shortcutPath")
            ICON_PATH=$(cygpath -w "${ICONS_PATH}/${ICON}")

            echo "[SET]    $shortcutPath"

            # update the registry value
            cmd.exe /c set_icon.vbs "$SHORTCUT_PATH" "$ICON_PATH"
        fi
    done

    unset ICON
done
