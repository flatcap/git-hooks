#!/bin/bash

for i in "$@"; do
	echo PREPARE ">>$i<<"
done

git branch -vv

# [ -s "$1" ] && cp "$1" "PREPARE_MESSAGE"

echo env:
set | grep "^GIT" | indent

# sed -i \
# 	-e '/^# Please enter the commit message for your changes. Lines starting/d' \
# 	-e '/^# with .#. will be ignored, and an empty message aborts the commit./d' \
# 	-e '/^# Do not touch the line above./d' \
# 	-e '/^# Everything below will be removed./d' "$1"

# sed -i '1s/^/hello/' "$1"

# sed -i '1a# Closes #1234 - title from bugzilla\n#' "$1"

