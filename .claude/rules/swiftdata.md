---
paths: "**/*.swift"
---

# SwiftData Rules

> **Prerequisites**: Run `/init-swift` for universal Swift guidelines. Pairs with `/init-swift-swiftui`.

### Schema Design

```swift
@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var name: String
    var startDate: Date
    @Attribute(.externalStorage) var coverPhoto: Data?      // store blobs outside the DB
    @Attribute(.allowsCloudEncryption) var notes: String?   // encrypted in CloudKit
    @Relationship(deleteRule: .cascade, inverse: \Stop.trip) var stops: [Stop] = []
    @Transient var distanceFormatter: MeasurementFormatter? // never persisted

    init(id: UUID = UUID(), name: String, startDate: Date) {
        self.id = id; self.name = name; self.startDate = startDate
    }
}
```

| Attribute | Use |
|-----------|-----|
| `.unique` | Enforce uniqueness (no `find-or-create` race) |
| `.externalStorage` | Large `Data` (images, blobs) → file on disk |
| `.allowsCloudEncryption` | Encrypt at rest in CloudKit |
| `.preserveValueOnDeletion` | Keep value in history after delete |
| `.spotlight` | Index for system search |
| `@Transient` | Computed/cached state, not persisted |

| Delete Rule | Behavior |
|-------------|----------|
| `.cascade` | Delete children with parent |
| `.nullify` | Set inverse to nil (default) |
| `.deny` | Refuse delete if children exist |
| `.noAction` | Manual cleanup required |

**Always declare `inverse:`** on one side of a relationship — avoids orphan rows and double writes.

### ModelContainer Setup

```swift
@main
struct App: App {
    let container: ModelContainer = {
        let schema = Schema([Trip.self, Stop.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.example.app")  // or .none
        )
        do { return try ModelContainer(for: schema, configurations: config) }
        catch { fatalError("ModelContainer: \(error)") }
    }()

    var body: some Scene {
        WindowGroup { ContentView() }.modelContainer(container)
    }
}
```

**CloudKit constraints:** all properties optional **or** have defaults; no `.unique`; relationships must have inverses; no `.deny` rule.

### Querying with @Query

```swift
@Query(sort: \Trip.startDate, order: .reverse) var trips: [Trip]

// Predicate — `#Predicate` macro, NOT NSPredicate
@Query(filter: #Predicate<Trip> { .name.localizedStandardContains("paris") })
var matches: [Trip]

// Dynamic predicate (changes with view state)
struct TripList: View {
    @Query private var trips: [Trip]
    init(search: String) {
        let pred = #Predicate<Trip> { search.isEmpty || .name.contains(search) }
        _trips = Query(filter: pred, sort: \Trip.startDate)
    }
}

// Fetch limit / pagination
@Query(FetchDescriptor<Trip>(predicate: nil, sortBy: [SortDescriptor(\.startDate)]),
       transaction: .init(animation: .default))
var recent: [Trip]
```

**`#Predicate` only supports a subset of Swift** — basic comparisons, string ops, optional unwrap, `contains`, arithmetic. No arbitrary closures, no captured non-Sendable types. Build complex filters in memory after fetch if needed.

### ModelContext: Mutations

```swift
@Environment(\.modelContext) private var ctx

func add(_ trip: Trip) {
    ctx.insert(trip)
    // ctx.save() is implicit on autosave; call manually only when you must
    // observe results NOW (export, sync handoff)
}

func delete(_ trip: Trip) { ctx.delete(trip) }

// Batch ops outside SwiftUI views
try ctx.transaction {
    for t in old { ctx.delete(t) }
    for t in new { ctx.insert(t) }
}  // single autosave at end
```

**Autosave** runs on app backgrounding + idle ticks. Don't sprinkle `ctx.save()` everywhere — it forces synchronous I/O.

### Migrations

**Lightweight (default):** add/remove optional properties, rename via `@Attribute(originalName:)`. Free.

**Custom:** version your schema with `VersionedSchema` + `SchemaMigrationPlan`:

```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [TripV1.self] }
}
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Trip.self] }
}
enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] {
        [.custom(fromVersion: SchemaV1.self, toVersion: SchemaV2.self,
                 willMigrate: { ctx in /* snapshot */ },
                 didMigrate:  { ctx in /* backfill */ })]
    }
}
// ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: config)
```

### Concurrency

**`ModelContext` is NOT Sendable** — never pass across actor boundaries. Use a `ModelActor` for background work:

```swift
@ModelActor
actor TripImporter {
    func importMany(_ payloads: [TripDTO]) throws {
        for p in payloads { modelContext.insert(Trip(dto: p)) }
        try modelContext.save()
    }
}
// Usage from main:
let importer = TripImporter(modelContainer: container)
try await importer.importMany(payloads)
```

**Pass `PersistentIdentifier`, not models**, between actors:
```swift
let id = trip.persistentModelID            // Sendable
await bgActor.process(id)                  // re-fetch on the other side
let trip = bgCtx.model(for: id) as? Trip
```

### Performance

| Issue | Fix |
|-------|-----|
| Slow list scrolling | `FetchDescriptor.fetchLimit`, `propertiesToFetch` |
| N+1 on relationships | `relationshipKeyPathsForPrefetching: [\.stops]` |
| Huge `Data` properties | `@Attribute(.externalStorage)` |
| Frequent `ctx.save()` | Let autosave handle it |
| Predicate too complex | Filter in memory after a narrower fetch |
| Counting rows | `ctx.fetchCount(descriptor)` — never `fetch().count` |

```swift
var fd = FetchDescriptor<Trip>(predicate: #Predicate { .startDate > cutoff })
fd.fetchLimit = 50
fd.relationshipKeyPathsForPrefetching = [\.stops]
fd.propertiesToFetch = [\.name, \.startDate]   // partial loads
let trips = try ctx.fetch(fd)
```

### Testing

In-memory container per test — fast, isolated, no disk:

```swift
@MainActor
func makeTestContext() throws -> ModelContext {
    let schema = Schema([Trip.self, Stop.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: config)
    return ModelContext(container)
}

@Test func insertingTripPersists() throws {
    let ctx = try makeTestContext()
    ctx.insert(Trip(name: "Tokyo", startDate: .now))
    let trips = try ctx.fetch(FetchDescriptor<Trip>())
    #expect(trips.count == 1)
}
```

For SwiftUI previews: `.modelContainer(for: Trip.self, inMemory: true)`.

### CloudKit Sync

- One `ModelConfiguration` per CloudKit container — they don't merge.
- Sync is eventual: don't assume a write on device A is visible on device B before the next push/pull cycle.
- Schema changes need a **production CloudKit schema deploy** before shipping.
- Test with `NSPersistentCloudKitContainer` logging: `-com.apple.CoreData.CloudKitDebug 1`.

### Common Mistakes

| ❌ Avoid | ✅ Prefer |
|----------|-----------|
| Sharing `ModelContext` across threads | `ModelActor` + `PersistentIdentifier` |
| Calling `ctx.save()` after every change | Let autosave run; save only at boundaries |
| `fetch().count` for counting | `ctx.fetchCount(descriptor)` |
| `@Attribute(.unique)` with CloudKit sync | Enforce uniqueness in app logic |
| Relationship without `inverse:` | Always declare on one side |
| Storing images as `Data` inline | `@Attribute(.externalStorage)` |
| Complex closures inside `#Predicate` | Narrow with predicate, finish in memory |
| New `ModelContainer` per view | One container at app root, inject via env |
| Mutating models off the main actor without an actor | `@ModelActor` background actor |
