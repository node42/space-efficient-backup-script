#!/bin/bash

# Space efficient directory stucture backup script leveraging rsync
# Copyright (C) 2025 Mark Roderick
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This script will backup the first argument's directory tree (excluding mounted filesystems)
# to the location of the second argument. Backups sets will be stored in a space
# efficient manner using hard links to avoid duplicating the unchanged files in
# prior backap sets (see rsync's --link-dest for this magic)
#
# Only basic input validation is performed.

# Check for required arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <SOURCE_DIRECTORY> <BACKUP_BASE_DIRECTORY>"
    echo "Example: $0 /home/username /mnt/backupdev/home_directory_backups"
    exit 1
fi
SOURCE_DIR="$1"
BACKUP_BASE_DIR="$2"

# Postfix SOURCE_DIR with a '/' if it doesn't already have one
if [[ "${SOURCE_DIR}" != */ ]]; then
    SOURCE_DIR="${SOURCE_DIR}/"
fi

# Validate SOURCE_DIR
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' does not exist or is not a directory."
    exit 1
fi

# Validate BACKUP_BASE_DIR
# We create it if it doesn't exist, but we still intrinsically check if the parent
# path is writable/exists.
mkdir -p "$BACKUP_BASE_DIR" || { echo "Error: Could not create backup base directory '$BACKUP_BASE_DIR'. Check permissions."; exit 1; }

# Get current timestamp for the new backup directory & corresponding log file
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Log file for backup operations (adjust path if needed)
LOG_DIR="${SOURCE_DIR}.logs/"
LOG_FILE="${LOG_DIR}rsync_home_backup-${TIMESTAMP}.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Error: Could not create log directory for '$LOG_FILE'. Check permissions."; exit 1; }

# Ensure backup base directory exists
mkdir -p "$BACKUP_BASE_DIR" || { echo "Error: Could not create backup base directory '$BACKUP_BASE_DIR'. Check permissions."; exit 1; }

# --- Rsync Options ---
# -a: archive mode (preserves permissions, timestamps, owner, group, symlinks, etc.)
# -H: hard-links identical files (essential for space efficiency)
# -x: don't cross filesystem boundaries (important for /home if it's on a separate partition)
# -v: verbose output
# --delete: delete files from the destination that are no longer in the source (for synchronization)
# --numeric-ids: don't map uid/gid by name; use raw numeric IDs
# --progress: show progress during transfer
# --log-file=FILE: log all rsync messages to a specified file
# --link-dest=DIR: hard-link to files in DIR when unchanged
# --exclude=DIR: set to the .logs directory in the source directory
RSYNC_OPTIONS="-aHv --delete --numeric-ids --progress --log-file=\"$LOG_FILE\" --exclude=\"/.logs/\""

# Determine backup set's name and it's full path for the 'latest' symlink.
CURRENT_BACKUP_DIR="${BACKUP_BASE_DIR}/${TIMESTAMP}"
LATEST_LINK="${BACKUP_BASE_DIR}/latest"

# Check if a previous backup exists to use --link-dest
if [ -d "$LATEST_LINK" ]; then
    echo "Previous backup found at $LATEST_LINK. Using --link-dest." | tee -a "$LOG_FILE"
    RSYNC_OPTIONS="${RSYNC_OPTIONS} --link-dest=${LATEST_LINK}/"
else
    echo "No previous backup found. Performing a full initial backup." | tee -a "$LOG_FILE"
fi

echo "Starting backup of ${SOURCE_DIR} to ${CURRENT_BACKUP_DIR}" | tee -a "$LOG_FILE"
echo "Rsync command: rsync ${RSYNC_OPTIONS} \"${SOURCE_DIR}\" \"${CURRENT_BACKUP_DIR}\"" | tee -a "$LOG_FILE"

# Execute rsync using 'eval' to flatten the arguments into strings
eval rsync ${RSYNC_OPTIONS} "${SOURCE_DIR}" "${CURRENT_BACKUP_DIR}"

# Est-ce bon?
RSYNC_EXIT_CODE=$?
if [ $RSYNC_EXIT_CODE -eq 0 ]; then
    echo "Backup completed successful to: ${CURRENT_BACKUP_DIR}" | tee -a "$LOG_FILE"
    # Update the 'latest' symlink to point to the new backup
    rm -f "$LATEST_LINK"
    ln -s "${CURRENT_BACKUP_DIR}" "$LATEST_LINK"
    echo "Updated 'latest' symlink to point to: ${CURRENT_BACKUP_DIR}" | tee -a "$LOG_FILE"
elif [ $RSYNC_EXIT_CODE -eq 24 ]; then
    echo "Backup completed with some files disappearing during transfer (rsync exit code 24)." | tee -a "$LOG_FILE"
    # Still considered a success...
    rm -f "$LATEST_LINK"
    ln -s "${CURRENT_BACKUP_DIR}" "$LATEST_LINK"
    echo "Updated 'latest' symlink to point to: ${CURRENT_BACKUP_DIR}" | tee -a "$LOG_FILE"
else
    echo "Backup failed with the rsync exit code: ${RSYNC_EXIT_CODE}" | tee -a "$LOG_FILE"
    echo "Check the log file for details at: ${LOG_FILE}" | tee -a "$LOG_FILE"
fi

# Fin
echo "Backup finished at $(date)" | tee -a "$LOG_FILE"
