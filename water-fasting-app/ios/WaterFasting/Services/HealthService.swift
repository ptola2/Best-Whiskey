import Foundation
import HealthKit
import Observation

/// What a check-in form took from Apple Health, so those values are not written back as duplicates.
struct HealthImports: Equatable {
    struct Reading: Equatable {
        var systolic: Int
        var diastolic: Int
    }

    var weightKg: Double?
    var lying: Reading?
    var standing: Reading?
}

/// The link with Apple Health. Waterline saves the weight and blood pressure from check-ins and reads recent readings
/// (from a smart scale or blood pressure cuff, for example) to fill check-ins in. It asks for permission only when the
/// person turns the link on in Profile. Health data never leaves the iPhone through this service.
@Observable @MainActor
final class HealthService {
    static let shared = HealthService()

    struct Weight: Identifiable {
        let id: UUID
        let kg: Double
        let date: Date
    }

    struct Pressure: Identifiable {
        let id: UUID
        let systolic: Int
        let diastolic: Int
        let pulse: Int?
        let date: Date
    }

    private static let enabledKey = "waterline.appleHealth"
    /// Custom metadata on saved blood pressure, so the position survives in Health.
    private static let positionKey = "WaterlinePosition"

    private let store = HKHealthStore()

    /// The person turned the link on in Profile.
    private(set) var isOn: Bool
    private(set) var isBusy = false
    /// Saving to Health is switched off for Waterline in the Health app.
    private(set) var savingDenied = false

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {
        isOn = HKHealthStore.isHealthDataAvailable() && UserDefaults.standard.bool(forKey: Self.enabledKey)
        refreshStatus()
    }

    private var weightType: HKQuantityType { HKQuantityType(.bodyMass) }
    private var systolicType: HKQuantityType { HKQuantityType(.bloodPressureSystolic) }
    private var diastolicType: HKQuantityType { HKQuantityType(.bloodPressureDiastolic) }
    private var heartRateType: HKQuantityType { HKQuantityType(.heartRate) }
    private var pressureType: HKCorrelationType { HKCorrelationType(.bloodPressure) }

    // MARK: Switching on and off

