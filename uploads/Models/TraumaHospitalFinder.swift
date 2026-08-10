import Foundation

/// Verified Level I/II trauma hospital from the bundled offline directory (ACS / state designations).
/// Shown for transport decisions when delay may not be survivable — not routine ER lookup.
struct TraumaHospital: Identifiable, Codable, Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    let level: Int
    let city: String
    let state: String
    let county: String
    let phone: String

    var id: String { "\(name)|\(latitude)|\(longitude)" }

    enum CodingKeys: String, CodingKey {
        case name = "n"
        case latitude = "lat"
        case longitude = "lng"
        case level = "l"
        case city = "c"
        case state = "s"
        case county = "co"
        case phone = "p"
    }

    var levelLabel: String { "Level \(level) trauma" }

    var mapsURL: URL? {
        URL(string: "https://maps.apple.com/?daddr=\(latitude),\(longitude)")
    }
}

/// Offline trauma lookup by state, with county only when the state list is long.
/// JSON + index load on first use (911 / scanned card), not at app launch.
enum TraumaHospitalFinder {
    static let countyThreshold = 30

    private static let lock = NSLock()
    private static var cachedIndex: [String: [String: [TraumaHospital]]]?
    private static var cachedStates: [String]?

    private static var regionIndex: [String: [String: [TraumaHospital]]] {
        lock.lock()
        defer { lock.unlock() }
        if let cachedIndex { return cachedIndex }
        let loaded = Self.loadRegionIndex()
        cachedIndex = loaded
        cachedStates = loaded.keys.sorted()
        return loaded
    }

    private static func loadRegionIndex() -> [String: [String: [TraumaHospital]]] {
        guard let url = Bundle.main.url(forResource: "trauma-hospitals", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode([TraumaHospital].self, from: data) else {
            return [:]
        }
        var index: [String: [String: [TraumaHospital]]] = [:]
        for hospital in catalog {
            index[hospital.state, default: [:]][hospital.county, default: []].append(hospital)
        }
        for state in index.keys {
            for county in index[state]!.keys {
                index[state]![county]!.sort { $0.name < $1.name }
            }
        }
        return index
    }

    /// Prefetch off the main thread so Find 911's first paint isn't blocked on JSON decode.
    static func warmUp() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = regionIndex
        }
    }

    /// States list without forcing a main-thread decode when the cache is cold.
    static func loadStatesAsync() async -> [String] {
        await Task.detached(priority: .userInitiated) {
            lock.lock()
            if let cachedStates {
                lock.unlock()
                return cachedStates
            }
            lock.unlock()
            let index = regionIndex
            return index.keys.sorted()
        }.value
    }

    static var states: [String] {
        lock.lock()
        if let cachedStates {
            lock.unlock()
            return cachedStates
        }
        lock.unlock()
        return regionIndex.keys.sorted()
    }

    static func counties(in state: String) -> [String] {
        guard !state.isEmpty, let counties = regionIndex[state] else { return [] }
        return counties.keys.sorted()
    }

    static func hospitals(in state: String) -> [TraumaHospital] {
        guard !state.isEmpty, let counties = regionIndex[state] else { return [] }
        return counties.values.flatMap { $0 }.sorted { $0.name < $1.name }
    }

    static func needsCountyPicker(for state: String) -> Bool {
        // Empty selection must not touch the JSON index (cold-launch path).
        guard !state.isEmpty else { return false }
        return hospitals(in: state).count >= countyThreshold
    }

    static func hospitals(state: String, county: String) -> [TraumaHospital] {
        guard !state.isEmpty else { return [] }
        return regionIndex[state]?[county] ?? []
    }

    static func resolvedHospitals(state: String, county: String) -> [TraumaHospital] {
        guard !state.isEmpty else { return [] }
        if needsCountyPicker(for: state) {
            guard !county.isEmpty else { return [] }
            return hospitals(state: state, county: county)
        }
        return hospitals(in: state)
    }

    static func matchCounty(state: String, name: String) -> String? {
        guard !state.isEmpty else { return nil }
        let target = name.lowercased()
            .replacingOccurrences(of: " county", with: "")
            .replacingOccurrences(of: " city", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return nil }
        let counties = counties(in: state)
        if let exact = counties.first(where: {
            $0.lowercased().replacingOccurrences(of: " county", with: "") == target
        }) { return exact }
        return counties.first(where: {
            let n = $0.lowercased()
            return n.contains(target) || target.contains(n.replacingOccurrences(of: " county", with: ""))
        })
    }
}
