#!/bin/bash
# papirus-folder-color.sh
# Generate icon theme inheriting Papirus or Papirus-Dark,
# but with different coloured folder icons.

USAGE="
papirus-folder-color.sh [OPTIONS]

    Generates a user custom icon theme with a different folder color from
    the default Papirus blue.

Options:
        -h, --help
            Show this message.
        -c, --color <color>
            Choose icon color.
        -s, --source_path <path>
            Set path to directory holding Papirus theme to be used.
        -t, --target_path <path>
            Set path to directory where new theme will be generated.
        -n, --name <name>
            Set name of generated theme.
        -l, --link
            Symlink icons to source instead of copying.
        -d, --dark
            Declare theme to be dark and inherit Papirus-Dark.

color must be specified and can be one of:
black,blue,bluegrey,breeze,brown,cyan,deeporange,green,grey,indigo,magenta,nordic,orange,palebrown,paleorange,pink,red,teal,violet,white,yaru,yellow,custom

NB \"custom\" color corresponds to jet black, while \"black\" is actually dark grey.
\"jet-black\" may also be passed as an alias for \"custom\".

If --source_path is not passed, the Papirus theme is read from
/usr/share/icons/Papirus

If --target_path is not passed, the generated theme is written to
~/.local/share/icons/<new theme name>

If --name is not passed, the generated theme will be named
Papirus-Bunsen[-Dark]-<colour>.

By default icons will be copied into the new theme, not symlinked.
This increases the size, but improves portability.
Pass --link to generate symlinks instead.

If source_path and target_path are under the same top-level directory
then symlinked icons will use relative paths, otherwise absolute paths.
"

vendor=Bunsen # This will be included in generated theme name,
              # if not overruled by --name option.

## default variables
## these can (should, at least for color) be overridden by script options
source_path=/usr/share/icons # place to find source Papirus theme
target_path="$HOME/.local/share/icons" # place to put generated theme
#target_path="$PWD"
copy_files=true # If true, copy icons into new theme instead of symlinking.
new_theme=''
color=''

error_exit() {
    echo "$0 error: $1" >&2
    exit 1
}

while [[ -n $1 ]]
do
    case "$1" in
    --color|-c)
        color=$2
        shift 2
        ;;
    --source_path|-s)
        source_path=$2
        shift 2
        ;;
    --target_path|-t)
        target_path=$2
        shift 2
        ;;
    --name|-n)
        new_theme=$2
        shift 2
        ;;
    --link|-l)
        copy_files=false
        shift
        ;;
    --dark|-d)
        dark_theme=true
        shift
        ;;
    --help|-h)
        echo "$USAGE"
        exit
        ;;
    *)
        error_exit "$1: Unrecognized option."
        ;;
    esac
done

########################################################################

case "$color" in
black|blue|bluegrey|breeze|brown|cyan|deeporange|green|grey|indigo|magenta|nordic|orange|palebrown|paleorange|pink|red|teal|violet|white|yaru|yellow|custom)
    ;;
jet-black)
    color=custom;;
*)
    error_exit "${color}: Unrecognized colour."
esac

[[ -n $new_theme ]] || {
    if [[ $dark_theme = true ]]
    then
        new_theme="Papirus-Bunsen-Dark-${color}"
    else
        new_theme="Papirus-Bunsen-${color}"
    fi
}

source_dir="$source_path/Papirus"
target_dir="$target_path/$new_theme"

[[ $(basename "$source_dir") = Papirus ]] || error_exit "$source_dir: Not a Papirus theme directory"
[[ $(basename "$target_dir") = Papirus* ]] || error_exit "$target_dir: Not a Papirus theme directory" # try to avoid accidents


