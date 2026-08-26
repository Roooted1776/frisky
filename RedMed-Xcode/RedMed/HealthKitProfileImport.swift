import Foundation
import HealthKit

/// Owner-only, read-only Apple Health import for Edit / first-fill.
/// Copies birth date and blood type from HealthKit characteristics.
/// Never writes to Health. Never runs on passerby / scanner. Never leaves the phone.
enum HealthKitProfileImport {
    struct Draft: Equatable {
        var birthDate: String?
        var bloodType: String?

        var filledCount: Int {
            [birthDate, bloodType].compactMap { $0 }.count
        }
    }

    enum ImportError: LocalizedError {
        case unavailable
        case denied
        case nothingToFill
        case readFailed

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Apple Health is not available on this device."
            case .denied:
                return "Health access was not granted. Enable it in Settings → Health → Data Access & Devices → RedMed."
            case .nothingToFill:
                return "Apple Health has no birth date or blood type to copy."
            case .readFailed:
                return "Could not read Apple Health."
            }
        }
    }

    /// Gated on `AppConfig.healthKitImportEnabled` — parked while the HealthKit
    /// entitlement is out of `RedMed.entitlements` (personal-team signing).
    static var isAvailable: Bool {
        AppConfig.healthKitImportEnabled && HKHealthStore.isHealthDataAvailable()
    }

    private static let birthDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()

    /// Request read access, then copy characteristics. Empty Health fields stay nil.
    @MainActor
    static func readCharacteristics() async throws -> Draft {
        guard isAvailable else { throw ImportError.unavailable }

        guard
            let dobType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth),
            let bloodType = HKObjectType.characteristicType(forIdentifier: .bloodType)
        else {
            throw ImportError.unavailable
        }

        let store = HKHealthStore()
        do {
            try await store.requestAuthorization(toShare: [], read: [dobType, bloodType])
        } catch {
            throw ImportError.denied
        }

        var draft = Draft()
        if let date = try? store.dateOfBirthComponents().date {
            draft.birthDate = birthDateFormatter.string(from: date)
        } else if let components = try? store.dateOfBirthComponents(),
                  let date = Calendar.current.date(from: components) {
            draft.birthDate = birthDateFormatter.string(from: date)
        }

        if let labeled = try? store.bloodType() {
            draft.bloodType = redMedBloodType(labeled.bloodType)
        }

        if draft.filledCount == 0 {
            throw ImportError.nothingToFill
        }
        return draft
    }

    private static func redMedBloodType(_ type: HKBloodType) -> String? {
        switch type {
        case .aPositive: return "A+"
        case .aNegative: return "A-"
        case .bPositive: return "B+"
        case .bNegative: return "B-"
        case .abPositive: return "AB+"
        case .abNegative: return "AB-"
        case .oPositive: return "O+"
        case .oNegative: return "O-"
        case .notSet: return nil
        @unknown default: return nil
        }
    }
}
