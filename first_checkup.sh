#!/usr/bin/env bash

# Decompress a ZIP archive, organize its files by extension,
# and report Python files that contain the PySide6 keyword.

# Check that exactly two arguments were provided.
if [[ $# -ne 2 ]]; then
    printf 'Illegal arguments. Usage: %s <origin_zip_path> <destination_path>\n' "$0" >&2
    exit 2
fi

zip_path=$1
destination=$2
parent_folder="$destination/organized_files"

# Check that the origin exists and is a regular file.
if [[ ! -f "$zip_path" ]]; then
    printf 'Error: ZIP file does not exist or is not a regular file: %s\n' "$zip_path" >&2
    exit 1
fi

# Check that the origin file has a .zip extension.
zip_extension=${zip_path##*.}
zip_extension=$(printf '%s' "$zip_extension" | tr '[:upper:]' '[:lower:]')

if [[ "$zip_extension" != "zip" ]]; then
    printf 'Error: origin file must have a .zip extension: %s\n' "$zip_path" >&2
    exit 1
fi

# Check that the unzip utility is available.
if ! command -v unzip >/dev/null 2>&1; then
    printf 'Error: unzip is required but was not found in PATH.\n' >&2
    exit 1
fi

# Create the destination and parent folders.
if ! mkdir -p -- "$parent_folder"; then
    printf 'Error: could not create destination directory: %s\n' "$parent_folder" >&2
    exit 1
fi

# Create a temporary folder for extraction and remove it when the script exits.
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/decompress_zip.XXXXXX") || {
    printf 'Error: could not create a temporary directory.\n' >&2
    exit 1
}
trap 'rm -rf -- "$temp_dir"' EXIT

# Extract the ZIP contents into the temporary folder.
mkdir -p -- "$temp_dir/extracted"

if ! unzip -q "$zip_path" -d "$temp_dir/extracted"; then
    printf 'Error: failed to decompress ZIP file: %s\n' "$zip_path" >&2
    exit 1
fi

# Identify the destination folder based on each file's extension.
category_for_file() {
    local filename extension
    filename=${1##*/}

    # Treat dotfiles without another dot as files with no extension.
    if [[ "$filename" == *.* && "$filename" != .* ]]; then
        extension=${filename##*.}
        extension=$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')
    else
        extension=''
    fi

    case "$extension" in
        py)
            printf 'Python'
            ;;
        pdf|doc|docx|txt|rtf|odt)
            printf 'documents'
            ;;
        jpg|jpeg|png|gif|bmp|svg|webp|tif|tiff)
            printf 'images'
            ;;
        c|h|cpp|hpp|cc|java|js|ts|jsx|tsx|html|css|sh|bash|rb|go|rs|php|sql)
            printf 'codes'
            ;;
        zip|7z|rar|tar|gz|bz2|xz)
            printf 'archives'
            ;;
        mp3|wav|ogg|flac|aac|m4a)
            printf 'audio'
            ;;
        mp4|mov|avi|mkv|webm)
            printf 'videos'
            ;;
        xls|xlsx|csv|ods)
            printf 'spreadsheets'
            ;;
        ppt|pptx|odp)
            printf 'presentations'
            ;;
        *)
            printf 'other'
            ;;
    esac
}

# Sort extracted files into folders based on extension.
# Preserve the archive's relative paths to avoid overwriting same-named files.
python_count=0
python_pyside_count=0

while IFS= read -r -d '' file_path; do
    relative_path=${file_path#"$temp_dir/extracted"/}

    # Skip macOS ZIP metadata files and folders.
    if [[ "$relative_path" == __MACOSX/* || "${file_path##*/}" == ._* ]]; then
        continue
    fi

    category=$(category_for_file "$file_path")
    output_path="$parent_folder/$category/$relative_path"

    mkdir -p -- "${output_path%/*}"

    if ! cp -p -- "$file_path" "$output_path"; then
        printf 'Error: could not copy file to destination: %s\n' "$relative_path" >&2
        exit 1
    fi

    # Scan each Python file for the exact PySide6 keyword.
    if [[ "$category" == "Python" ]]; then
        python_count=$((python_count + 1))
        printf '\nFile: %s\n' "$relative_path"

        if grep -nF -- 'PySide6' "$file_path"; then
            python_pyside_count=$((python_pyside_count + 1))

            # Copy matching files into the Python/PySide6 folder.
            pyside_path="$parent_folder/Python/PySide6/$relative_path"
            mkdir -p -- "${pyside_path%/*}"

            if ! cp -p -- "$file_path" "$pyside_path"; then
                printf 'Error: could not copy PySide6 file: %s\n' "$relative_path" >&2
                exit 1
            fi
        else
            printf 'No PySide6 keyword found.\n'
        fi
    fi
done < <(find "$temp_dir/extracted" -type f -print0)

# Print the Python scan summary.
printf '\nSummary: %d Python file(s) scanned; %d file(s) use PySide6.\n' \
    "$python_count" "$python_pyside_count"