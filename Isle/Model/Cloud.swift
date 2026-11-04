import CloudKit
import Foundation
import Observation

/// Le isole anche nell'iCloud privato dell'utente: tornano dopo una reinstallazione e passano da un iPhone all'altro.
/// Un solo record con tutto il file, pochi KB anche dopo anni. Due copie diverse si uniscono senza perdere niente:
/// risposte, semi e ricadute si sommano, titolo e impostazioni vengono dalla copia toccata per ultima.
@MainActor
enum Cloud {
    private static let container = CKContainer(identifier: "iCloud.com.jacopogiannetti.isle")
    private static let recordID = CKRecord.ID(recordName: "isle")
    private static var running = false
    private static var again = false
    private static var pending: Task<Void, Never>?

    /// Le prove nel simulatore non devono finire nell'iCloud di nessuno.
    private static var off: Bool { Launch.demo }

    private struct Snapshot: Codable {
        var habits: [Habit]
        var deleted: [String]
    }

    /// Per la riga nelle impostazioni.
    @MainActor
    @Observable
    final class Status {
        /// `nil` finché non si sa se l'utente è entrato in iCloud.
        var account: Bool?
        var syncing = false
        var failed = false
        /// L'ultimo errore così com'è, mostrato solo nelle build di sviluppo.
        var error: String?
        var last = UserDefaults.standard.object(forKey: "cloudLast") as? Date {
            didSet { UserDefaults.standard.set(last, forKey: "cloudLast") }
        }
    }

    static let status = Status()

    /// All'avvio. Alla prima apertura dopo l'installazione l'app aspetta iCloud fino a dieci secondi,
    /// così chi reinstalla ritrova le sue isole invece dell'introduzione. Senza rete l'errore arriva subito.
    static func start() {
        Task {
            await sync()
            // Isole ritrovate mentre l'app si apriva: questa è l'apertura, il paywall vale.
            // Arrivate più tardi, magari a metà onboarding, aspettano la prossima.
            guard Store.shared.restoring else { return }
            Store.shared.restoring = false
            Premium.gate(Store.shared)
        }
        Task {
            try? await Task.sleep(for: .seconds(10))
            Store.shared.restoring = false
        }
        Task {
            for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                await sync()
            }
        }
    }

    /// Dopo ogni salvataggio, con un attimo di pausa: tante modifiche di fila diventano un solo invio.
    static func changed() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await sync()
        }
    }

    static func sync() async {
        guard !off else { return }
        if running {
            again = true
            while running { try? await Task.sleep(for: .milliseconds(100)) }
            return
        }
        running = true
        status.syncing = true
        defer {
            running = false
            status.syncing = false
        }
        repeat {
            again = false
            var ok = false
            // Se un altro iPhone ha scritto nel frattempo, si riprende la sua copia e si unisce di nuovo.
            for _ in 0..<3 where !ok {
                do {
                    try await round()
                    ok = true
                } catch let e as CKError where e.code == .serverRecordChanged {
                    continue
                } catch {
                    status.error = String(describing: error)
                    break
                }
            }
            status.failed = !ok
            if ok { status.error = nil }
        } while again
    }

    private static func round() async throws {
        var account = try await container.accountStatus()
        // Appena installata, iOS può rispondere "non ancora" per qualche istante.
        for _ in 0..<5 where account == .temporarilyUnavailable || account == .couldNotDetermine {
            try await Task.sleep(for: .seconds(1))
            account = try await container.accountStatus()
        }
        let available = account == .available
        status.account = available
        if !available { status.error = "accountStatus: \(account.rawValue)" }
        guard available else { return }
        let db = container.privateCloudDatabase
        var record: CKRecord?
        do {
            record = try await db.record(for: recordID)
        } catch let e as CKError where e.code == .unknownItem {
            record = nil
        }
        var remote: Snapshot?
        if let record {
            // Una copia illeggibile non va mai sostituita: dopo una reinstallazione quella di qui è vuota.
            guard let url = (record["data"] as? CKAsset)?.fileURL else { throw CocoaError(.fileReadUnknown) }
            remote = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        }

        let store = Store.shared
        let deleted = store.deleted.union(remote?.deleted ?? [])
        let habits = merge(store.habits, remote?.habits ?? [], deleted: deleted)
        store.adopt(habits, deleted: deleted)

        let mine = try encode(Snapshot(habits: habits, deleted: deleted.sorted()))
        if let remote, try encode(remote) == mine {
            status.last = Date()
            return
        }

        let file = FileManager.default.temporaryDirectory.appendingPathComponent("isle-\(UUID().uuidString).json")
        try mine.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let r = record ?? CKRecord(recordType: "Isle", recordID: recordID)
        r["data"] = CKAsset(fileURL: file)
        let result = try await db.modifyRecords(saving: [r], deleting: [], savePolicy: .ifServerRecordUnchanged)
        if case .failure(let e) = result.saveResults[recordID] { throw e }
        status.last = Date()
    }

    /// Chiavi in ordine: due copie uguali danno gli stessi byte.
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return try e.encode(value)
    }

    /// In ordine di creazione su ogni iPhone: un ordine diverso farebbe sembrare diverse due copie uguali.
    static func merge(_ local: [Habit], _ remote: [Habit], deleted: Set<String>) -> [Habit] {
        let theirs = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let mine = Set(local.map(\.id))
        let list = local.map { h in theirs[h.id].map { join(h, $0) } ?? h } + remote.filter { !mine.contains($0.id) }
        return list.filter { !deleted.contains($0.id) }.sorted { ($0.created, $0.id) < ($1.created, $1.id) }
    }

    private static func join(_ a: Habit, _ b: Habit) -> Habit {
        let aFirst = (a.edited ?? .distantPast) >= (b.edited ?? .distantPast)
        var h = aFirst ? a : b
        let other = aFirst ? b : a
        h.answers = union(a.answers, b.answers) { $0 }.sorted { $0.at < $1.at }
        h.placements = union(a.placements, b.placements, \.id).sorted { $0.at < $1.at }
        h.relapses = union(a.relapses, b.relapses, \.id).sorted { $0.at < $1.at }
        h.resists = union(a.resists, b.resists) { $0 }.sorted()
        let moves = union(a.rearranges ?? [], b.rearranges ?? []) { $0 }.sorted { $0.at < $1.at }
        h.rearranges = moves.isEmpty ? nil : moves
        let seen = union(a.skySeen ?? [], b.skySeen ?? []) { $0 }
        h.skySeen = seen.isEmpty ? nil : seen
        h.renames = other.renames.merging(h.renames) { _, newer in newer }
        h.lastVisit = [a.lastVisit, b.lastVisit].compactMap { $0 }.max()
        return h
    }

    private static func union<T, K: Hashable>(_ a: [T], _ b: [T], _ key: (T) -> K) -> [T] {
        var seen = Set<K>()
        return (a + b).filter { seen.insert(key($0)).inserted }
    }
}
