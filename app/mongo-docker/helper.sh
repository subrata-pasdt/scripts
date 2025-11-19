# Validate email formats for FROM_EMAIL and TO_EMAIL (basic check)
validate_email() {
  local email=$1
  if ! [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo "Invalid email format: $email"
    return 1
  fi
}

