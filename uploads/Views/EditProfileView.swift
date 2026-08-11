import SwiftUI

struct EditProfileView: View {
    @Environment(\.layoutMetrics) private var layout
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var link: BraceletLinkStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// When true, shown as the My ID tab (Save stays; no Cancel).
    var embedded: Bool = false

    @State private var editUnlocked = false
    @State private var authInProgress = false

    @State private var draft: MedicalProfile = {
        var profile = MedicalProfile()
        while profile.contacts.count < 3 { profile.contacts.append(EmergencyContact()) }
        return profile
    }()
    @State private var medRows: [MedRow] = []
    @State private var showingClearConfirm = false
    @State private var showingAddAllergy = false
    @State private var showingAddMed = false
    @State private var showingAddCondition = false
    @State private var openContactIndex: Int?
    @State private var savedFlash = false
    @State private var showingBraceletSetup = false
    @State private var firstName = ""
    @State private var lastName = ""
    @StateObject private var braceletWriter = NFCWriter()

    private let bloodTypes = ["", "O-", "O+", "A-", "A+", "B-", "B+", "AB-", "AB+"]

    // Ordered roughly by U.S. outpatient prescription volume (ClinCalc DrugStats
    // Top 300) with emergency-relevant drugs — anticoagulants, insulins,
    // epinephrine, naloxone, steroids, opioids, antiseizure — kept prominent.
    static let commonMeds = [
        // Pain / anti-inflammatory
        "Acetaminophen (Tylenol)", "Ibuprofen (Advil/Motrin)", "Aspirin",
        "Naproxen (Aleve)", "Meloxicam", "Cyclobenzaprine (Flexeril)",
        // Cholesterol
        "Atorvastatin (Lipitor)", "Rosuvastatin (Crestor)", "Simvastatin", "Pravastatin",
        // Blood pressure / heart
        "Lisinopril", "Losartan", "Amlodipine", "Metoprolol", "Carvedilol",
        "Atenolol", "Hydrochlorothiazide", "Furosemide (Lasix)", "Spironolactone",
        "Diltiazem", "Clonidine", "Digoxin",
        // Diabetes
        "Metformin", "Glipizide", "Insulin glargine (Lantus)", "Insulin aspart (NovoLog)",
        "Insulin (regular)", "Semaglutide (Ozempic/Wegovy)", "Empagliflozin (Jardiance)",
        "Dulaglutide (Trulicity)",
        // Thyroid
        "Levothyroxine (Synthroid)",
        // Stomach / reflux
        "Omeprazole (Prilosec)", "Pantoprazole (Protonix)", "Famotidine (Pepcid)",
        // Respiratory
        "Albuterol inhaler", "Fluticasone (Flonase/Flovent)", "Montelukast (Singulair)",
        "Budesonide-formoterol (Symbicort)",
        // Mental health
        "Sertraline (Zoloft)", "Escitalopram (Lexapro)", "Fluoxetine (Prozac)",
        "Citalopram (Celexa)", "Duloxetine (Cymbalta)", "Venlafaxine (Effexor)",
        "Bupropion (Wellbutrin)", "Trazodone", "Mirtazapine (Remeron)",
        // Sedatives / benzodiazepines
        "Alprazolam (Xanax)", "Lorazepam (Ativan)", "Clonazepam (Klonopin)", "Diazepam (Valium)",
        // Nerve / seizure
        "Gabapentin (Neurontin)", "Pregabalin (Lyrica)", "Levetiracetam (Keppra)",
        "Lamotrigine (Lamictal)", "Topiramate (Topamax)", "Divalproex (Depakote)",
        "Levodopa-carbidopa (Sinemet)",
        // Blood thinners / antiplatelet
        "Warfarin (Coumadin)", "Apixaban (Eliquis)", "Rivaroxaban (Xarelto)",
        "Dabigatran (Pradaxa)", "Clopidogrel (Plavix)",
        // Steroids
        "Prednisone", "Methylprednisolone", "Hydrocortisone",
        // Antibiotics
        "Amoxicillin", "Amoxicillin-clavulanate (Augmentin)", "Azithromycin (Z-Pak)",
        "Cephalexin (Keflex)", "Doxycycline", "Ciprofloxacin",
        "Sulfamethoxazole-trimethoprim (Bactrim)", "Nitrofurantoin (Macrobid)",
        // Opioids / dependence
        "Tramadol (Ultram)", "Hydrocodone-acetaminophen (Norco)", "Oxycodone (OxyContin)",
        "Morphine", "Buprenorphine-naloxone (Suboxone)",
        // Emergency rescue
        "Epinephrine (EpiPen)", "Naloxone (Narcan)",
        // Other common
        "Tamsulosin (Flomax)", "Allopurinol", "Methotrexate",
        "Hydroxychloroquine (Plaquenil)", "Potassium chloride"
    ]

