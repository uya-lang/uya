#!/bin/bash

echo "Running TDD tests for Uya compiler..."

# Test 1: Enum feature
echo "Test 1: Enum feature"
./uyac tests/test_enum_simple.uya test_enum_simple_gen.c
if [ $? -eq 0 ]; then
    gcc -o test_enum_simple test_enum_simple_gen.c 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ Enum feature: Generated C code compiles successfully with GCC"
        ./test_enum_simple
        if [ $? -eq 0 ]; then
            echo "✓ Enum feature: Executable runs successfully"
        else
            echo "✗ Enum feature: Executable failed to run"
        fi
    else
        echo "✗ Enum feature: Generated C code failed to compile with GCC"
    fi
else
    echo "✗ Enum feature: Failed to generate C code"
fi

# Test 2: Basic functionality still works
echo ""
echo "Test 2: Basic functionality"
./uyac tests/simple_test.uya test_basic_gen.c
if [ $? -eq 0 ]; then
    gcc -o test_basic test_basic_gen.c 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ Basic functionality: Generated C code compiles successfully with GCC"
        ./test_basic
        if [ $? -eq 0 ]; then
            echo "✓ Basic functionality: Executable runs successfully"
        else
            echo "✗ Basic functionality: Executable failed to run"
        fi
    else
        echo "✗ Basic functionality: Generated C code failed to compile with GCC"
    fi
else
    echo "✗ Basic functionality: Failed to generate C code"
fi

echo ""
echo "TDD tests completed."