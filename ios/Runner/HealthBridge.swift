import Flutter
import HealthKit

struct HealthMetric {
    let key: String
    let category: String
    let type: HKSampleType
    let unit: HKUnit?
    let symbol: String

    static let catalog: [HealthMetric] = {
        let rate = HKUnit.count().unitDivided(by: .minute())
        let specs: [(String, String, HKQuantityTypeIdentifier, HKUnit, String)] = [
            ("steps","activity",.stepCount,.count(),"steps"),
            ("active_energy","activity",.activeEnergyBurned,.kilocalorie(),"kcal"),
            ("resting_energy","activity",.basalEnergyBurned,.kilocalorie(),"kcal"),
            ("distance","activity",.distanceWalkingRunning,.meter(),"m"),
            ("exercise","activity",.appleExerciseTime,.minute(),"min"),
            ("weight","body",.bodyMass,.gramUnit(with: .kilo),"kg"),
            ("body_fat","body",.bodyFatPercentage,.percent(),"%"),
            ("lean_mass","body",.leanBodyMass,.gramUnit(with: .kilo),"kg"),
            ("bmi","body",.bodyMassIndex,.count(),"kg/m²"),
            ("calories","nutrition",.dietaryEnergyConsumed,.kilocalorie(),"kcal"),
            ("protein","nutrition",.dietaryProtein,.gram(),"g"),
            ("carbs","nutrition",.dietaryCarbohydrates,.gram(),"g"),
            ("fat","nutrition",.dietaryFatTotal,.gram(),"g"),
            ("fibre","nutrition",.dietaryFiber,.gram(),"g"),
            ("water","nutrition",.dietaryWater,.literUnit(with: .milli),"mL"),
            ("resting_hr","recovery",.restingHeartRate,rate,"bpm"),
            ("hrv","recovery",.heartRateVariabilitySDNN,.secondUnit(with: .milli),"ms"),
            ("respiration","recovery",.respiratoryRate,rate,"breaths/min")
        ]
        var metrics = specs.compactMap { key, category, id, unit, symbol -> HealthMetric? in
            guard let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
            return HealthMetric(key: key, category: category, type: type, unit: unit, symbol: symbol)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            metrics.append(HealthMetric(key: "sleep", category: "recovery", type: sleep, unit: nil, symbol: "stage"))
        }
        return metrics
    }()

    func value(_ quantity: HKQuantity) -> Double {
        let n = quantity.doubleValue(for: unit!)
        return key == "body_fat" ? n * 100 : n
    }
}

