# Verification Suite

This directory contains verification scripts to ensure the correctness of the Communication Protocols driver suite.

## 1. Python Mock Verification (`mock_verify.py`)
This suite uses `unittest.mock` to simulate hardware behavior and verify the logic of the Python-based tools and prototypes.
- **Dependencies**: Python 3
- **Run**: `python mock_verify.py`

## 2. Host-Based C Unit Tests (`test_drivers.c`)
This compiles the actual driver C code against simulated register definitions (`stm32f4xx_base.h` in simulation mode) to verify bit-manipulation logic, buffer handling, and protocol state machines on your PC.
- **Dependencies**: C Compiler (MSVC `cl`, GCC, or Clang)
- **Run (Windows MSVC)**: `run_verification.bat`
- **Run (GCC/Linux)**: `gcc -std=c11 -DUNIT_TEST -I../drivers/common -I../protocol_stacks/modbus -I../protocol_stacks/usb_cdc -I../protocol_stacks/can_bus test_drivers.c -o test_drivers && ./test_drivers`

## 3. How to Run All Tests

### Windows
You need the **Visual Studio Build Tools (MSVC)** installed.

**Option A: Using Developer Command Prompt (Recommended)**
1. Open "x64 Native Tools Command Prompt for VS 2022" (Search in Start Menu).
2. Navigate to the repository root.
3. Run:
   ```cmd
   verification\run_verification.bat
   ```

**Option B: Manually setting up environment**
If you are in a standard cmd or PowerShell, you must first load the MSVC environment variables (adjust path to your version):
```cmd
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
verification\run_verification.bat
```

### Linux / macOS
```bash
# 1. Run Python mock tests
python3 verification/mock_verify.py

# 2. Compile and run C host tests
gcc -std=c11 -DUNIT_TEST \
    -Idrivers/common \
    -Iprotocol_stacks/modbus \
    -Iprotocol_stacks/usb_cdc \
    -Iprotocol_stacks/can_bus \
    verification/test_drivers.c -o test_drivers

./test_drivers
```
