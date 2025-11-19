#!/bin/bash

# Parse command line args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mailjet_api_key) MAILJET_API_KEY="$2"; shift 2 ;;
    --mailjet_api_secret) MAILJET_API_SECRET="$2"; shift 2 ;;
    --from_email) FROM_EMAIL="$2"; shift 2 ;;
    --to_email) TO_EMAIL="$2"; shift 2 ;;
    --cc) CC_EMAILS="$2"; shift 2 ;;
    --bcc) BCC_EMAILS="$2"; shift 2 ;;
    --subject) EMAIL_SUBJECT="$2"; shift 2 ;;
    --body) EMAIL_BODY="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# Validate required fields
if [ -z "$MAILJET_API_KEY" ] || [ -z "$MAILJET_API_SECRET" ] || [ -z "$FROM_EMAIL" ] || [ -z "$TO_EMAIL" ] || [ -z "$EMAIL_SUBJECT" ] || [ -z "$EMAIL_BODY" ]; then
  echo "Missing required arguments."
  exit 1
fi

# Helper function to convert comma separated emails to JSON array of objects
function emails_to_json_array() {
  local emails_csv="$1"
  local json="["
  local first=1
  IFS=',' read -ra ADDR <<< "$emails_csv"
  for email in "${ADDR[@]}"; do
    email=$(echo "$email" | xargs) # trim whitespace
    if [[ -n "$email" ]]; then
      if [ $first -eq 0 ]; then
        json+=","
      fi
      json+="{\"Email\":\"$email\"}"
      first=0
    fi
  done
  json+="]"
  echo "$json"
}

# Prepare JSON fields for To, CC, BCC
TO_JSON=$(emails_to_json_array "$TO_EMAIL")
CC_JSON=$( [ -n "$CC_EMAILS" ] && emails_to_json_array "$CC_EMAILS" || echo "null" )
BCC_JSON=$( [ -n "$BCC_EMAILS" ] && emails_to_json_array "$BCC_EMAILS" || echo "null" )

# Escape body for JSON
if command -v jq &> /dev/null; then
  EMAIL_BODY_ESCAPED=$(jq -Rn --arg txt "$EMAIL_BODY" '$txt')
else
  EMAIL_BODY_ESCAPED=$(printf '%s' "$EMAIL_BODY" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
fi




read -r -d '' MAILJET_PAYLOAD <<EOF
{
  "Messages": [
    {
      "From": {
        "Email": "$FROM_EMAIL",
        "Name": "PAS Digital Technologies"
      },
      "To": $TO_JSON$( [ "$CC_JSON" != "null" ] && echo ",      \"Cc\": $CC_JSON" )$( [ "$BCC_JSON" != "null" ] && echo ",      \"Bcc\": $BCC_JSON" ),
      "Subject": "$EMAIL_SUBJECT",
      "TextPart": $EMAIL_BODY_ESCAPED
    }
  ]
}
EOF




# echo $MAILJET_PAYLOAD

curl -s -X POST https://api.mailjet.com/v3.1/send \
  -u "$MAILJET_API_KEY:$MAILJET_API_SECRET" \
  -H "Content-Type: application/json" \
  -d "$MAILJET_PAYLOAD"