    func setOn(_ on: Bool) async {
        guard isAvailable else { return }
        if on {
            isBusy = true
            // Blood pressure is shared through its two component types: HealthKit refuses the correlation type here.
            let share: Set<HKSampleType> = [weightType, systolicType, diastolicType]
            let read: Set<HKObjectType> = [weightType, systolicType, diastolicType, heartRateType]
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                store.requestAuthorization(toShare: share, read: read) { _, _ in continuation.resume() }
            }
            isBusy = false
        }
        isOn = on
        UserDefaults.standard.set(on, forKey: Self.enabledKey)
        refreshStatus()
    }

    /// Health only reveals whether saving is allowed (never whether reading is), so that is what the card reports.
    func refreshStatus() {
        guard isOn else {
            savingDenied = false
            return
        }
        savingDenied = store.authorizationStatus(for: weightType) == .sharingDenied
            && store.authorizationStatus(for: systolicType) == .sharingDenied
    }

    // MARK: Reading

    /// The latest weight from another app or device, within the given window.
    func latestWeight(withinHours hours: Double) async -> Weight? {
        guard isOn else { return nil }
        let found = await samples(of: weightType, predicate: recentFromOthers(hours: hours), limit: 1)
        guard let sample = found.first as? HKQuantitySample else { return nil }
        return Weight(id: sample.uuid, kg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)), date: sample.endDate)
    }

    /// Recent blood pressure readings from other apps or devices, newest first, each with the pulse the same cuff
    /// recorded at the same moment when there is one.
    func recentPressures(withinHours hours: Double, limit: Int) async -> [Pressure] {
        guard isOn else { return [] }
        let found = await samples(of: pressureType, predicate: recentFromOthers(hours: hours), limit: limit)
        let mmHg = HKUnit.millimeterOfMercury()
        var result: [Pressure] = []
        for case let correlation as HKCorrelation in found {
            guard let systolic = correlation.objects(for: systolicType).first as? HKQuantitySample,
                  let diastolic = correlation.objects(for: diastolicType).first as? HKQuantitySample,
                  let sys = Fmt.safeInt(systolic.quantity.doubleValue(for: mmHg)),
                  let dia = Fmt.safeInt(diastolic.quantity.doubleValue(for: mmHg)) else { continue }
            let pulse = await pulse(near: correlation.endDate, from: correlation.sourceRevision.source)
            result.append(Pressure(id: correlation.uuid, systolic: sys, diastolic: dia, pulse: pulse, date: correlation.endDate))
        }
        return result
    }

    /// Only the device that took the blood pressure counts, so a watch reading from the same minute is not mistaken
    /// for the cuff's pulse.
    private func pulse(near date: Date, from source: HKSource) async -> Int? {
        let window = HKQuery.predicateForSamples(withStart: date.addingTimeInterval(-120), end: date.addingTimeInterval(120))
        let sameDevice = NSCompoundPredicate(andPredicateWithSubpredicates: [window, HKQuery.predicateForObjects(from: source)])
        let found = await samples(of: heartRateType, predicate: sameDevice, limit: 10).compactMap { $0 as? HKQuantitySample }
        let nearest = found.min { abs($0.endDate.timeIntervalSince(date)) < abs($1.endDate.timeIntervalSince(date)) }
        let perMinute = HKUnit.count().unitDivided(by: .minute())
        return nearest.flatMap { Fmt.safeInt($0.quantity.doubleValue(for: perMinute)) }
    }

    /// Readings from the last few hours that Waterline did not write itself, so it never offers back its own values.
    private func recentFromOthers(hours: Double) -> NSPredicate {
        let now = Date()
        let recent = HKQuery.predicateForSamples(withStart: now.addingTimeInterval(-hours * 3600), end: now.addingTimeInterval(60))
        let own = HKQuery.predicateForObjects(from: HKSource.default())
        return NSCompoundPredicate(andPredicateWithSubpredicates: [recent, NSCompoundPredicate(notPredicateWithSubpredicate: own)])
    }

    private func samples(of type: HKSampleType, predicate: NSPredicate, limit: Int) async -> [HKSample] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[HKSample], Never>) in
            let newest = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [newest]) { _, results, _ in
                continuation.resume(returning: results ?? [])
            }
            store.execute(query)
        }
    }

    // MARK: Saving and removing

    /// Saves a check-in's weight and blood pressure. Values the form took from Health are skipped.
    func save(_ checkIn: CheckIn, imports: HealthImports) async {
        guard isOn else { return }
        let id = checkIn.id.uuidString
        var objects: [HKObject] = []

        if let kg = checkIn.weightKg, kg != imports.weightKg {
            let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
            objects.append(HKQuantitySample(type: weightType, quantity: quantity, start: checkIn.at, end: checkIn.at,
                                            metadata: [HKMetadataKeyExternalUUID: id,
                                                       HKMetadataKeySyncIdentifier: "\(id).weight",
                                                       HKMetadataKeySyncVersion: 1]))
        }

        let v = checkIn.vitals
        let readings: [(position: String, systolic: Int?, diastolic: Int?, imported: HealthImports.Reading?)] = [
            ("lying", v.lyingSystolic, v.lyingDiastolic, imports.lying),
            ("standing", v.standingSystolic, v.standingDiastolic, imports.standing),
        ]
        let mmHg = HKUnit.millimeterOfMercury()
        for reading in readings {
            guard let sys = reading.systolic, let dia = reading.diastolic,
                  HealthImports.Reading(systolic: sys, diastolic: dia) != reading.imported else { continue }
            let parts: [String: Any] = [HKMetadataKeyExternalUUID: id]
            let systolic = HKQuantitySample(type: systolicType, quantity: HKQuantity(unit: mmHg, doubleValue: Double(sys)),
                                            start: checkIn.at, end: checkIn.at, metadata: parts)
            let diastolic = HKQuantitySample(type: diastolicType, quantity: HKQuantity(unit: mmHg, doubleValue: Double(dia)),
                                             start: checkIn.at, end: checkIn.at, metadata: parts)
            objects.append(HKCorrelation(type: pressureType, start: checkIn.at, end: checkIn.at,
                                         objects: [systolic, diastolic],
                                         metadata: [HKMetadataKeyExternalUUID: id,
                                                    HKMetadataKeySyncIdentifier: "\(id).\(reading.position)",
                                                    HKMetadataKeySyncVersion: 1,
                                                    Self.positionKey: reading.position]))
        }

        guard !objects.isEmpty else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.save(objects) { _, _ in continuation.resume() }
        }
        refreshStatus()
    }

    /// Removes what Waterline saved for a check-in that was removed. Health only lets an app delete its own samples.
    func removeSamples(forCheckIn id: UUID) async {
        guard isOn else { return }
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyExternalUUID, allowedValues: [id.uuidString])
        let types: [HKObjectType] = [pressureType, weightType, systolicType, diastolicType]
        for type in types {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                store.deleteObjects(of: type, predicate: predicate) { _, _, _ in continuation.resume() }
            }
        }
    }
}
