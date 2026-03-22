crontab -e
# for the first time choose 1
# add this to the file:

# Restart every night at 4AM
0 4 * * * /usr/sbin/shutdown -r now

# Run backup locally on Saturdays and Tuesdays at 2:30 AM
30 2 * * 2,6 /usr/local/bin/immich_borg_backup.sh local

# Run backup remote on Wednesdays at 2:30 AM
30 2 * * 3 /usr/local/bin/immich_borg_backup.sh remote

# Save and exit