    // Grouped: drug allergies (penicillin/sulfa/NSAIDs are the most common),
    // the FDA's 9 major food allergens (sesame added 2023), then environmental.
    static let commonAllergens = [
        // Drugs
        "Penicillin", "Amoxicillin", "Cephalosporins", "Sulfa drugs (sulfonamides)",
        "Aspirin / NSAIDs", "Codeine / Opioids", "Morphine",
        "Local anesthetics (lidocaine)", "General anesthesia",
        "Iodine / Contrast dye", "Erythromycin / Macrolides", "Tetracycline",
        // Foods
        "Peanuts", "Tree nuts", "Shellfish", "Fish", "Eggs", "Milk / Dairy",
        "Soy", "Wheat / Gluten", "Sesame",
        // Environmental / other
        "Latex", "Bee / Wasp stings", "Pollen", "Dust mites", "Mold",
        "Pet dander", "Nickel", "Adhesive / Tape"
    ]

    // Most-prevalent U.S. chronic conditions (CDC) plus conditions and implants
    // that change emergency treatment (anticoagulation, dialysis, transplant,
    // adrenal insufficiency, immunocompromise, ICD/pacemaker).
    static let commonConditions = [
        // Cardiometabolic — most prevalent
        "Hypertension", "High cholesterol", "Diabetes (Type 1)", "Diabetes (Type 2)",
        "Obesity", "Heart disease", "Coronary artery disease", "Heart failure",
        "AFib", "Stroke history", "Thyroid disorder",
        // Implants / devices
        "Pacemaker", "ICD (implanted defibrillator)",
        // Respiratory
        "Asthma", "COPD", "Sleep apnea",
        // Neurological
        "Epilepsy / Seizure disorder", "Migraine", "Alzheimer's / Dementia",
        "Parkinson's disease", "Multiple sclerosis",
        // Kidney / liver
        "Kidney disease", "On dialysis", "Liver disease", "Hepatitis",
        // Immune / transplant / cancer
        "Cancer (active treatment)", "Organ transplant", "Immunocompromised",
        "HIV", "Adrenal insufficiency (Addison's)",
        // Autoimmune / blood
        "Lupus", "Rheumatoid arthritis", "Crohn's / IBD",
        "Sickle cell disease", "Hemophilia", "On blood thinners / anticoagulants",
        // Digestive / bone / eye
        "GERD / Acid reflux", "Osteoporosis", "Glaucoma", "Chronic pain",
        // Mental health
        "PTSD", "Anxiety disorder", "Depression", "Bipolar disorder", "Autism",
        // Other
        "Pregnancy", "Blind / Low vision", "Deaf / Hard of hearing",
        "Mobility impairment"
    ]

    /// Edits require device auth once this device has saved profile data.
    /// First-time setup stays open until the owner taps Save. Also stays
    /// open for the single foreground session that follows pairing a
    /// bracelet — never the pairing session itself — via
    /// `link.pendingPostPairingGrace` (armed/promoted/consumed in
    /// `ContentView` off app-wide scenePhase transitions).
    private var requiresEditAuth: Bool {
        store.profile.hasOwnerData && !link.pendingPostPairingGrace
    }

    private var editAuthAvailability: BiometricGate.Availability {
        BiometricGate.availability()
    }

