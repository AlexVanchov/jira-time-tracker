#!/bin/bash

# Check if required commands are installed
for cmd in python3 jq curl; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is required but not installed."
        exit 1
    fi
done

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Copy jira_time.sh to jtime
cp "$SCRIPT_DIR/jira_time.sh" "$SCRIPT_DIR/jtime"

# Make the script executable
chmod +x "$SCRIPT_DIR/jtime"

# Create a symlink in /usr/local/bin
if [ -w /usr/local/bin ]; then
    ln -sf "$SCRIPT_DIR/jtime" /usr/local/bin/jtime
    echo "Successfully installed 'jtime' command."
else
    echo "Error: Cannot write to /usr/local/bin. Try running with sudo."
    exit 1
fi

# Create .gitignore if it doesn't exist
if [ ! -f "$SCRIPT_DIR/.gitignore" ]; then
    echo ".env" > "$SCRIPT_DIR/.gitignore"
    echo "Created .gitignore file"
fi

echo "Installation complete! You can now use the 'jtime' command from anywhere." 