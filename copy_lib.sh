#!/bin/bash

# Script to copy libwstunnel.so from Rust build to Android jniLibs
# Uses relative paths from project root

# Get script directory (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Relative paths from project root
SOURCE_FILE="rust/target/aarch64-linux-android/release/libwstunnel.so"
DEST_DIR="android/app/src/main/jniLibs/arm64-v8a"
DEST_FILE="${DEST_DIR}/libwstunnel.so"

# Full paths
SOURCE_PATH="${SCRIPT_DIR}/${SOURCE_FILE}"
DEST_PATH="${SCRIPT_DIR}/${DEST_FILE}"
DEST_DIR_PATH="${SCRIPT_DIR}/${DEST_DIR}"

# Check if source file exists
if [ ! -f "$SOURCE_PATH" ]; then
    echo "Error: source file not found: $SOURCE_PATH"
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR_PATH"

# Copy file
cp "$SOURCE_PATH" "$DEST_PATH"

if [ $? -eq 0 ]; then
    echo "File successfully copied:"
    echo "  From: $SOURCE_FILE"
    echo "  To:   $DEST_FILE"
else
    echo "Error copying file"
    exit 1
fi

