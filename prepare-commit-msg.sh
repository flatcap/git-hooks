#!/bin/bash

sed -i \
	-e '/^# Please enter the commit message for your changes. Lines starting/d' \
	-e '/^# with .#. will be ignored, and an empty message aborts the commit./d' \
	-e '/^# Do not touch the line above./d' \
	-e '/^# Everything below will be removed./d' "$1"

