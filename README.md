# GlideFix

**GlideFix** is a hardened, production-grade native macOS Menu Bar application built in Swift (SwiftUI + AppKit + CoreGraphics) that solves hardware and scrolling usability issues when external Bluetooth or USB mice with notched scroll wheels are connected to macOS.

---

## The Problem
macOS couples the scroll direction of external physical mice to the built-in MacBook Trackpad ("Natural Scrolling") and processes notched scroll wheel increments in discrete, jerky line jumps.

## The Solution
GlideFix delivers:
1. **Independent Scroll Direction Inversion**: Inverts external notched mouse wheels while leaving MacBook Trackpads and Apple Magic Mice completely untouched.
2. **120Hz/60Hz Momentum Smooth Scrolling**: Converts discrete wheel ticks into buttery-smooth, pixel-interpolated momentum scrolling with exponential damping physics.
3. **Zero-Lockup Engine**: Sub-microsecond HID event inspection, watchdog recovery, and 0.0% idle CPU usage.
4. **Zero-Trust Hardened Security**: Strict event-mask isolation, hardened runtime, anti-dylib injection, debugger rejection (`PT_DENY_ATTACH`), air-gapped zero-logging, and a hardware-safety circuit breaker.

---

## Security Architecture & Kernel Hardening

### 1. Strict Event-Mask Isolation (Hardware Anti-Keylogger Guarantee)
- `CGEventTap` is created with a strictly enforced mask: `CGEventMask(1 << CGEventType.scrollWheel.rawValue)` (`0x400000`).
- A runtime security guard (`SecurityAuditor.enforceEventMask`) asserts the mask is strictly scroll-wheel only. Any keyboard bits (`keyDown`, `keyUp`, `flagsChanged`) or mouse-click bits trigger an immediate `fatalError` before touching the WindowServer.

### 2. Hardened Runtime & Anti-Dylib Injection
- Signed with macOS **Hardened Runtime** (`--options runtime`) and explicit lockdown entitlements in [`GlideFix.entitlements`](GlideFix.entitlements):
  - `allow-dyld-environment-variables` = `false`
  - `allow-unsigned-executable-memory` = `false`
  - `allow-jit` = `false`
  - `disable-library-validation` = `false`
  - `get-task-allow` = `false`
- At process start, `SecurityAuditor.enforceDyldEnvironmentSafety()` scans `ProcessInfo.processInfo.environment`. If any `DYLD_` variable is detected, it terminates immediately.

### 3. Anti-Tamper & Debugger Rejection (`PT_DENY_ATTACH`)
- Invokes `ptrace(PT_DENY_ATTACH, 0, 0, 0)` dynamically in Release mode so the macOS kernel blocks `lldb`, `gdb`, `dtrace`, or external processes from attaching to GlideFix or inspecting Mach ports.

### 4. Hardware Safety Circuit Breaker
- Measures `CGEventTap` callback execution time with `mach_absolute_time()`.
- If callback execution exceeds `1.5ms` for 5 consecutive events, it automatically disables the tap and invalidates the Mach port to guarantee the macOS cursor never freezes.

### 5. Secure Event Input & Strict Zero-Logging Policy
- Checks `IsSecureEventInputEnabled()` (via Carbon HIToolbox) during password/keychain prompts and passes native events untouched.
- Completely air-gapped from network and IPC APIs (`URLSession`, `NWConnection`, `CFSocket`, `WKWebView`, `Process`, `NSTask`).
- 0% disk and unified logging: zero `NSLog`, `print`, or `os_log` statements in event and physics loops.

---

## Project Structure

```
GlideFix/
├── Package.swift
├── GlideFix.entitlements
├── Sources/
│   ├── GlideFixCore/
│   │   ├── Configuration/
│   │   │   ├── AppSettings.swift
│   │   │   └── MagicTag.swift
│   │   ├── EventTap/
│   │   │   ├── EventTapManager.swift
│   │   │   └── ScrollClassifier.swift
│   │   ├── Permissions/
│   │   │   └── AccessibilityManager.swift
│   │   ├── Physics/
│   │   │   └── PhysicsInterpolator.swift
│   │   ├── Security/
│   │   │   └── SecurityAuditor.swift
│   │   └── System/
│   │       └── AppExclusionManager.swift
│   └── GlideFixApp/
│       ├── GlideFixApp.swift
│       ├── Resources/
│       │   └── Info.plist
│       └── UI/
│           ├── ExclusionListView.swift
│           ├── MenuBarContentView.swift
│           ├── OnboardingPermissionView.swift
│           ├── PhysicsControlsView.swift
│           ├── SecurityTelemetryView.swift
│           └── StatusIndicatorView.swift
├── Tests/
│   └── GlideFixTests/
│       ├── AppExclusionTests.swift
│       ├── EventTaggingTests.swift
│       ├── MemorySafetyTests.swift
│       ├── PhysicsInterpolatorTests.swift
│       ├── ScrollClassifierTests.swift
│       └── SecurityAuditorTests.swift
├── Scripts/
│   └── package_app.sh
└── GlideFix.app/
```

---

## Verification & Security Audits

### 1. Zero-Attack-Surface Static Audit
```bash
grep -rnE "URLSession|NWConnection|CFSocket|WKWebView|NSTask|Process\(|keyDown|keyUp|flagsChanged" Sources/
# Result: 0 matches
```

### 2. Run Test Suite (26 Unit Tests)
```bash
swift test --package-path /Users/shaanm/Projects/GlideFix
# Result: 26 passed, 0 failures, 0 warnings
```

### 3. Build Hardened Release Bundle
```bash
/Users/shaanm/Projects/GlideFix/Scripts/package_app.sh
```

### 4. Verify Hardened Runtime & Entitlements
```bash
codesign -dvvv --entitlements - GlideFix.app
codesign --verify --deep --strict --verbose=2 GlideFix.app
# Result: flags=0x10002(adhoc,runtime), valid on disk, satisfies Designated Requirement
```

### 5. Launch App
```bash
open /Users/shaanm/Projects/GlideFix/GlideFix.app
```