# Define function to make symlinks,
# relative if source & target have same top-level directory.
# If copy_files is true, copy instead of linking.
set_linking() {
    if [[ $copy_files = true ]]
    then
        link_file() { cp "$1" "$2"; }
    else
        local tld_src=$( readlink -f "${source_dir}" )
        tld_src=${tld_src#/}
        tld_src=${tld_src%%/*}
        local tld_tgt=$( readlink -f "${target_dir}" )
        tld_tgt=${tld_tgt#/}
        tld_tgt=${tld_tgt%%/*}
        if [[ "$tld_src" = "$tld_tgt" ]]
        then
            link_file() { ln -sfr "$1" "$2"; }
        else
            link_file() { ln -sf "$1" "$2"; }
        fi
    fi
}

set_linking

[[ -e "$target_dir" ]] && {
    echo "$target_dir will be removed and replaced, OK?"
    read -r -p ' remove? (y/n) '
    case ${REPLY^^} in
    Y|YES)
        rm -rf "$target_dir" || error_exit "Failed to remove $target_dir";;
    *)
        echo 'User cancelled. Exiting...'; exit;;
    esac
}
mkdir -p "$target_dir" || error_exit "Failed to create $target_dir"

defcolor=blue # the Papirus default
shortdirlist=
longdirlist=
for subdir in "$source_dir"/*
do
    [[ -d ${subdir}/places && ! -h $subdir ]] || continue # only use icons in "places" directories
    files=()
    while IFS= read -r -d '' file
    do
        files+=("$file")
    done < <(find "${subdir}/places" -type l \( -ilname "*-$defcolor-*" -o -lname "*-$defcolor.*" \) ! -iname "*-$defcolor-*" ! -iname "*-$defcolor.*" -print0)
    [[ ${#files[@]} -gt 0 ]] || continue
    dirname=${subdir##*/}
    mkdir -p "$target_dir/${dirname}/places" || error_exit "Failed to create $target_dir/${dirname}/places"
    scaledname=${dirname}@2x
    [[ $dirname != symbolic ]] && ln -s "${dirname}" "${target_dir}/${scaledname}" || error_exit "Failed to link ${target_dir}/${scaledname} to ${dirname}"
    for i in "${files[@]}"
    do
        find "${subdir}/places" -type l -lname "${i##*/}" -exec cp --no-dereference '{}' "$target_dir/${dirname}/places" \;
        target="$(readlink "$i")"
        target="${target/-${defcolor}/-${color}}"
        [[ -f "$subdir/places/$target" ]] || { echo "$subdir/places/$target: not found"; continue; }
        link_file "$subdir/places/$target" "$target_dir/$dirname/places/${i##*/}" || error_exit "Failed to link_file() $target_dir/$dirname/places/${i##*/} to $subdir/places/$target"
    done
    case "${dirname}" in
    symbolic)
        shortdirlist+="${dirname}/places,"
        longdirlist+="[${dirname}/places]
Context=Places
Size=16
MinSize=16
MaxSize=512
Type=Scalable

"
        ;;
    *)
        shortdirlist+="${dirname}/places,${scaledname}/places,"
        longdirlist+="[${dirname}/places]
Context=Places
Size=${dirname%x*}
Type=Fixed

[${scaledname}/places]
Context=Places
Size=${dirname%x*}
Scale=2
Type=Fixed

"
        ;;
    esac
done

if [[ $dark_theme = true ]]
then
    inherit="Papirus-Dark"
else
    inherit="Papirus"
fi

cat <<EOF > "$target_dir/index.theme"
[Icon Theme]
Name=$new_theme
Comment=Recoloured Papirus icon theme for BunsenLabs
Inherits=${inherit},breeze,ubuntu-mono-dark,gnome,hicolor

Example=folder

FollowsColorScheme=true

DesktopDefault=48
DesktopSizes=16,22,24,32,48,64
ToolbarDefault=22
ToolbarSizes=16,22,24,32,48
MainToolbarDefault=22
MainToolbarSizes=16,22,24,32,48
SmallDefault=16
SmallSizes=16,22,24,32,48
PanelDefault=48
PanelSizes=16,22,24,32,48,64
DialogDefault=48
DialogSizes=16,22,24,32,48,64

# Directory list
Directories=${shortdirlist%,}

$longdirlist
EOF

gtk-update-icon-cache "$target_dir"
