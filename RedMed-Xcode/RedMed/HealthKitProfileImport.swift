import Foundation

/// Parked: no `import HealthKit`, no HealthKit.framework link.
/// Restore with `docs/healthkit-restore.md` and `AppConfig.healthKitImportEnabled = true`.
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

    static var isAvailable: Bool { false }

    @MainActor
    static func readCharacteristics() async throws -> Draft {
        throw ImportError.unavailable
    }
}
