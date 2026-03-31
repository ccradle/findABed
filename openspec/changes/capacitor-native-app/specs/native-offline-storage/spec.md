## ADDED Requirements

### Requirement: SQLite offline queue on native
On native platforms, the offline hold queue SHALL use SQLite (via `@capacitor-community/sqlite`) instead of IndexedDB. On web, the existing IndexedDB queue continues to work unchanged.

**Acceptance criteria:**
- Platform detection: `Capacitor.isNativePlatform()` routes to SQLite; web routes to IndexedDB
- SQLite queue supports same operations: enqueue, replay, delete, getQueueSize
- Hold expiry validation works identically on both storage paths
- Data survives iOS background app termination and 7-day inactivity (the key advantage over IndexedDB)
- Existing Playwright tests pass unchanged (they test the web path)

### Requirement: Storage abstraction layer
A `StorageAdapter` interface SHALL abstract the difference between SQLite (native) and IndexedDB (web) for the offline queue.

**Acceptance criteria:**
- Single API surface: `enqueue()`, `replay()`, `getSize()`, `clear()`
- Implementation selected at runtime based on platform
- No leaking of SQLite or IndexedDB specifics into business logic
