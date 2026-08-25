import SwiftUI

/// Country + dial code for the Emergency Contacts phone field. Flag is derived
/// from the ISO 3166-1 alpha-2 code (regional indicator symbols) so the table
/// below never has to carry emoji literals.
struct CountryDialCode: Identifiable, Hashable {
    let iso: String
    let name: String
    let dialCode: String

    var id: String { iso }

    var flag: String {
        String(iso.uppercased().unicodeScalars.compactMap { scalar in
            Unicode.Scalar(127397 + scalar.value).map(Character.init)
        })
    }

    /// Split a stored phone string into its country + national number.
    /// No leading `+` (legacy contacts, or a plain paste) assumes the
    /// device's own region rather than guessing a foreign one.
    static func parse(_ phone: String) -> (country: CountryDialCode, localNumber: String) {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("+") else {
            return (defaultCountry, trimmed)
        }
        let match = all
            .filter { trimmed.hasPrefix($0.dialCode) }
            .max { $0.dialCode.count < $1.dialCode.count }
        guard let match else { return (defaultCountry, trimmed) }
        let rest = trimmed.dropFirst(match.dialCode.count).trimmingCharacters(in: .whitespaces)
        return (match, rest)
    }

    static let defaultCountry: CountryDialCode = unitedStates

    private static let unitedStates = CountryDialCode(iso: "US", name: "United States", dialCode: "+1")