final class HealthBridge {
    private let store = HKHealthStore()
    private let channel: FlutterMethodChannel
    private var observers = [HKObserverQuery]()
    private var pending = [UUID: () -> Void]()
    private var ready = false
    // Exclude the installation binding from backup and device migration.
    private var grantURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HealthSync", isDirectory: true)
            .appendingPathComponent("grant.plist")
    }

    private func localGrant() -> [String: Any]? {
        guard let data = try? Data(contentsOf: grantURL) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    private func saveGrant(_ grant: [String: Any]) throws {
        var directory = grantURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var options = URLResourceValues()
        options.isExcludedFromBackup = true
        try directory.setResourceValues(options)
        let data = try PropertyListSerialization.data(fromPropertyList: grant, format: .binary, options: 0)
        try data.write(to: grantURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "gain_guide/health", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, reply in self?.handle(call, reply) }
        if HKHealthStore.isHealthDataAvailable() { watch() }
    }

    private func watch() {
        observers.forEach { store.stop($0) }
        observers.removeAll()
        let grant = localGrant()
        let categories = grant?["categories"] as? [String] ?? []
        for metric in HealthMetric.catalog {
            guard categories.contains(metric.category) else {
                if grant != nil { store.disableBackgroundDelivery(for: metric.type) { _,_ in } }
                continue
            }
            let query = HKObserverQuery(sampleType: metric.type, predicate: nil) { [weak self] _, done, error in
                DispatchQueue.main.async {
                    guard let self = self, error == nil else { done(); return }
                    let id = UUID()
                    self.pending[id] = done
                    if self.ready { self.notify(id) }
                    // iOS may suspend the process. Unacknowledged database pages
                    // are replayed from HealthKit on the next opportunity.
                    DispatchQueue.main.asyncAfter(deadline: .now()+20) { self.pending.removeValue(forKey: id)?() }
                }
            }
            observers.append(query)
            store.execute(query)
            store.enableBackgroundDelivery(for: metric.type, frequency: .hourly) { _,_ in }
        }
    }

    private func notify(_ id: UUID) {
        channel.invokeMethod("changed", arguments: nil) { [weak self] _ in
            self?.pending.removeValue(forKey: id)?()
        }
    }

    private func handle(_ call: FlutterMethodCall, _ reply: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let fail = { reply(FlutterError(code: "health_query", message: "Apple Health could not complete the request.", details: nil)) }
        let grant = localGrant()
        switch call.method {
        case "ready":
            ready = true
            for id in Array(pending.keys) { notify(id) }
            reply(nil)
        case "available": reply(HKHealthStore.isHealthDataAvailable())
        case "grant": reply(grant)
        case "zone": reply(TimeZone.current.identifier)
        case "bind":
            do { try saveGrant(args) } catch { fail(); return }
            watch()
            reply(nil)
        case "unbind":
            if FileManager.default.fileExists(atPath: grantURL.path) {
                do { try FileManager.default.removeItem(at: grantURL) } catch { fail(); return }
            }
            watch()
            store.disableAllBackgroundDelivery { _,_ in }
            reply(nil)
        case "authorize":
            let categories = args["categories"] as? [String] ?? []
            let types = Set<HKObjectType>(HealthMetric.catalog.filter { categories.contains($0.category) }.map { $0.type })
            store.requestAuthorization(toShare: [], read: types) { success,_ in
                DispatchQueue.main.async { if success { reply(nil) } else { fail() } }
            }
        case "metrics":
            reply(HealthMetric.catalog.filter { (grant?["categories"] as? [String] ?? []).contains($0.category) }.map { $0.key })
        case "page", "totals":
            guard let revision = args["revision"] as? String, revision == grant?["revision"] as? String,
                  let owner = args["owner"] as? String, owner == grant?["owner"] as? String,
                  let metric = HealthMetric.catalog.first(where: { $0.key == args["metric"] as? String }),
                  (grant?["categories"] as? [String] ?? []).contains(metric.category),
                  let epoch = args["since"] as? Double, let zoneID = args["zone"] as? String,
                  let zone = TimeZone(identifier: zoneID) else { fail(); return }
            let start = Date(timeIntervalSince1970: epoch)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
            if call.method == "totals" {
                totals(metric, predicate, start, zone, reply)
            } else {
                var anchor: HKQueryAnchor?
                if let encoded = args["anchor"] as? String {
                    guard let data = Data(base64Encoded: encoded),
                          let decoded = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
                    else { fail(); return }
                    anchor = decoded
                }
                let query = HKAnchoredObjectQuery(type: metric.type, predicate: predicate, anchor: anchor, limit: 400) {
                    _, samples, deleted, next, error in
                    guard error == nil, let next = next,
                          let data = try? NSKeyedArchiver.archivedData(withRootObject: next, requiringSecureCoding: true)
                    else { DispatchQueue.main.async { fail() }; return }
                    let iso = ISO8601DateFormatter()
                    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    let rows: [[String:Any]] = (samples ?? []).map { sample in
                        let source = sample.sourceRevision.source
                        let value: Double
                        if let q = sample as? HKQuantitySample { value = metric.value(q.quantity) }
                        else { value = Double((sample as! HKCategorySample).value) }
                        return ["id":sample.uuid.uuidString,"started":iso.string(from:sample.startDate),
                                "ended":iso.string(from:sample.endDate),"source":source.name,"bundle":source.bundleIdentifier,
                                "identifier":sample.sampleType.identifier,"value":value,"unit":metric.symbol]
                    }
                    DispatchQueue.main.async {
                        reply(["samples":rows,"removed":(deleted ?? []).map { $0.uuid.uuidString },
                               "anchor":data.base64EncodedString(),"cumulative":["activity","nutrition"].contains(metric.category)])
                    }
                }
                store.execute(query)
            }
        default: reply(FlutterMethodNotImplemented)
        }
    }

    private func totals(_ metric: HealthMetric, _ predicate: NSPredicate, _ start: Date, _ zone: TimeZone,
                        _ reply: @escaping FlutterResult) {
        guard let type = metric.type as? HKQuantityType else { reply(nil); return }
        var interval = DateComponents()
        interval.timeZone = zone
        interval.day = 1
        let nutrition = metric.category == "nutrition"
        let options: HKStatisticsOptions = nutrition ? [.cumulativeSum,.separateBySource] : .cumulativeSum
        let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate,
            options: options, anchorDate: start, intervalComponents: interval)
        query.initialResultsHandler = { _, collection, error in
            if let e = error as NSError?, e.domain == HKErrorDomain && e.code == HKError.Code.errorNoData.rawValue {
                DispatchQueue.main.async { reply([]) }
                return
            }
            guard let collection = collection, error == nil else {
                DispatchQueue.main.async { reply(FlutterError(code:"statistics",message:"Daily totals unavailable.",details:nil)) }
                return
            }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = zone
            formatter.dateFormat = "yyyy-MM-dd"
            var rows = [[String:Any]]()
            collection.enumerateStatistics(from: start, to: Date()) { stats,_ in
                // A mirrored food diary must not add a second copy of every meal.
                // Use one source per nutrient/day, preferring MyFitnessPal.
                let quantity: HKQuantity?
                if nutrition {
                    let sources = (stats.sources ?? []).sorted {
                        let a = $0.bundleIdentifier.lowercased(), b = $1.bundleIdentifier.lowercased()
                        if a.contains("myfitnesspal") != b.contains("myfitnesspal") { return a.contains("myfitnesspal") }
                        return a < b
                    }
                    quantity = sources.lazy.compactMap { stats.sumQuantity(for: $0) }.first
                } else { quantity = stats.sumQuantity() }
                if let q = quantity {
                    rows.append(["day":formatter.string(from:stats.startDate),"value":metric.value(q),"unit":metric.symbol])
                }
            }
            DispatchQueue.main.async { reply(rows) }
        }
        store.execute(query)
    }
}
