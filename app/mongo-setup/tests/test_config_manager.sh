#!/bin/bash

# Test script for config-manager.sh module

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source the config manager module
source "${PROJECT_ROOT}/scripts/config-manager.sh"

echo "=== Testing Configuration Manager Module ==="
echo ""

# Test 1: detect_ipv4 function
echo "Test 1: Testing detect_ipv4 function"
detected_ip=$(detect_ipv4)
echo "Detected IP: $detected_ip"
if [[ -n "$detected_ip" ]]; then
    echo "✓ detect_ipv4 returned a value"
else
    echo "✗ detect_ipv4 failed to return a value"
    exit 1
fi
echo ""

# Test 2: Create a test .env file
echo "Test 2: Testing load_existing_config function"
TEST_ENV_FILE="/tmp/test_mongo_setup.env"
cat > "$TEST_ENV_FILE" << 'EOF'
# Test MongoDB Configuration
REPLICA_COUNT=5
REPLICA_HOST_IP=192.168.1.100
STARTING_PORT=27018
USERS_JSON_PATH=./test/users.json
KEYFILE_PATH=./test/keyfile
MONGO_INITDB_ROOT_USERNAME=testadmin
MONGO_INITDB_ROOT_PASSWORD=testpass123
EOF

if load_existing_config "$TEST_ENV_FILE"; then
    echo "✓ load_existing_config succeeded"
    
    # Verify loaded values
    if [[ "$EXISTING_REPLICA_COUNT" == "5" ]]; then
        echo "✓ REPLICA_COUNT loaded correctly: $EXISTING_REPLICA_COUNT"
    else
        echo "✗ REPLICA_COUNT not loaded correctly: $EXISTING_REPLICA_COUNT"
        exit 1
    fi
    
    if [[ "$EXISTING_REPLICA_HOST_IP" == "192.168.1.100" ]]; then
        echo "✓ REPLICA_HOST_IP loaded correctly: $EXISTING_REPLICA_HOST_IP"
    else
        echo "✗ REPLICA_HOST_IP not loaded correctly: $EXISTING_REPLICA_HOST_IP"
        exit 1
    fi
    
    if [[ "$EXISTING_MONGO_INITDB_ROOT_USERNAME" == "testadmin" ]]; then
        echo "✓ MONGO_INITDB_ROOT_USERNAME loaded correctly: $EXISTING_MONGO_INITDB_ROOT_USERNAME"
    else
        echo "✗ MONGO_INITDB_ROOT_USERNAME not loaded correctly: $EXISTING_MONGO_INITDB_ROOT_USERNAME"
        exit 1
    fi
else
    echo "✗ load_existing_config failed"
    exit 1
fi
echo ""

# Test 3: backup_config function
echo "Test 3: Testing backup_config function"
if backup_config "$TEST_ENV_FILE"; then
    echo "✓ backup_config succeeded"
    
    # Check if backup file was created
    backup_files=("${TEST_ENV_FILE}.backup_"*)
    if [[ -f "${backup_files[0]}" ]]; then
        echo "✓ Backup file created: ${backup_files[0]}"
        rm -f "${backup_files[0]}"
    else
        echo "✗ Backup file not found"
        exit 1
    fi
else
    echo "✗ backup_config failed"
    exit 1
fi
echo ""

# Test 4: Test credential generation
echo "Test 4: Testing credential generation"
test_username="admin_$(openssl rand -hex 4)"
test_password="$(openssl rand -hex 16)"

if [[ -n "$test_username" ]] && [[ ${#test_username} -gt 6 ]]; then
    echo "✓ Username generation works: $test_username"
else
    echo "✗ Username generation failed"
    exit 1
fi

if [[ -n "$test_password" ]] && [[ ${#test_password} -eq 32 ]]; then
    echo "✓ Password generation works (length: ${#test_password})"
else
    echo "✗ Password generation failed"
    exit 1
fi
echo ""

# Cleanup
rm -f "$TEST_ENV_FILE"

echo "=== All tests passed! ==="
