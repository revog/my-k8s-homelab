#!/bin/sh

FILEBOT_NODE_URL="filebot-node:5452"
FILEBOT_JOB_ID=5	# get current ID from http://<FileBotHost>:8502/
EXTRACTED_FOLDER="/extracted-downloads/"
LIST=""

for d in $EXTRACTED_FOLDER/*; do
  LIST=$LIST+"- $d"
done

curl http://$FILEBOT_NODE_URL/task?id=$FILEBOT_JOB_ID
