#!/bin/bash

# Parse command line args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mailjet_api_key) MAILJET_API_KEY="$2"; shift 2 ;;
    --mailjet_api_secret) MAILJET_API_SECRET="$2"; shift 2 ;;
    --from_email) FROM_EMAIL="$2"; shift 2 ;;
    --to_email) TO_EMAIL="$2"; shift 2 ;;
    --subject) EMAIL_SUBJECT="$2"; shift 2 ;;
    --body) EMAIL_BODY="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [ -z "$MAILJET_API_KEY" ] || [ -z "$MAILJET_API_SECRET" ] || [ -z "$FROM_EMAIL" ] || [ -z "$TO_EMAIL" ] || [ -z "$EMAIL_SUBJECT" ] || [ -z "$EMAIL_BODY" ]; then
  echo "Missing required arguments."
  exit 1
fi

# Escape body for JSON using jq if available, else fallback simple quoting
if command -v jq &> /dev/null; then
  EMAIL_BODY_ESCAPED=$(jq -Rn --arg txt "$EMAIL_BODY" '$txt')
else
  # basic escape (replace newlines with \n)
  EMAIL_BODY_ESCAPED=$(printf '%s' "$EMAIL_BODY" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
fi

read -r -d '' MAILJET_PAYLOAD <<EOF
{
  "Messages": [
    {
      "From": {
        "Email": "$FROM_EMAIL",
        "Name": "Backup Script"
      },
      "To": [
        {
          "Email": "$TO_EMAIL",
          "Name": "Recipient"
        }
      ],
      "Subject": "$EMAIL_SUBJECT",
      "TextPart": $EMAIL_BODY_ESCAPED
    }
  ]
}
EOF

curl -s -X POST https://api.mailjet.com/v3.1/send \
  -u "$MAILJET_API_KEY:$MAILJET_API_SECRET" \
  -H "Content-Type: application/json" \
  -d "$MAILJET_PAYLOAD"
