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
