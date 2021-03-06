#!/bin/zsh

SCRIPT_NAME="`basename $0`"
SCRIPT_PATH="`readlink -f ${0:a}`"

usage(){
  cat <<USAGE
  Usage: $SCRIPT_NAME [OPTION]...
    -c <config.json>       specify config file
    -i <path to icon dir>  specify custom icon dir path
        --dry-run          do not actually persist any changes
        --help             print this message
USAGE
}


SHORTCUT_LOATIONS=(
    /mnt/c/ProgramData/Microsoft/Windows/Start\ Menu
    '/mnt/d/Users/shiro/AppData/Roaming/ClassicShell/Pinned'
    '/mnt/d/Users/shiro/AppData/Roaming/Microsoft/Windows/Start Menu'
)


DRY_RUN=false
CONFIG_FILE='config.json'
ICON_DIR='/mnt/d/ext/customization/icons/metro'


# decide which file converter to use
if   [ `command -v cygpath` ]; then
  PATH_CONVERTER='cygpath'
elif [ `command -v wslpath` ]; then
  PATH_CONVERTER='wslpath'
else
  echo 'error: unable to find cygpath or wslpath locally'
  exit 1
fi


while getopts ':c:i:-:' opt; do
  case "$opt" in
    -) case "$OPTARG" in
        help)
          usage; exit 0
          ;;
        dry-run)
          DRY_RUN=true
          ;;
        *)
          usage; exit 1
          ;;
      esac;;
    c)
      if [ ! -e "$OPTARG" ]; then
        echo "$OPTARG: not found"
        exit 1
      fi
      CONFIG_FILE="$OPTARG"
      ;;
    i)
      if [ ! -d "$OPTARG" ]; then
        echo "$OPTARG: not found"
        exit 1
      fi
      ICON_DIR="$OPTARG"
      ;;
    :|\?)
      usage; exit 1
      ;;
  esac
done
shift $((OPTIND-1))

# no additional arguments
[ $# -ne 0 ] && usage && exit 1


cd "${SCRIPT_PATH:h}"
mkdir -p out


echo "### FILE TYPES ###"
echo


# handle app aliasing
declare -A apps

for row in `jq -r '.apps[] | @base64' "$CONFIG_FILE"`; do
  _value() { echo ${row} | base64 --decode | jq -r "$1"'| select (type=="string")'}

  local name="`_value '.name'`"
  local _path="`_value '.path'`"
  local command="`_value '.command'`"

  if [ -z "$command" ] && \
    command="${_path//\\/\\\\} "'\"%1\"'

  apps["$name",command]="$command"
done

# generate registry script head
echo 'Windows Registry Editor Version 5.00' > out/ext.reg


for row in `jq -r '.filetypes[] | @base64' "$CONFIG_FILE"`; do
  task(){
    _value() { echo ${row} | base64 --decode | jq -r "$1"'| select (type=="string")' }

    local extensions=(`_value '.extensions[]?'`)
    local openWith=`_value '.openWith'`
    local openWithApp=`_value '.openWithApp'`
    local icon=`_value '.icon'`
    local command=`_value '.command'`
    local _path="`_value '.path'`"

    # resolve app command
    if   [ -n "$command" ]; then
      command="$command"
    elif [ -n "${apps["$openWithApp",command]}" ]; then
      command=$apps["$openWithApp",command]
    else
      command="${openWith//\\/\\\\} "'\"%1\"'
    fi

    iconPath="`$PATH_CONVERTER -w "$ICON_DIR/$icon" 2>/dev/null`"

    if [ $? -ne 0 ]; then
      echo "[ERROR] $ICON_DIR/$icon: not found"
      continue
    fi

    for extension in "${extensions[@]}"; do
      # special handling of empty extension
      if [ "$extension" = "NONE" ] && \
        extension=""

      sed -e "s|EXTENSION|${extension}|g" \
        -e "s|ICON|${iconPath//\\/\\/}|g" \
        -e "s|COMMAND|${command//\\/\\\\}|g" \
        template/ext.reg >> out/ext.reg

      echo >> out/ext.reg

      # set the new extension as the default program
      [ $DRY_RUN = false ] && \
        ./SetUserFTA.exe ".${extension}" "auto.${extension}"

      echo "[SET] .$extension -> $icon"
    done
  }
  task &
done

wait



# apply registry snippet silently
[ $DRY_RUN = false ] && \
regedit.exe /s out/ext.reg


echo
echo "### SHORTCUTS ###"
echo


# build a list of shortcuts from all locations
declare -a SHORTCUTS

for location in "$SHORTCUT_LOATIONS[@]"; do
    local location=$(realpath "$location" || '')

    [ -z $location ] && continue

   # echo loc $location

    SHORTCUTS+=("$location"/**/*.lnk) 2>/dev/null
done

declare -A ICONS

for row in `jq -r '.shortcuts[] | @base64' "$CONFIG_FILE"`; do
    _value() { echo ${row} | base64 --decode | jq -r ${1} }

    local pattern=`_value '.pattern'`
    local icon=`_value '.icon'`

    ICONS[$pattern]="$icon"
done


mkdir -p out/shortcuts 2>/dev/null

# set the new icons for each shortcut if it's in the icon manifest
for shortcutPath in "${SHORTCUTS[@]}"; do
    (
    # get the name without the prefix
    local shortcut="${shortcutPath##*Start Menu/Programs/}"

    # iterate keys and attempt pattern matching against shortcut
    for key in ${(k)ICONS[@]}; do
        if [[ "$shortcut" =~ "$key" ]]; then

            icon=${ICONS[$key]}

            platShortcutPath=`$PATH_CONVERTER -w "$shortcutPath"`
            iconPath="`$PATH_CONVERTER -w "${ICON_DIR}/${icon}" 2>/dev/null`"

            if [ $? -ne 0 ]; then
              echo "[ERROR] $ICON_DIR/$icon: not found"
              continue
            fi

            printf '[SET] %s\n' "$platShortcutPath"

            cp "$shortcutPath" "out/shortcuts/${shortcutPath:t}"
            cmd.exe /c set_icon.vbs "out/shortcuts/${shortcutPath:t}" "$iconPath"

            # update the registry value
            if [ "$DRY_RUN" = false ]; then
              cp "out/shortcuts/${shortcut:t}"  "$shortcutPath"
            fi
        fi

    done

    unset ICON
    ) &
done