    /// Common-use subset, not exhaustive — every entry here is unambiguous;
    /// an unlisted country falls back to the device region (or US).
    static let all: [CountryDialCode] = [
        unitedStates,
        CountryDialCode(iso: "CA", name: "Canada", dialCode: "+1"),
        CountryDialCode(iso: "MX", name: "Mexico", dialCode: "+52"),
        CountryDialCode(iso: "GB", name: "United Kingdom", dialCode: "+44"),
        CountryDialCode(iso: "IE", name: "Ireland", dialCode: "+353"),
        CountryDialCode(iso: "FR", name: "France", dialCode: "+33"),
        CountryDialCode(iso: "DE", name: "Germany", dialCode: "+49"),
        CountryDialCode(iso: "IT", name: "Italy", dialCode: "+39"),
        CountryDialCode(iso: "ES", name: "Spain", dialCode: "+34"),
        CountryDialCode(iso: "PT", name: "Portugal", dialCode: "+351"),
        CountryDialCode(iso: "NL", name: "Netherlands", dialCode: "+31"),
        CountryDialCode(iso: "BE", name: "Belgium", dialCode: "+32"),
        CountryDialCode(iso: "CH", name: "Switzerland", dialCode: "+41"),
        CountryDialCode(iso: "AT", name: "Austria", dialCode: "+43"),
        CountryDialCode(iso: "SE", name: "Sweden", dialCode: "+46"),
        CountryDialCode(iso: "NO", name: "Norway", dialCode: "+47"),
        CountryDialCode(iso: "DK", name: "Denmark", dialCode: "+45"),
        CountryDialCode(iso: "FI", name: "Finland", dialCode: "+358"),
        CountryDialCode(iso: "IS", name: "Iceland", dialCode: "+354"),
        CountryDialCode(iso: "PL", name: "Poland", dialCode: "+48"),
        CountryDialCode(iso: "CZ", name: "Czech Republic", dialCode: "+420"),
        CountryDialCode(iso: "SK", name: "Slovakia", dialCode: "+421"),
        CountryDialCode(iso: "HU", name: "Hungary", dialCode: "+36"),
        CountryDialCode(iso: "RO", name: "Romania", dialCode: "+40"),
        CountryDialCode(iso: "BG", name: "Bulgaria", dialCode: "+359"),
        CountryDialCode(iso: "GR", name: "Greece", dialCode: "+30"),
        CountryDialCode(iso: "TR", name: "Turkey", dialCode: "+90"),
        CountryDialCode(iso: "RU", name: "Russia", dialCode: "+7"),
        CountryDialCode(iso: "UA", name: "Ukraine", dialCode: "+380"),
        CountryDialCode(iso: "BY", name: "Belarus", dialCode: "+375"),
        CountryDialCode(iso: "LT", name: "Lithuania", dialCode: "+370"),
        CountryDialCode(iso: "LV", name: "Latvia", dialCode: "+371"),
        CountryDialCode(iso: "EE", name: "Estonia", dialCode: "+372"),
        CountryDialCode(iso: "HR", name: "Croatia", dialCode: "+385"),
        CountryDialCode(iso: "RS", name: "Serbia", dialCode: "+381"),
        CountryDialCode(iso: "SI", name: "Slovenia", dialCode: "+386"),
        CountryDialCode(iso: "BA", name: "Bosnia and Herzegovina", dialCode: "+387"),
        CountryDialCode(iso: "AL", name: "Albania", dialCode: "+355"),
        CountryDialCode(iso: "MT", name: "Malta", dialCode: "+356"),
        CountryDialCode(iso: "CY", name: "Cyprus", dialCode: "+357"),
        CountryDialCode(iso: "LU", name: "Luxembourg", dialCode: "+352"),
        CountryDialCode(iso: "AU", name: "Australia", dialCode: "+61"),
        CountryDialCode(iso: "NZ", name: "New Zealand", dialCode: "+64"),
        CountryDialCode(iso: "JP", name: "Japan", dialCode: "+81"),
        CountryDialCode(iso: "KR", name: "South Korea", dialCode: "+82"),
        CountryDialCode(iso: "CN", name: "China", dialCode: "+86"),
        CountryDialCode(iso: "HK", name: "Hong Kong", dialCode: "+852"),
        CountryDialCode(iso: "TW", name: "Taiwan", dialCode: "+886"),
        CountryDialCode(iso: "SG", name: "Singapore", dialCode: "+65"),
        CountryDialCode(iso: "MY", name: "Malaysia", dialCode: "+60"),
        CountryDialCode(iso: "ID", name: "Indonesia", dialCode: "+62"),
        CountryDialCode(iso: "PH", name: "Philippines", dialCode: "+63"),
        CountryDialCode(iso: "TH", name: "Thailand", dialCode: "+66"),
        CountryDialCode(iso: "VN", name: "Vietnam", dialCode: "+84"),
        CountryDialCode(iso: "IN", name: "India", dialCode: "+91"),
        CountryDialCode(iso: "PK", name: "Pakistan", dialCode: "+92"),
        CountryDialCode(iso: "BD", name: "Bangladesh", dialCode: "+880"),
        CountryDialCode(iso: "LK", name: "Sri Lanka", dialCode: "+94"),
        CountryDialCode(iso: "NP", name: "Nepal", dialCode: "+977"),
        CountryDialCode(iso: "IL", name: "Israel", dialCode: "+972"),
        CountryDialCode(iso: "SA", name: "Saudi Arabia", dialCode: "+966"),
        CountryDialCode(iso: "AE", name: "United Arab Emirates", dialCode: "+971"),
        CountryDialCode(iso: "QA", name: "Qatar", dialCode: "+974"),
        CountryDialCode(iso: "KW", name: "Kuwait", dialCode: "+965"),
        CountryDialCode(iso: "BH", name: "Bahrain", dialCode: "+973"),
        CountryDialCode(iso: "OM", name: "Oman", dialCode: "+968"),
        CountryDialCode(iso: "JO", name: "Jordan", dialCode: "+962"),
        CountryDialCode(iso: "LB", name: "Lebanon", dialCode: "+961"),
        CountryDialCode(iso: "EG", name: "Egypt", dialCode: "+20"),
        CountryDialCode(iso: "ZA", name: "South Africa", dialCode: "+27"),
        CountryDialCode(iso: "NG", name: "Nigeria", dialCode: "+234"),
        CountryDialCode(iso: "KE", name: "Kenya", dialCode: "+254"),
        CountryDialCode(iso: "GH", name: "Ghana", dialCode: "+233"),
        CountryDialCode(iso: "ET", name: "Ethiopia", dialCode: "+251"),
        CountryDialCode(iso: "MA", name: "Morocco", dialCode: "+212"),
        CountryDialCode(iso: "DZ", name: "Algeria", dialCode: "+213"),
        CountryDialCode(iso: "TN", name: "Tunisia", dialCode: "+216"),
        CountryDialCode(iso: "BR", name: "Brazil", dialCode: "+55"),
        CountryDialCode(iso: "AR", name: "Argentina", dialCode: "+54"),
        CountryDialCode(iso: "CL", name: "Chile", dialCode: "+56"),
        CountryDialCode(iso: "CO", name: "Colombia", dialCode: "+57"),
        CountryDialCode(iso: "PE", name: "Peru", dialCode: "+51"),
        CountryDialCode(iso: "VE", name: "Venezuela", dialCode: "+58"),
        CountryDialCode(iso: "EC", name: "Ecuador", dialCode: "+593"),
        CountryDialCode(iso: "UY", name: "Uruguay", dialCode: "+598"),
        CountryDialCode(iso: "PY", name: "Paraguay", dialCode: "+595"),
        CountryDialCode(iso: "BO", name: "Bolivia", dialCode: "+591"),
        CountryDialCode(iso: "CR", name: "Costa Rica", dialCode: "+506"),
        CountryDialCode(iso: "PA", name: "Panama", dialCode: "+507"),
        CountryDialCode(iso: "DO", name: "Dominican Republic", dialCode: "+1"),
        CountryDialCode(iso: "JM", name: "Jamaica", dialCode: "+1"),
        CountryDialCode(iso: "TT", name: "Trinidad and Tobago", dialCode: "+1"),
        CountryDialCode(iso: "CU", name: "Cuba", dialCode: "+53"),
        CountryDialCode(iso: "GT", name: "Guatemala", dialCode: "+502"),
        CountryDialCode(iso: "HN", name: "Honduras", dialCode: "+504"),
        CountryDialCode(iso: "SV", name: "El Salvador", dialCode: "+503"),
        CountryDialCode(iso: "NI", name: "Nicaragua", dialCode: "+505")
    ]
}