    var body: some View {
        NavigationStack {
            ZStack {
            Form {
                if embedded {
                    Section {
                        VStack(alignment: .leading, spacing: layout.s(10)) {
                            if link.isLinked {
                                BrandMark(size: .hero, titleOverride: link.deviceName)
                            } else {
                                BrandMark(size: .hero, showTagline: true)
                                if Self.joinProfileName(first: firstName, last: lastName).isEmpty {
                                    Text("Add your name to unlock NFC write.")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppTheme.muted)
                                }
                            }
                        }
                        .padding(.vertical, layout.spaceSM)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(
                            top: layout.pageTopInset,
                            leading: layout.spaceXS,
                            bottom: layout.spaceSM,
                            trailing: layout.spaceXS
                        ))
                    }
                }

                if link.isLinked {
                    Section {
                        BraceletSyncInstructions()
                        if braceletWriter.isWriting || !braceletWriter.statusMessage.isEmpty {
                            Text(braceletWriter.isWriting ? "Hold near bracelet…" : braceletWriter.statusMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(braceletWriter.verified ? AppTheme.ok : AppTheme.ink)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack(spacing: layout.spaceSM) {
                        TextField("First", text: $firstName)
                            .textContentType(.givenName)
                            .autocorrectionDisabled()
                        TextField("Last", text: $lastName)
                            .textContentType(.familyName)
                            .autocorrectionDisabled()
                    }
                    .padding(.top, layout.spaceMD)
                    DatePicker("Birth date", selection: dobBinding, displayedComponents: .date)
                    Picker("Blood type", selection: $draft.blood) {
                        ForEach(bloodTypes, id: \.self) { bt in
                            Text(bt.isEmpty ? "Unknown" : bt).tag(bt)
                        }
                    }
                } header: {
                    Text("You")
                }

                Section("Allergies") {
                    if draft.allergies.isEmpty {
                        Text("None").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(draft.allergies.enumerated()), id: \.offset) { index, allergy in
                            HStack {
                                Text(allergy)
                                Spacer()
                                Button { draft.allergies.remove(at: index) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button("Add allergy") { showingAddAllergy = true }
                        .foregroundStyle(AppTheme.teal)
                }

                Section("Medications") {
                    if medRows.isEmpty {
                        Text("None").foregroundStyle(.secondary)
                    } else {
                        ForEach($medRows) { $row in
                            VStack(alignment: .leading, spacing: layout.s(6)) {
                                Text(row.name).font(.body.weight(.semibold))
                                TextField("Dose", text: $row.dose).font(.subheadline)
                            }
                        }
                        .onDelete { medRows.remove(atOffsets: $0) }
                    }
                    Button("Add medication") { showingAddMed = true }
                        .foregroundStyle(AppTheme.teal)
                }

                Section("Conditions") {
                    if draft.conditions.isEmpty {
                        Text("None").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(draft.conditions.enumerated()), id: \.offset) { index, condition in
                            HStack {
                                Text(condition)
                                Spacer()
                                Button { draft.conditions.remove(at: index) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button("Add condition") { showingAddCondition = true }
                        .foregroundStyle(AppTheme.teal)
                }

                Section("Contacts") {
                    ForEach(0..<3, id: \.self) { index in
                        contactDisclosure(index: index)
                    }
                }

                Section {
                    Button("Clear data", role: .destructive) { showingClearConfirm = true }
                } footer: {
                    Text("On this device and your band only. Never uploaded.")
                }
            }
            .scrollContentBackground(.hidden)
            .screenAtmosphere()
            .disabled(!editUnlocked)
            .blur(radius: editUnlocked ? 0 : 8)

            if requiresEditAuth && !editUnlocked {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                if authInProgress {
                    ProgressView("Unlocking…")
                        .font(.subheadline.weight(.semibold))
                        .padding(layout.spaceLG)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: layout.s(16)))
                } else {
                    VStack(spacing: layout.spaceMD) {
                        Image(systemName: editAuthAvailability.iconSystemName)
                            .font(.system(size: layout.s(40)))
                            .foregroundStyle(AppTheme.accent)
                        Text(editAuthAvailability.editGateTitle)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Button(editAuthAvailability.unlockButtonLabel) {
                            Task { await unlockForEdit() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                    }
                    .padding(layout.spaceLG)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: layout.s(16)))
                }
            }
            }
            .navigationTitle(embedded ? "" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if embedded {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingBraceletSetup = true
                        } label: {
                            BraceletToolbarButton(link: link)
                        }
                        .accessibilityLabel("Bracelet setup")
                    }
                }
                if !embedded {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(savedFlash ? "Saved" : "Save") { save() }
                        .bold()
                        .foregroundStyle(AppTheme.accent)
                        .disabled(!editUnlocked)
                }
            }
            .tint(AppTheme.accent)
            .onAppear {
                loadDraft()
                prepareEditAccess()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background {
                    if link.pendingPostPairingGrace { link.consumePostPairingGrace() }
                    if requiresEditAuth { editUnlocked = false }
                }
            }
            .onChange(of: braceletWriter.verified) { verified in
                guard verified,
                      let url = ProfileLinkBuilder.buildURL(profile: store.profile, baseURL: AppConfig.medicalCardBaseURL) else { return }
                link.link(name: link.deviceName, url: url.absoluteString)
            }
            .onChange(of: braceletWriter.success) { success in
                guard success, !braceletWriter.verified,
                      let url = ProfileLinkBuilder.buildURL(profile: store.profile, baseURL: AppConfig.medicalCardBaseURL) else { return }
                link.link(name: link.deviceName, url: url.absoluteString)
            }
            .sheet(isPresented: $showingBraceletSetup) {
                BraceletSetupView()
            }
            .sheet(isPresented: $showingAddAllergy) {
                SearchAddSheet(
                    title: "Add allergy",
                    placeholder: "Search or type",
                    suggestions: Self.commonAllergens,
                    existing: draft.allergies
                ) { draft.allergies.append($0) }
            }
            .sheet(isPresented: $showingAddMed) {
                SearchAddSheet(
                    title: "Add medication",
                    placeholder: "Type 3+ letters to search",
                    suggestions: Self.commonMeds,
                    existing: medRows.map(\.name),
                    minimumQueryLength: 3
                ) { medRows.append(MedRow(name: $0, dose: "")) }
            }
            .sheet(isPresented: $showingAddCondition) {
                SearchAddSheet(
                    title: "Add condition",
                    placeholder: "Search or type",
                    suggestions: Self.commonConditions,
                    existing: draft.conditions
                ) { draft.conditions.append($0) }
            }
            .confirmationDialog("Clear all data?", isPresented: $showingClearConfirm) {
                Button("Clear", role: .destructive) {
                    Task { await clearAfterAuth() }
                }
            }
        }
    }

    private func prepareEditAccess() {
        guard requiresEditAuth else {
            editUnlocked = true
            return
        }
        guard editAuthAvailability != .none else {
            editUnlocked = true
            return
        }
        guard !editUnlocked, !authInProgress else { return }
        Task { await unlockForEdit() }
    }

    @MainActor
    private func unlockForEdit() async {
        guard requiresEditAuth, !editUnlocked else { return }
        authInProgress = true
        let ok = await BiometricGate.authenticate(reason: "Unlock to edit your medical ID")
        authInProgress = false
        if ok { editUnlocked = true }
    }

    @MainActor
    private func clearAfterAuth() async {
        let ok = await BiometricGate.authenticate(reason: "Confirm clearing your medical ID")
        guard ok else { return }
        store.clearAllData()
        link.clear()
        draft = store.profile
        while draft.contacts.count < 3 { draft.contacts.append(EmergencyContact()) }
        medRows = []
        editUnlocked = true
    }

    private func save() {
        guard editUnlocked else { return }
        draft.name = Self.joinProfileName(first: firstName, last: lastName)
        draft.meds = medRows.compactMap(Self.formatMed)
        draft.allergies = draft.allergies.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        draft.conditions = draft.conditions.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        draft.contacts = draft.contacts
            .map {
                var c = $0
                c.name = c.name.trimmingCharacters(in: .whitespaces)
                c.rel = c.rel.trimmingCharacters(in: .whitespaces)
                c.phone = c.phone.trimmingCharacters(in: .whitespaces)
                return c
            }
            .filter { !$0.name.isEmpty || !$0.rel.isEmpty || !$0.phone.isEmpty }
        draft.updated = ISO8601DateFormatter().string(from: Date())
        store.profile = draft
        loadDraft()
        syncBraceletIfLinked()
        if embedded {
            savedFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedFlash = false }
        } else {
            dismiss()
        }
    }

    /// Passersby read `#d=` off the chip, not a server — re-write the band after each save.
    private func syncBraceletIfLinked() {
        guard link.isLinked, !store.profile.name.isEmpty else { return }
        guard let url = ProfileLinkBuilder.buildURL(profile: store.profile, baseURL: AppConfig.medicalCardBaseURL) else { return }
        braceletWriter.writeURL(url.absoluteString)
    }

    private func loadDraft() {
        draft = store.profile
        let nameParts = Self.splitProfileName(draft.name)
        firstName = nameParts.first
        lastName = nameParts.last
        if draft.contacts.count < 3 {
            while draft.contacts.count < 3 { draft.contacts.append(EmergencyContact()) }
        }
        medRows = store.profile.meds.map(Self.parseMed)
        draft.allergies = draft.allergies.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        draft.conditions = draft.conditions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func contactDetail(_ contact: EmergencyContact) -> String {
        [contact.rel, contact.phone]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private func contactDisclosure(index: Int) -> some View {
        let isExpanded = Binding(
            get: { openContactIndex == index },
            set: { openContactIndex = $0 ? index : nil }
        )
        DisclosureGroup(isExpanded: isExpanded) {
            TextField("Name", text: $draft.contacts[index].name)
            TextField("Relation", text: $draft.contacts[index].rel)
            TextField("Phone", text: $draft.contacts[index].phone)
                .keyboardType(.phonePad)
        } label: {
            contactLabel(index: index)
        }
    }

    @ViewBuilder
    private func contactLabel(index: Int) -> some View {
        let contact = draft.contacts[index]
        let name = contact.name.trimmingCharacters(in: .whitespaces)
        let detail = contactDetail(contact)
        VStack(alignment: .leading, spacing: layout.s(2)) {
            Text(name.isEmpty ? "Emergency contact \(index + 1)" : name)
                .font(.subheadline.weight(.semibold))
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
            }
        }
    }

    // Cached instead of built inside dobBinding's get/set — those closures
    // run on every DatePicker render/edit, and DateFormatter construction
    // is comparatively expensive to repeat that often.
    private static let dobFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var dobBinding: Binding<Date> {
        Binding(
            get: {
                Self.dobFormatter.date(from: draft.dob) ?? Date(timeIntervalSince1970: 0)
            },
            set: {
                draft.dob = Self.dobFormatter.string(from: $0)
            }
        )
    }

    /// Matches `joinProfileName` / `splitProfileName` encoding for NFC `#d=` parity.
    private static func joinProfileName(first: String, last: String) -> String {
        [first, last]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func splitProfileName(_ full: String) -> (first: String, last: String) {
        let trimmed = full.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ("", "") }
        guard let space = trimmed.firstIndex(of: " ") else { return (trimmed, "") }
        return (
            String(trimmed[..<space]).trimmingCharacters(in: .whitespaces),
            String(trimmed[trimmed.index(after: space)...]).trimmingCharacters(in: .whitespaces)
        )
    }

    private static func parseMed(_ raw: String) -> MedRow {
        if let range = raw.range(of: " — ") {
            return MedRow(name: String(raw[raw.startIndex..<range.lowerBound]),
                           dose: String(raw[range.upperBound...]))
        }
        return MedRow(name: raw, dose: "")
    }

    private static func formatMed(_ row: MedRow) -> String? {
        let name = row.name.trimmingCharacters(in: .whitespaces)
        let dose = row.dose.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        return dose.isEmpty ? name : "\(name) — \(dose)"
    }
}

private struct MedRow: Identifiable {
    let id = UUID()
    var name: String = ""
    var dose: String = ""
}

private struct SearchAddSheet: View {
    let title: String
    let placeholder: String
    let suggestions: [String]
    let existing: [String]
    var minimumQueryLength: Int = 0
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtered: [String] {
        let q = trimmedQuery
        let base = suggestions.filter { !existing.contains($0) }
        guard q.count >= minimumQueryLength else { return [] }
        return base.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    private var canAddCustom: Bool {
        let q = trimmedQuery
        return !q.isEmpty && !existing.contains(where: { $0.caseInsensitiveCompare(q) == .orderedSame })
    }

    var body: some View {
        NavigationStack {
            List {
                if minimumQueryLength > 0, trimmedQuery.count > 0, trimmedQuery.count < minimumQueryLength {
                    Text("Type at least \(minimumQueryLength) characters to search.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                }
                if canAddCustom {
                    Button("Add \"\(trimmedQuery)\"") {
                        add(query)
                    }
                }
                ForEach(filtered, id: \.self) { item in
                    Button(item) { add(item) }
                }
            }
            .searchable(text: $query, prompt: placeholder)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .tint(AppTheme.accent)
        }
    }

    private func add(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        dismiss()
    }
}

#Preview {
    EditProfileView(embedded: true)
        .environmentObject(ProfileStore())
        .environmentObject(BraceletLinkStore())
}
