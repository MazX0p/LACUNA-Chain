# LACUNA Chain

**Six-layer call-stack spoofing via `.pdata` lacunae — defeats ETW-Ti, kernel callbacks, CET shadow stack, and return-address validation in a single composite chain.**

## Overview

LACUNA Chain exploits executable code regions with no `.pdata` `RUNTIME_FUNCTION` coverage ("lacunae") across `ntdll`, `kernelbase`, `wow64`, and `win32u` to build a fake but structurally valid call stack. When ETW-Ti fires an APC during `NtDelayExecution(alertable)`, the kernel unwinds through ghost frames instead of real callers — every layer passes `RtlLookupFunctionEntry` as a leaf with no unwind record, so the chain survives both frame-pointer and unwind-based walks.

## Techniques

| # | Technique | Description |
|---|-----------|-------------|
| 1 | **BYOUD-Gap** | Zero-modification call-stack spoofing using `.pdata` gaps — addresses between `RUNTIME_FUNCTION` entries are treated as leaf by `RtlVirtualUnwind` (RSP += 8) |
| 2 | **BYOUD-MF** | Machine Frame RSP Teleport via `UWOP_PUSH_MACHFRAME` (opcode 10) — reads RSP from stack+0x18 to jump the unwinder to a controlled address |
| 3 | **BYOUD-RT** | Runtime RSP calculation from `TEB.StackBase` (`GS:[0x08]`) for depth-aware frame placement |
| 4 | **ETW-Ti APC Window** | Exploits the `USER_APC` timing gap — the kernel collects the call stack while the thread is in an alertable wait with a spoofed stack |
| 5 | **Win32u NOP Gap Chain** | Uses 8-byte NOPs (`0F 1F 84 00 00 00 00 00`) between syscall stubs — whitelist-immune since no EDR rule covers `win32u` interior |
| 6 | **Parameter Encryption** | Hardware breakpoint VEH handler decrypts syscall parameters (RCX/RDX/R8/R9) at the last moment via `EXCEPTION_SINGLE_STEP` on DR0 |
| 7 | **Indirect Syscalls** | JMP to ntdll's own `syscall; ret` gadget so RIP is inside `ntdll.dll` at kernel entry |
| 8 | **Ghost Gadget Scanning** | Enumerates `JMP [RBX]` (`FF 23`) instructions inside ghost functions as ROP primitives |
| 9 | **Section-Based Injection** | `NtCreateSection` + `NtMapViewOfSection` x2 replacing the `VirtualAlloc`/`WriteProcessMemory`/`VirtualProtect` triad |

## The Chain

```
Layer 0  ntdll!KiUserExceptionDispatcher+4     BYOUD-MF anchor (UWOP_PUSH_MACHFRAME teleport)
Layer 1  wow64+0x17795-0x177EF                 Ghost frame — WoW64 exception-prep cover
Layer 2  kernelbase+0x64132-0x6421F            Ghost frame — VirtualProtect return-site cover
Layer 3  ntdll+0x50F2B-0x50FFF                 Ghost frame — thread-creation semantic layer
Layer 4  win32u+(NOP gap address)              Ghost frame — whitelist-immune, all known rules skip
Layer 5  ntdll!RtlUserThreadStart+0x21         Standard thread root terminator
```

## Build

Cross-compile from Linux using mingw-w64:

```bash
chmod +x build.sh
./build.sh
```

Or manually:

```bash
x86_64-w64-mingw32-gcc -O0 -masm=intel -fno-omit-frame-pointer \
    -Wall -Wno-unused-function -Wno-frame-address \
    -o lacuna.exe lacuna_chain.c -lkernel32 -lntdll
```

## Usage

```
lacuna.exe scan                     # enumerate ghost regions + gadgets across all DLLs
lacuna.exe verify                   # build chain and walk L0(MF)->L1->L2->L3->L4->L5
lacuna.exe inject <pid> <sc.bin>    # section-based APC injection with full chain
```

## Research

Full write-up: [LACUNA Chain: Ghost Frames — Forging Plausible Call Stacks from .pdata Lacunae](https://0xmaz.me/posts/LACUNA-Chain-Ghost-Frames-defeats-All-EDR-layers-of-call-stack-based-detection/)

## Author

Mohamed Alzhrani ([@0xmaz](https://0xmaz.me))

## Disclaimer

This tool is provided for authorized security research, penetration testing, and educational purposes only. The author is not responsible for any misuse.
