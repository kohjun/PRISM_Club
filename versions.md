# Pinned Tool Versions

Per `docs/01_TECH_STACK.md` §8, this records the toolchain versions used during PRISM Club milestone 1 development. Recorded 2026-05-16.

| Tool | Version | Notes |
|---|---|---|
| Node.js | 24.13.1 | from `node --version` |
| npm | 11.8.0 | bundled with Node 24 |
| Docker | 28.4.0 | Docker Desktop on Windows |
| Flutter | (not yet installed on PATH) | binary at `C:\Users\kohju\flutter\bin\flutter.bat` |
| Dart | (bundled with Flutter SDK) | binary at `C:\Users\kohju\flutter\bin\cache\dart-sdk\bin\dart.exe` |
| PostgreSQL | 16.14 | via Docker (`postgres:16-alpine`) |
| Redis | 7 | via Docker (defined but unused in milestone 1) |

## Notes

- **pnpm was not used** despite the original plan recommendation: `corepack enable pnpm` failed with `EPERM` on this Windows machine (Node lives in `C:\Program Files\nodejs\` which requires admin to modify). Switched to npm workspaces.
- **Turborepo not adopted** for milestone 1 — npm workspace scripts are sufficient at this size. Can be added later when build orchestration matters more.
- **Flutter not yet on PATH.** Backend work (Tasks #1–5) proceeds without it. Before Task #6, either add `C:\Users\kohju\flutter\bin` to the user PATH or call `flutter.bat` by absolute path.
