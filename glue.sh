#!/usr/bin/zsh

ICONS_PATH='/mnt/d/ext/customization/icons/metro'

SHORTCUT_LOATIONS=(
	/mnt/c/ProgramData/Microsoft/Windows/Start\ Menu
	${HOME}'/AppData/Roaming/Microsoft/Windows/Start Menu'
)


# build a list of shortcuts from all locations
declare -a SHORTCUTS

for location in "$SHORTCUT_LOATIONS[@]"; do
	location=$(realpath "$location")
	SHORTCUTS+=("$location"/**/*.lnk) 2>/dev/null
done


# read icon manifest and build an associative array
declare -A ICONS
IFS=','

while read key value; do
	ICONS[$key]=$(echo "$value" | xargs)
done < icon_manifest.csv

unset IFS


# set the new icons for each shortcut if it's in the icon manifest
for f in "${SHORTCUTS[@]}"; do
	# get the name without the prefix
	SHORTCUT="${f##*Start Menu/Programs/}"

	# iterate keys and attempt pattern matching against shortcut
	for key in ${(k)ICONS[@]}; do
		if [[ "$SHORTCUT" =~ "$key" ]]; then

			ICON=${ICONS[$key]}

			SHORTCUT_PATH=$(wslpath -w "$f")
			ICON_PATH=$(wslpath -w "${ICONS_PATH}/${ICON}")

			echo "[SET]    $f"

			cmd.exe /c set_icon.vbs "$SHORTCUT_PATH" "$ICON_PATH"
		fi
	done

	unset ICON
done
