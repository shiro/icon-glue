#!/usr/bin/zsh

ICONS_PATH='/mnt/d/ext/customization/icons/metro'

SHORTCUT_LOATIONS=(
	/mnt/c/ProgramData/Microsoft/Windows/Start\ Menu
	${HOME}'/AppData/Roaming/Microsoft/Windows/Start Menu'
)


declare -A EXTENSIONS
declare -A EXTENSIONS_ICONS

# read extension manifest without whitespaces
IFS=','
sed 's/\s*,\s*/,/g' ext_manifest.csv | while read -r ext app icon; do
	EXTENSIONS[$ext]="$app"
	EXTENSIONS_ICONS[$ext]="$icon"
done
unset IFS


# create output dir
mkdir -p out

# generate registry script head
echo 'Windows Registry Editor Version 5.00' > out/ext.reg

# generate registry snippets and append to output
for key in ${(k)EXTENSIONS[@]}; do

	icon="${ICONS_PATH}/${EXTENSIONS_ICONS[$key]}"
	icon="$(cygpath -w "$icon")"

	app="${EXTENSIONS[$key]}"

    sed -e "s|EXTENSION|${key}|g" \
		-e "s|ICON|${icon//\\/\\/}|g" \
		-e "s|APPLICATION|${app//\\/\\\\\\\\}|g" \
		template/ext.reg >> out/ext.reg

	# set the new extension as the default program
	./SetUserFTA ".${key}" "auto.${key}"
done

# apply registry snippet silently
regedit.exe /s out/ext.reg



# build a list of shortcuts from all locations
declare -a SHORTCUTS

for location in "$SHORTCUT_LOATIONS[@]"; do
	location=$(realpath "$location")
	SHORTCUTS+=("$location"/**/*.lnk) 2>/dev/null
done


# read icon manifest and build an associative array
declare -A ICONS
IFS=','

sed 's/\s*,\s*/,/g' icon_manifest.csv | while read key value; do
	ICONS[$key]=$(echo "$value" | xargs)
done

unset IFS


# set the new icons for each shortcut if it's in the icon manifest
for f in "${SHORTCUTS[@]}"; do
	# get the name without the prefix
	SHORTCUT="${f##*Start Menu/Programs/}"

	# iterate keys and attempt pattern matching against shortcut
	for key in ${(k)ICONS[@]}; do
		if [[ "$SHORTCUT" =~ "$key" ]]; then

			ICON=${ICONS[$key]}

			SHORTCUT_PATH=$(cygpath -w "$f")
			ICON_PATH=$(cygpath -w "${ICONS_PATH}/${ICON}")

			echo "[SET]    $f"

			cmd.exe /c set_icon.vbs "$SHORTCUT_PATH" "$ICON_PATH"
		fi
	done

	unset ICON
done
