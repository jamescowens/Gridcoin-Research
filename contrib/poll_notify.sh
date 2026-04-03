#!/usr/bin/env bash

# (C) 2025 The Gridcoin Developers
# Distributed under the MIT/X11 software license, see the accompanying
# file COPYING or https://opensource.org/licenses/mit-license.php.


# A basic script for poll notification with Gridcoin, normally to
# be used with the -pollnotify=<cmd> Gridcoin startup or config file
# argument.
#
# If using this script with -pollnotify, the command string should
# appear like the following:
#
# -pollnotify="/path/to/script/poll_notify.sh <gridcoin daemon executable> <gridcoin data directory> <network> <sender email address> <recipient email address> %s1 %s2"
#
# The script requires the command-line version of gridcoin, gridcoinresearchd,
# jq (the JSON parser), and properly configured mailx.

export LC_ALL=C

# Check if the correct number of arguments is provided
if [ "$#" -ne 7 ]; then
    echo "Usage: $0 <gridcoin daemon executable> <gridcoin data directory> <network> <sender email address> <recipient email_address> <poll_txid> <notification_type>"
    echo "The gridcoin executable should include the path. Specify the data directory for the node. For network, specify mainnet or testnet."
    exit 1
fi

# Assign input arguments to variables
GRIDCOIN_EXECUTABLE="$1"
GRIDCOIN_DATA_DIRECTORY="$2"

GRIDCOIN_NETWORK=""
if [[ "$3" == "testnet" ]]; then
    GRIDCOIN_NETWORK="-testnet"
fi

SENDER_EMAIL_ADDRESS="$4"
RECIPIENT_EMAIL_ADDRESS="$5"
POLL_TXID="$6"
NOTIFICATION_TYPE="$7"

# Fetch all poll details using gridcoinresearchd
ALL_POLLS=$("$GRIDCOIN_EXECUTABLE" -datadir="$GRIDCOIN_DATA_DIRECTORY" "$GRIDCOIN_NETWORK" listpolls true 2>/dev/null)

# Check if the poll list was retrieved successfully
if [ -z "$ALL_POLLS" ]; then
    echo "Failed to retrieve poll list."
    exit 2
fi

# Extract poll details for the specific TXID using jq
POLL_DETAILS=$(echo "$ALL_POLLS" | jq --arg txid "$POLL_TXID" '.[] | select(.id == $txid)')

# Check if the poll details for the given TXID were found
if [ -z "$POLL_DETAILS" ]; then
    echo "Poll with TXID $POLL_TXID not found."
    exit 3
fi

# Extract specific fields from the poll details
POLL_TITLE=$(echo "$POLL_DETAILS" | jq -r '.title')
POLL_QUESTION=$(echo "$POLL_DETAILS" | jq -r '.question')
POLL_URL=$(echo "$POLL_DETAILS" | jq -r '.url')
POLL_TYPE=$(echo "$POLL_DETAILS" | jq -r '.poll_type')
POLL_EXPIRATION=$(echo "$POLL_DETAILS" | jq -r '.expiration')
POLL_CHOICES=$(echo "$POLL_DETAILS" | jq -r '.choices | map(.label) | join(", ")')
POLL_ADDITIONAL_FIELDS=$(echo "$POLL_DETAILS" | jq -r '.additional_fields | map("\(.name): \(.value)") | join("\n")')

# Subject and body for the email
EMAIL_SUBJECT="Poll \"$POLL_TITLE\" $NOTIFICATION_TYPE"
EMAIL_BODY="Poll Notification:\\n
Title: $POLL_TITLE\n
Type: $POLL_TYPE\n
Question: $POLL_QUESTION\n
Expiration: $POLL_EXPIRATION\n
Choices: $POLL_CHOICES\n
Additional Details:\n$POLL_ADDITIONAL_FIELDS\n
Poll URL: $POLL_URL\n
Notification Type: $NOTIFICATION_TYPE\n
Poll TXID: $POLL_TXID\n
This is an automated notification sent by Gridcoin."

# Send the email using mailx and check if the email was sent successfully
if echo -e "$EMAIL_BODY" | mailx -r "$SENDER_EMAIL_ADDRESS" -s "$EMAIL_SUBJECT" "$RECIPIENT_EMAIL_ADDRESS"; then
    echo "Notification email sent to $RECIPIENT_EMAIL_ADDRESS successfully."
else
    echo "Failed to send email to $RECIPIENT_EMAIL_ADDRESS."
    exit 4
fi
