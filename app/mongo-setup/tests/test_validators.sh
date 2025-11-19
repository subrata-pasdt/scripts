#!/bin/bash

# Test script for validators.sh

# Source the validators module
source scripts/validators.sh

echo "=== Testing validate_integer ==="
echo "Test 1: Valid integer (5, range 1-10)"
validate_integer "5" 1 10 "Test value" && echo "✓ PASS" || echo "✗ FAIL"

echo -e "\nTest 2: Invalid - below range (0, range 1-10)"
validate_integer "0" 1 10 "Test value" && echo "✗ FAIL" || echo "✓ PASS (correctly rejected)"

echo -e "\nTest 3: Invalid - above range (11, range 1-10)"
validate_integer "11" 1 10 "Test value" && echo "✗ FAIL" || echo "✓ PASS (correctly rejected)"

echo -e "\nTest 4: Invalid - not a number (abc)"
validate_integer "abc" 1 10 "Test value" && echo "✗ FAIL" || echo "✓ PASS (correctly rejected)"

echo -e "\n=== Testing validate_ipv4 ==="
echo "Test 5: Valid IPv4 (192.168.1.1)"
validate_ipv4 "192.168.1.1" && echo "✓ PASS" || echo "✗ FAIL"

echo -e "\nTest 6: Valid IPv4 (10.0.0.1)"
validate_ipv4 "10.0.0.1" && echo "✓ PASS" || echo "✗ FAIL"

echo -e "\nTest 7: Invalid - octet > 255 (192.168.1.256)"
validate_ipv4 "192.168.1.256" && echo "✗ FAIL" || echo "✓ PASS (correctly rejected)"

echo -e "\nTest 8: Invalid - wrong format (192.168.1)"
validate_ipv4 "192.168.1" && echo "✗ FAIL" || echo "✓ PASS (correctly rejected)"

echo -e "\n=== Testing validate_port ==="
echo "Test 9: Valid port (27017)"
validate_port "27017" && echo "✓ PASS" || echo "✗ FAIL"

echo -e "\nTest 10: Valid port (1024)"
validate_port "1024" && echo "✓ PASS" || echo "✗ FAIL"

echo -e "\nTest 11: Invalid - below range (1023)"
validate_port "1023" && echo "✗ FAIL" || echo "✓ PASS (correctly rejected)"

echo -e "\nTest 12: Invalid - above range (65536)"
validate_port "65536" && echo "✗ FAIL" || echo "✓ PASS (correctly rejected)"

echo -e "\n=== Testing validate_path ==="
echo "Test 13: Valid path (./scripts/users.json)"
validate_path "./scripts/users.json" && echo "✓ PASS" || echo "✗ FAIL"

echo -e "\nTest 14: Invalid - non-existent directory (/nonexistent/path/file.txt)"
validate_path "/nonexistent/path/file.txt" && echo "✗ FAIL" || echo "✓ PASS (correctly rejected)"

echo -e "\n=== Testing validate_replica_count ==="
echo "Test 15: Valid replica count (3)"
validate_replica_count "3" && echo "✓ PASS" || echo "✗ FAIL"

echo -e "\nTest 16: Valid replica count (1)"
validate_replica_count "1" && echo "✓ PASS" || echo "✗ FAIL"

echo -e "\nTest 17: Valid replica count (50)"
validate_replica_count "50" && echo "✓ PASS" || echo "✗ FAIL"

echo -e "\nTest 18: Invalid - below range (0)"
validate_replica_count "0" && echo "✗ FAIL" || echo "✓ PASS (correctly rejected)"

echo -e "\nTest 19: Invalid - above range (51)"
validate_replica_count "51" && echo "✗ FAIL" || echo "✓ PASS (correctly rejected)"

echo -e "\n=== All tests completed ==="
