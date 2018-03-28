#!/usr/bin/zsh

ICONS_PATH='/mnt/d/ext/customization/icons/metro'


declare -A ICONS
IFS=','

while read key value; do
	ICONS[$key]=$(echo "$value" | xargs)
done < icon_manifest.csv

unset IFS


SHORTCUTS=(/mnt/c/ProgramData/Microsoft/Windows/Start\ Menu/Programs/**/*.lnk)

for f in "${SHORTCUTS[@]}"; do
	SHORTCUT="${f##/mnt/c/ProgramData/Microsoft/Windows/Start\ Menu/Programs/}"

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
