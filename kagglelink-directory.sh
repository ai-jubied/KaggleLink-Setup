#!/bin/sh
# kagglelink: default new interactive shells to the filesystem root.
# Installed to /etc/profile.d/ by setup_kaggle_zrok.sh.
#
# IMPORTANT: this must never print to stdout - output during shell startup
# corrupts rsync/scp/sftp sessions.

# Interactive shells only
case $- in
    *i*) ;;
    *) return 0 2>/dev/null || exit 0 ;;
esac

# Only change directory if we started in $HOME or the install dir
if [ "$PWD" = "$HOME" ] || [ "$PWD" = "/tmp/kagglelink" ]; then
    cd / 2>/dev/null || true
fi
