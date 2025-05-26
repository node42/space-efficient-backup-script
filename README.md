# space-efficient-backup-script
Shell script to backup a given directory structure to a given directory. Backups leverage hardlinks so unchanged files are only recorded once. The intent is create a _very_ simple version of Apple's backup functionality for a given directory and require minimal dependencies.

# Usage
```bash
# Like cp or mv the syntax is source to target.
chmod ug+x /path/to/space-efficient-backup.sh # As needed ;)
/path/to/space-efficient-backup.sh /dir/to/backup /dir/to/keep/backups/in
```

# Backup Directory Example
```bash
drwx------ 1 myuser mygroup 246 May 26 10:54 2025-05-26_10-54-27
drwx------ 1 myuser mygroup 246 May 26 10:54 2025-05-26_11-17-29
lrwxrwxrwx 1 myuser mygroup  87 May 26 11:17 latest -> /run/media/node42/mymedia/home_backups/2025-05-26_11-17-29
```

# Requirements
1. The bash shell executable as `/bin/bash`
1. `rsync` version `2.6.0` or later (2004 or later)
1. The `date` command
1. The `mkdir` command
1. The `tee` command
1. The `echo` command
1. read permission to the source directory structure
1. read and write (and execute) permission the the target directory

# Notes
1. The backup sets are named use the local time with resolution to the secong (like `2025-05-26_10-44-53`)
1. The latest backup is available via the symbolic link `latest` in the backup target directory
1. Logs are hardcoded to be stored in the source directory in `.logs/` (created by the script as needed)
1. The logs for this job are not backed up as part of this script
1. This is created for personal use and doesn't have much edge case migigation logic
1. No data (personal or otherwise) is identified, recorded, or transmitted outside of what is written to the backup target directory
1. No network connectivity is needed (or used) (unless your target directory is on a network filesystem)
