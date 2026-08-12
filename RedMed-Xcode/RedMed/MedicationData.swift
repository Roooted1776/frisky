import Foundation

/// Edit autocomplete catalogues. Strings stay inert until first match / warmUp.
/// Indexing is lazy + locked — never at `@main`, never via eager `static let`.
/// Common entries are listed first so the early-exit matcher surfaces them before rare ones.
enum SuggestionCatalog {
    typealias Entry = (display: String, lower: String)

    private static let lock = NSLock()
    private static var cachedMedications: [Entry]?
    private static var cachedAllergies: [Entry]?
    private static var cachedConditions: [Entry]?

    static var medications: [Entry] { locked(&cachedMedications, _medications) }
    static var allergies: [Entry] { locked(&cachedAllergies, _allergies) }
    static var conditions: [Entry] { locked(&cachedConditions, _conditions) }

    /// Prefetch off the main thread when Edit opens — first keystroke stays cheap.
    static func warmUp() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = medications
            _ = allergies
            _ = conditions
        }
    }

    /// Prefix matches first, then contains. Skip exact + already-used rows. Hard cap.
    /// Linear scan with early exit — catalogs are hundreds of strings, not megabytes.
    static func matches(
        query: String,
        in catalog: [Entry],
        excludingTaken taken: Set<String>,
        limit: Int = 5
    ) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        let queryLower = q.lowercased()
        var prefixHits: [String] = []
        var containsHits: [String] = []
        prefixHits.reserveCapacity(limit)
        containsHits.reserveCapacity(limit)
        for entry in catalog {
            if entry.lower == queryLower { continue }
            if taken.contains(entry.lower) { continue }
            if entry.lower.hasPrefix(queryLower) {
                prefixHits.append(entry.display)
                if prefixHits.count == limit { return prefixHits }
            } else if containsHits.count < limit, entry.lower.contains(queryLower) {
                containsHits.append(entry.display)
            }
        }
        if containsHits.isEmpty { return prefixHits }
        var next = prefixHits
        for hit in containsHits {
            if next.count == limit { break }
            next.append(hit)
        }
        return next
    }

    private static func locked(_ cache: inout [Entry]?, _ values: [String]) -> [Entry] {
        lock.lock()
        defer { lock.unlock() }
        if let cache { return cache }
        let built = values.map { (display: $0, lower: $0.lowercased()) }
        cache = built
        return built
    }

    // MARK: - Medications (common first, then less common / rare specialty)

    private static let _medications: [String] = [
        // OTC pain/fever
        "Tylenol (acetaminophen)", "Advil (ibuprofen)", "Motrin (ibuprofen)", "Aleve (naproxen)", "Aspirin",
        "Excedrin", "Bayer Aspirin", "Goody's Powder",
        // OTC allergy/cold/flu
        "Benadryl (diphenhydramine)", "Claritin (loratadine)", "Zyrtec (cetirizine)", "Allegra (fexofenadine)",
        "Xyzal (levocetirizine)", "Sudafed (pseudoephedrine)", "Mucinex (guaifenesin)", "NyQuil", "DayQuil",
        "Robitussin", "Afrin nasal spray", "Flonase (fluticasone)", "Nasacort (triamcinolone)", "Zicam",
        "Theraflu", "Coricidin",
        // OTC GI
        "Tums (calcium carbonate)", "Pepcid (famotidine)", "Prilosec (omeprazole)", "Nexium (esomeprazole)",
        "Zantac (ranitidine)", "Pepto-Bismol", "Imodium (loperamide)", "Gas-X (simethicone)", "Miralax",
        "Dulcolax", "Metamucil", "Colace (docusate)", "Tagamet (cimetidine)",
        // OTC topical/skin
        "Hydrocortisone cream", "Neosporin", "Bacitracin", "Calamine lotion", "Cortizone-10",
        "Benzoyl peroxide", "Salicylic acid", "Aquaphor",
        // OTC sleep/misc
        "Unisom (doxylamine)", "Melatonin", "Dramamine (dimenhydrinate)", "Emergen-C", "Airborne",
        // Cardiovascular
        "Lisinopril", "Losartan", "Amlodipine", "Metoprolol", "Atenolol", "Carvedilol", "Bisoprolol",
        "Hydrochlorothiazide", "Furosemide (Lasix)", "Spironolactone", "Atorvastatin (Lipitor)",
        "Rosuvastatin (Crestor)", "Simvastatin", "Pravastatin", "Clopidogrel (Plavix)", "Warfarin (Coumadin)",
        "Apixaban (Eliquis)", "Rivaroxaban (Xarelto)", "Digoxin", "Nitroglycerin", "Isosorbide mononitrate",
        "Diltiazem", "Verapamil", "Valsartan", "Irbesartan", "Ramipril", "Enalapril", "Propranolol",
        "Chlorthalidone", "Bumetanide (Bumex)", "Torsemide", "Hydralazine", "Amiodarone",
        "Sotalol", "Flecainide", "Dabigatran (Pradaxa)", "Edoxaban (Savaysa)",
        // Diabetes
        "Metformin", "Glipizide", "Glyburide", "Insulin glargine (Lantus)", "Insulin lispro (Humalog)",
        "Insulin aspart (Novolog)", "Sitagliptin (Januvia)", "Empagliflozin (Jardiance)",
        "Semaglutide (Ozempic)", "Liraglutide (Victoza)", "Dulaglutide (Trulicity)", "Pioglitazone",
        "Insulin detemir (Levemir)", "Insulin degludec (Tresiba)", "Canagliflozin (Invokana)",
        "Dapagliflozin (Farxiga)", "Linagliptin (Tradjenta)", "Tirzepatide (Mounjaro)",
        "Glimepiride", "Repaglinide", "Acarbose",
        // Respiratory
        "Albuterol inhaler", "Fluticasone/salmeterol (Advair)", "Budesonide/formoterol (Symbicort)",
        "Montelukast (Singulair)", "Tiotropium (Spiriva)", "Prednisone", "Ipratropium (Atrovent)",
        "Budesonide (Pulmicort)", "Beclomethasone (Qvar)", "Umeclidinium/vilanterol (Anoro)",
        "Fluticasone/vilanterol (Breo)", "Theophylline", "Roflumilast (Daliresp)",
        // Mental health
        "Sertraline (Zoloft)", "Escitalopram (Lexapro)", "Fluoxetine (Prozac)", "Citalopram (Celexa)",
        "Paroxetine (Paxil)", "Bupropion (Wellbutrin)", "Venlafaxine (Effexor)", "Duloxetine (Cymbalta)",
        "Trazodone", "Mirtazapine (Remeron)", "Alprazolam (Xanax)", "Lorazepam (Ativan)", "Clonazepam (Klonopin)",
        "Diazepam (Valium)", "Buspirone", "Quetiapine (Seroquel)", "Aripiprazole (Abilify)", "Risperidone",
        "Olanzapine (Zyprexa)", "Lithium", "Lamotrigine (Lamictal)", "Valproic acid (Depakote)",
        "Desvenlafaxine (Pristiq)", "Vilazodone (Viibryd)", "Vortioxetine (Trintellix)",
        "Haloperidol (Haldol)", "Ziprasidone (Geodon)", "Lurasidone (Latuda)", "Cariprazine (Vraylar)",
        "Oxcarbazepine (Trileptal)", "Carbamazepine (Tegretol)", "Methylphenidate (Ritalin)",
        "Amphetamine/dextroamphetamine (Adderall)", "Lisdexamfetamine (Vyvanse)", "Atomoxetine (Strattera)",
        // Pain / neuro (prescription)
        "Gabapentin (Neurontin)", "Pregabalin (Lyrica)", "Tramadol", "Hydrocodone/acetaminophen (Vicodin)",
        "Oxycodone", "Oxycodone/acetaminophen (Percocet)", "Morphine sulfate", "Fentanyl patch",
        "Cyclobenzaprine (Flexeril)", "Meloxicam (Mobic)", "Celecoxib (Celebrex)", "Diclofenac",
        "Sumatriptan (Imitrex)", "Topiramate (Topamax)", "Levetiracetam (Keppra)", "Baclofen",
        "Hydromorphone (Dilaudid)", "Methadone", "Buprenorphine (Suboxone)", "Naltrexone",
        "Naloxone (Narcan)", "Rizatriptan (Maxalt)", "Eletriptan (Relpax)", "Zolmitriptan (Zomig)",
        "Carbidopa/levodopa (Sinemet)", "Ropinirole (Requip)", "Pramipexole (Mirapex)",
        "Phenytoin (Dilantin)", "Phenobarbital", "Clobazam (Onfi)", "Lacosamide (Vimpat)",
        "Tizanidine (Zanaflex)", "Methocarbamol (Robaxin)", "Indomethacin", "Ketorolac (Toradol)",
        // Thyroid / hormone
        "Levothyroxine (Synthroid)", "Methimazole", "Liothyronine", "Propylthiouracil (PTU)",
        "Desiccated thyroid (Armour Thyroid)", "Hydrocortisone (oral)", "Fludrocortisone",
        "Prednisolone", "Dexamethasone", "Methylprednisolone (Medrol)",
        // Antibiotics
        "Amoxicillin", "Azithromycin (Z-Pak)", "Ciprofloxacin", "Doxycycline", "Cephalexin (Keflex)",
        "Clindamycin", "Metronidazole (Flagyl)", "Trimethoprim/sulfamethoxazole (Bactrim)",
        "Levofloxacin", "Nitrofurantoin (Macrobid)", "Penicillin V", "Amoxicillin/clavulanate (Augmentin)",
        "Cefdinir", "Ceftriaxone", "Vancomycin", "Linezolid (Zyvox)", "Meropenem",
        "Piperacillin/tazobactam (Zosyn)", "Gentamicin", "Tobramycin", "Rifampin",
        // GI (prescription)
        "Omeprazole", "Esomeprazole", "Pantoprazole (Protonix)", "Ranitidine", "Ondansetron (Zofran)",
        "Sucralfate", "Dicyclomine (Bentyl)", "Mesalamine", "Lansoprazole (Prevacid)",
        "Rabeprazole (Aciphex)", "Metoclopramide (Reglan)", "Promethazine (Phenergan)",
        "Lubiprostone (Amitiza)", "Linaclotide (Linzess)", "Ursodiol",
        // Allergy / immune (prescription)
        "Hydroxyzine (Atarax)", "Cetirizine", "EpiPen (epinephrine auto-injector)",
        "Montelukast", "Omalizumab (Xolair)", "Dupilumab (Dupixent)", "Azelastine nasal spray",
        // Blood thinners / anticoagulants extra
        "Heparin", "Enoxaparin (Lovenox)", "Fondaparinux (Arixtra)", "Argatroban",
        // Women's health
        "Norethindrone/ethinyl estradiol (birth control)", "Medroxyprogesterone", "Estradiol", "Progesterone",
        "Levonorgestrel IUD (Mirena)", "Etonogestrel implant (Nexplanon)", "Clomiphene",
        // Misc chronic
        "Allopurinol", "Colchicine", "Finasteride", "Tamsulosin (Flomax)", "Sildenafil (Viagra)",
        "Tadalafil (Cialis)", "Latanoprost eye drops", "Timolol eye drops", "Methotrexate", "Hydroxychloroquine",
        "Adalimumab (Humira)", "Etanercept (Enbrel)", "Alendronate (Fosamax)", "Risedronate (Actonel)",
        "Denosumab (Prolia)", "Teriparatide (Forteo)", "Oxybutynin", "Mirabegron (Myrbetriq)",
        "Donepezil (Aricept)", "Memantine (Namenda)", "Rivastigmine (Exelon)",
        // Vitamins / supplements
        "Vitamin D3", "Vitamin B12", "Multivitamin", "Fish oil", "Iron supplement (ferrous sulfate)",
        "Calcium supplement", "Magnesium supplement", "Folic acid", "Biotin", "Potassium chloride",
        "Thiamine (B1)", "Zinc supplement", "Coenzyme Q10", "Prenatal vitamin", "Vitamin C",
        "Ferrous gluconate", "Glucosamine", "Turmeric / curcumin",
        // Medium-common — frequently prescribed, not everyday OTC
        "Olmesartan (Benicar)", "Telmisartan (Micardis)", "Benazepril", "Quinapril", "Nifedipine",
        "Labetalol", "Nebivolol (Bystolic)", "Clonidine", "Prazosin", "Doxazosin", "Terazosin",
        "Isosorbide dinitrate", "Ranolazine (Ranexa)", "Sacubitril/valsartan (Entresto)",
        "Ezetimibe (Zetia)", "Fenofibrate", "Gemfibrozil", "Lovastatin", "Evolocumab (Repatha)",
        "Lisinopril/HCTZ", "Losartan/HCTZ", "Amlodipine/benazepril (Lotrel)",
        "Semaglutide (Wegovy)", "Semaglutide oral (Rybelsus)", "Liraglutide (Saxenda)",
        "Insulin regular (Humulin R)", "Insulin NPH (Humulin N)", "Saxagliptin (Onglyza)",
        "Levalbuterol (Xopenex)", "Fluticasone/umeclidinium/vilanterol (Trelegy)",
        "Mometasone (Asmanex/Nasonex)", "Formoterol", "Salmeterol", "Mepolizumab (Nucala)",
        "Benralizumab (Fasenra)", "Tezepelumab (Tezspire)", "Auvi-Q (epinephrine)",
        "Amitriptyline", "Nortriptyline", "Imipramine", "Doxepin", "Desipramine",
        "Zolpidem (Ambien)", "Eszopiclone (Lunesta)", "Zaleplon (Sonata)", "Temazepam (Restoril)",
        "Ramelteon (Rozerem)", "Suvorexant (Belsomra)", "Lemborexant (Dayvigo)",
        "Modafinil (Provigil)", "Armodafinil (Nuvigil)", "Guanfacine (Intuniv)",
        "Methylphenidate ER (Concerta)", "Dexmethylphenidate (Focalin)",
        "Paliperidone (Invega)", "Brexpiprazole (Rexulti)", "Lumateperone (Caplyta)",
        "Clozapine (Clozaril)", "Chlorpromazine (Thorazine)",
        "Carisoprodol (Soma)", "Orphenadrine", "Diclofenac gel (Voltaren)", "Lidocaine patch",
        "Nabumetone", "Etodolac", "Piroxicam", "Codeine/acetaminophen (Tylenol #3)",
        "Butalbital/acetaminophen/caffeine (Fioricet)", "Tapentadol (Nucynta)",
        "Naratriptan (Amerge)", "Frovatriptan (Frova)", "Ubrogepant (Ubrelvy)",
        "Rimegepant (Nurtec)", "Erenumab (Aimovig)", "Fremanezumab (Ajovy)",
        "Galcanezumab (Emgality)", "OnabotulinumtoxinA (Botox for migraine)",
        "Zonisamide (Zonegran)", "Brivaracetam (Briviact)", "Eslicarbazepine (Aptiom)",
        "Ethosuximide (Zarontin)", "Primidone", "Entacapone", "Rasagiline (Azilect)",
        "Selegiline", "Amantadine", "Galantamine (Razadyne)", "Dextromethorphan/quinidine (Nuedexta)",
        "Meclizine (Antivert)", "Scopolamine patch", "Prochlorperazine (Compazine)",
        "Hyoscyamine (Levsin)", "Diphenoxylate/atropine (Lomotil)", "Lactulose", "Senna",
        "Pancrelipase (Creon)", "Cholestyramine", "Colesevelam (Welchol)",
        "Plecanatide (Trulance)", "Prucalopride (Motegrity)", "Sulfasalazine",
        "Budesonide (Entocort)", "Leflunomide (Arava)", "Tofacitinib (Xeljanz)",
        "Upadacitinib (Rinvoq)", "Vedolizumab (Entyvio)", "Certolizumab (Cimzia)",
        "Golimumab (Simponi)", "Ixekizumab (Taltz)", "Risankizumab (Skyrizi)",
        "Guselkumab (Tremfya)", "Ibandronate (Boniva)", "Zoledronic acid (Reclast)",
        "Febuxostat (Uloric)", "Dutasteride (Avodart)", "Silodosin (Rapaflo)",
        "Alfuzosin (Uroxatral)", "Solifenacin (Vesicare)", "Tolterodine (Detrol)",
        "Vibegron (Gemtesa)", "Brimonidine eye drops", "Dorzolamide eye drops",
        "Travoprost eye drops", "Bimatoprost (Lumigan)", "Olopatadine eye drops",
        "Fluconazole (Diflucan)", "Terbinafine (Lamisil)", "Nystatin",
        "Acyclovir (Zovirax)", "Valacyclovir (Valtrex)", "Oseltamivir (Tamiflu)",
        "Baloxavir (Xofluza)", "Nitroglycerin ointment", "Isosorbide mononitrate ER",
        "Varenicline (Chantix)", "Nicotine patch", "Nicotine gum", "Bupropion (Zyban)",
        "Naltrexone ER (Vivitrol)", "Acamprosate (Campral)", "Disulfiram (Antabuse)",
        "Buprenorphine ER (Sublocade)", "Phentermine", "Phentermine/topiramate (Qsymia)",
        "Naltrexone/bupropion (Contrave)", "Orlistat (Xenical/Alli)",
        "Testosterone cypionate", "Testosterone gel (AndroGel)", "Estradiol patch",
        "Conjugated estrogens (Premarin)", "Drospirenone/ethinyl estradiol (Yaz)",
        "Norelgestromin/ethinyl estradiol (patch)", "Etonogestrel/ethinyl estradiol (NuvaRing)",
        "Medroxyprogesterone injection (Depo-Provera)", "Levonorgestrel emergency (Plan B)",
        "Vardenafil (Levitra)", "Avanafil (Stendra)", "Sildenafil (Revatio)",
        "Sevelamer (Renvela)", "Calcium acetate (PhosLo)", "Sodium zirconium cyclosilicate (Lokelma)",
        "Patiromer (Veltassa)", "Epoetin alfa (Procrit/Epogen)", "Darbepoetin (Aranesp)",
        "Calcitriol", "Cinacalcet (Sensipar)", "Iron sucrose (Venofer)",
        "Ferric carboxymaltose (Injectafer)", "Vitamin B12 injection",
        "Bictegravir/emtricitabine/tenofovir (Biktarvy)", "Emtricitabine/tenofovir (Descovy)",
        "Dolutegravir (Tivicay)", "Sofosbuvir/velpatasvir (Epclusa)",
        "Glecaprevir/pibrentasvir (Mavyret)", "Entecavir (Baraclude)", "Tenofovir (Viread)",
        "Medical cannabis / THC", "CBD oil",
        // Rare / specialty — EMS-relevant biologics, orphan, transplant, chemo
        "Tacrolimus (Prograf)", "Cyclosporine", "Mycophenolate (CellCept)", "Sirolimus (Rapamune)",
        "Azathioprine (Imuran)", "Belatacept (Nulojix)", "Antithymocyte globulin",
        "Imatinib (Gleevec)", "Rituximab (Rituxan)", "Infliximab (Remicade)", "Ustekinumab (Stelara)",
        "Secukinumab (Cosentyx)", "Tocilizumab (Actemra)", "Abatacept (Orencia)",
        "Natalizumab (Tysabri)", "Ocrelizumab (Ocrevus)", "Fingolimod (Gilenya)",
        "Eculizumab (Soliris)", "Ravulizumab (Ultomiris)", "Emicizumab (Hemlibra)",
        "Factor VIII concentrate", "Factor IX concentrate", "Desmopressin (DDAVP)",
        "Octreotide (Sandostatin)", "Lanreotide", "Pasireotide",
        "Carglumic acid (Carbaglu)", "Sodium phenylbutyrate", "Glycerol phenylbutyrate (Ravicti)",
        "Nitisinone (Orfadin)", "Cysteamine (Cystagon)", "Miglustat (Zavesca)",
        "Alglucosidase alfa (Myozyme)", "Idursulfase (Elaprase)", "Laronidase (Aldurazyme)",
        "Agalsidase beta (Fabrazyme)", "Imiglucerase (Cerezyme)", "Eliglustat (Cerdelga)",
        "Elexacaftor/tezacaftor/ivacaftor (Trikafta)", "Ivacaftor (Kalydeco)",
        "Nusinersen (Spinraza)", "Onasemnogene abeparvovec (Zolgensma)", "Risdiplam (Evrysdi)",
        "Eteplirsen (Exondys 51)", "Deflazacort (Emflaza)",
        "Riluzole (Rilutek)", "Edaravone (Radicava)", "Relyvrio",
        "Sapropterin (Kuvan)", "Pegvaliase (Palynziq)",
        "Midodrine", "Fludrocortisone acetate", "Pyridostigmine (Mestinon)",
        "Dantrolene", "Diazoxide", "Octreotide rescue kit",
        "Hydroxyurea", "Deferasirox (Exjade)", "Deferoxamine (Desferal)",
        "Bosentan (Tracleer)", "Ambrisentan (Letairis)", "Macitentan (Opsumit)",
        "Sildenafil (Revatio) for PAH", "Treprostinil (Remodulin)", "Epoprostenol (Flolan)",
        "Selexipag (Uptravi)", "Riociguat (Adempas)",
        "Ivacaftor/lumacaftor (Orkambi)", "Tezacaftor/ivacaftor (Symdeko)",
        "Cannabidiol (Epidiolex)", "Stiripentol (Diacomit)", "Fenfluramine (Fintepla)",
        "Vigabatrin (Sabril)", "Rufinamide (Banzel)", "Perampanel (Fycompa)",
        "Isotretinoin (Accutane)", "Acitretin", "Apremilast (Otezla)",
        "Lenalidomide (Revlimid)", "Thalidomide", "Pomalidomide (Pomalyst)",
        "Imatinib", "Dasatinib (Sprycel)", "Nilotinib (Tasigna)", "Bosutinib (Bosulif)",
        "Ibrutinib (Imbruvica)", "Venetoclax (Venclexta)", "Ruxolitinib (Jakafi)",
        "Pembrolizumab (Keytruda)", "Nivolumab (Opdivo)", "Atezolizumab (Tecentriq)",
        "Bevacizumab (Avastin)", "Trastuzumab (Herceptin)", "Pertuzumab (Perjeta)",
        "Tamoxifen", "Anastrozole (Arimidex)", "Letrozole (Femara)", "Exemestane (Aromasin)",
        "Leuprolide (Lupron)", "Goserelin (Zoladex)", "Abiraterone (Zytiga)",
        "Enzalutamide (Xtandi)", "Bicalutamide (Casodex)",
        "Insulin pump therapy", "Continuous glucose monitor (CGM)",
        "Portable oxygen concentrator", "Home BiPAP/CPAP",
    ]

    // MARK: - Allergies (common first, then rare / specialty)

    private static let _allergies: [String] = [
        // Medications — common
        "Penicillin", "Amoxicillin", "Sulfa drugs (sulfonamides)", "Aspirin", "Ibuprofen (NSAIDs)",
        "Naproxen", "Codeine", "Morphine", "Cephalosporins", "Erythromycin", "Tetracycline",
        "Contrast dye (IV)", "Latex", "Local anesthetics (lidocaine/novocaine)", "ACE inhibitors",
        "Statins", "Insulin", "Aspirin / NSAID triad", "Opioids", "Vancomycin",
        "Fluoroquinolones", "Macrolide antibiotics", "Metronidazole", "Clindamycin",
        "Phenytoin", "Carbamazepine", "Lamotrigine", "Allopurinol", "Heparin (HIT)",
        "Protamine", "Aspirin-exacerbated respiratory disease (AERD)",
        // Foods — common
        "Peanuts", "Tree nuts (almonds, cashews, walnuts)", "Shellfish (shrimp, crab, lobster)",
        "Fish", "Milk / dairy", "Eggs", "Soy", "Wheat / gluten", "Sesame", "Corn",
        "Strawberries", "Kiwi", "Avocado", "Mustard", "Sulfites", "Chocolate", "Tomato",
        "Banana", "Citrus", "Coconut", "Oats", "Barley", "Rye", "Beef", "Pork", "Chicken",
        // Insect / venom
        "Bee stings", "Wasp stings", "Fire ant bites", "Mosquito bites", "Hornet stings",
        "Yellow jacket stings",
        // Environmental
        "Pollen", "Grass", "Ragweed", "Dust mites", "Mold", "Pet dander (cats)", "Pet dander (dogs)",
        "Cockroach allergen", "Horse dander", "Feathers", "Smoke / incense",
        // Contact / other common
        "Latex gloves", "Adhesive tape / bandages", "Nickel", "Iodine", "Chlorhexidine",
        "Hair dye (PPD)", "Fragrance / perfume", "Formaldehyde", "Neomycin", "Bacitracin",
        "Benzocaine", "Povidone-iodine", "Alcohol swabs", "Sunlight (photosensitivity)",
        // Medium-common — individual foods, drugs, and contact triggers people actually list
        "Almonds", "Cashews", "Walnuts", "Pecans", "Hazelnuts", "Brazil nuts", "Macadamia nuts",
        "Pistachios", "Shrimp", "Crab", "Lobster", "Clams", "Mussels", "Oysters", "Scallops",
        "Cod", "Salmon", "Tuna", "Tilapia", "Catfish", "Trout", "Anchovies",
        "Garlic", "Onion", "Cinnamon", "Mango", "Pineapple", "Melon", "Apple", "Peach",
        "Cherry", "Carrot", "Celery", "Green pea", "Lentils", "Chickpeas", "Potato",
        "Red dye 40", "Blue dye 1", "Yellow dye 6", "Preservatives (parabens)",
        "Methylisothiazolinone (MI/MCI)", "Propylene glycol", "Lanolin", "Fragrance mix",
        "Cocamidopropyl betaine", "Quaternium-15", "Benzalkonium chloride", "Thimerosal",
        "Oxybenzone (sunscreen)", "Chemical sunscreen", "Tea tree oil", "Lavender",
        "Essential oils", "Wool", "Latex rubber", "Cobalt", "Chromium", "Epoxy resin",
        "Acrylic nail products", "Nail polish", "Makeup / cosmetics", "Laundry detergent",
        "Fabric softener", "Bleach", "Ammonia", "Cleaning products", "Cigarette smoke",
        "Wood smoke", "Birch pollen", "Oak pollen", "Cedar / juniper pollen", "Timothy grass",
        "Bermuda grass", "Mugwort", "Aspergillus mold", "Alternaria mold",
        "Hamster dander", "Rabbit dander", "Guinea pig dander", "Bird feathers / droppings",
        "Ampicillin", "Augmentin (amox/clav)", "Cefazolin (Ancef)", "Ceftriaxone (Rocephin)",
        "Azithromycin (Z-Pak)", "Doxycycline", "Ciprofloxacin (Cipro)", "Levofloxacin (Levaquin)",
        "Nitrofurantoin (Macrobid)", "Fluconazole", "Acyclovir", "Tramadol", "Hydrocodone",
        "Oxycodone", "Hydromorphone (Dilaudid)", "Fentanyl", "Gabapentin", "Pregabalin (Lyrica)",
        "Acetaminophen (Tylenol)", "Ketorolac (Toradol)", "Prednisone / corticosteroids",
        "ARBs (losartan/valsartan class)", "Beta blockers", "Calcium channel blockers",
        "Amiodarone", "Metformin", "Sulfonylureas", "GLP-1 agonists (Ozempic class)",
        "Biologics (Humira/Remicade class)", "Heparin", "Enoxaparin (Lovenox)",
        "Lactose intolerance", "Gluten sensitivity (non-celiac)", "Histamine-rich foods",
        "Red wine / alcohol sulfites", "Beer (barley)", "Soy sauce", "Cashew butter",
        "Peanut butter", "Whey protein powder", "Casein protein powder",
        // Rare / specialty allergies — EMS / anesthesia relevant
        "Alpha-gal syndrome (red meat)", "Anisakis (fish parasite)", "Buckwheat",
        "Celery-mugwort-spice syndrome", "Oral allergy syndrome (pollen-food)",
        "Lupin flour", "Quinoa", "Chia seeds", "Poppy seeds", "Sunflower seeds",
        "Gelatin (vaccine/capsule)", "Egg-based vaccines", "Yeast (Saccharomyces)",
        "Carmine / cochineal (red dye)", "Tartrazine (Yellow 5)", "Aspartame",
        "MSG (monosodium glutamate)", "Histamine intolerance", "Nickel (systemic)",
        "Propofol", "Rocuronium", "Succinylcholine", "Atracurium", "Cisatracurium",
        "Morphine / codeine (mast cell)", "Blue dye (isosulfan / patent blue)",
        "Chlorhexidine gluconate anaphylaxis", "Ethylene oxide", "Phthalates",
        "Natural rubber latex (Type I)", "Cashew / pistachio cross-reactivity",
        "Peanut oil (refined vs crude)", "Soy lecithin", "Casein (dairy protein)",
        "Whey protein", "Alpha-lactalbumin", "Beta-lactoglobulin",
        "Shrimp tropomyosin", "Fish parvalbumin", "Peanut Ara h 2",
        "Wheat omega-5 gliadin", "Buckwheat anaphylaxis", "Royal jelly",
        "Propolis", "Bee pollen supplements", "Chamomile", "Echinacea",
        "Ginkgo biloba", "St. John's wort", "Kava", "Valerian",
        "Radiocontrast (iodinated)", "Gadolinium MRI contrast", "Fluorescein dye",
        "Patent blue V", "Indigo carmine", "Methylene blue",
        "Dextran", "Hetastarch", "Albumin infusion", "Fresh frozen plasma",
        "Cryoprecipitate", "Platelet transfusion", "IVIG", "Blood transfusion reaction",
        "Iron dextran", "Iron sucrose", "Ferric carboxymaltose",
        "PEG (polyethylene glycol)", "Polysorbate 80", "Trometamol",
        "COVID vaccine (PEG/polysorbate)", "Influenza vaccine (egg)",
        "Tetanus toxoid", "MMR vaccine", "Yellow fever vaccine",
        "Aspirin desensitization needed", "Multiple drug allergy syndrome",
        "Mast cell activation syndrome (MCAS) triggers", "Hereditary angioedema triggers",
        "Cold urticaria", "Cholinergic urticaria", "Exercise-induced anaphylaxis",
        "Food-dependent exercise-induced anaphylaxis (FDEIA)",
        "Aquagenic urticaria", "Solar urticaria", "Pressure urticaria",
        "Seminal fluid allergy", "Catamenial anaphylaxis",
        "Anesthetic gas (halogenated)", "Nitrous oxide sensitivity",
        "Bone cement (methyl methacrylate)", "Surgical glue (cyanoacrylate)",
        "Chlorine / pool chemicals", "Isocyanates", "Formalin",
    ]

    // MARK: - Conditions (common first, then rare / EMS-critical)

    private static let _conditions: [String] = [
        // Cardiovascular — common
        "Hypertension (high blood pressure)", "Coronary artery disease", "Atrial fibrillation (AFib)",
        "Congestive heart failure", "Prior heart attack (MI)", "Pacemaker", "Implanted defibrillator (ICD)",
        "High cholesterol", "Deep vein thrombosis (DVT)", "Pulmonary embolism history", "Peripheral artery disease",
        "Stroke history", "Aortic aneurysm", "Angina", "Heart valve disease", "Cardiomyopathy",
        // Endocrine / metabolic — common
        "Type 1 diabetes", "Type 2 diabetes", "Hypothyroidism", "Hyperthyroidism", "Obesity",
        "Adrenal insufficiency", "Osteoporosis", "Prediabetes", "Metabolic syndrome", "Gout",
        // Respiratory — common
        "Asthma", "COPD", "Sleep apnea", "Pulmonary fibrosis", "Chronic bronchitis", "Emphysema",
        "Pneumonia history", "Pulmonary hypertension",
        // Neurological — common
        "Epilepsy / seizure disorder", "Migraine", "Parkinson's disease", "Multiple sclerosis",
        "Alzheimer's / dementia", "Traumatic brain injury history", "Neuropathy", "Essential tremor",
        "Stroke / TIA history", "Concussion history",
        // Mental health — common
        "Depression", "Anxiety disorder", "Bipolar disorder", "PTSD", "Schizophrenia", "ADHD",
        "Obsessive-compulsive disorder (OCD)", "Panic disorder", "Autism spectrum disorder",
        // GI / renal — common
        "GERD / acid reflux", "Crohn's disease", "Ulcerative colitis", "Celiac disease",
        "Chronic kidney disease", "Dialysis patient", "Liver disease / cirrhosis", "Gallstones",
        "Irritable bowel syndrome (IBS)", "Pancreatitis history", "Hepatitis B", "Hepatitis C",
        // Blood / immune — common
        "Anemia", "Hemophilia", "Sickle cell disease", "Blood clotting disorder", "HIV/AIDS",
        "Autoimmune disorder", "Rheumatoid arthritis", "Lupus", "Psoriasis", "Thyroiditis",
        // Other common
        "Cancer (active treatment)", "Pregnancy", "Organ transplant recipient", "Glaucoma",
        "Chronic pain condition", "Fibromyalgia", "Osteoarthritis", "Hearing loss",
        "Vision impairment / blindness", "Amputation", "Wheelchair user", "Hearing aid user",
        "Intellectual disability", "Down syndrome", "Cerebral palsy",
        // Medium-common — frequent chronic / post-op / lifestyle-linked diagnoses
        "Diverticulosis", "Diverticulitis", "Peptic ulcer disease", "H. pylori history",
        "Barrett's esophagus", "Hiatal hernia", "Gastritis", "Gastroparesis",
        "Chronic constipation", "Fatty liver (NAFLD/NASH)", "Gallbladder disease",
        "Cholecystectomy history", "Appendectomy history", "Hernia (inguinal/umbilical)",
        "Kidney stones", "Recurrent UTI", "Benign prostatic hyperplasia (BPH)",
        "Overactive bladder", "Urinary incontinence", "Chronic back pain", "Sciatica",
        "Herniated disc", "Degenerative disc disease", "Spinal stenosis", "Scoliosis",
        "Osteopenia", "Vitamin D deficiency", "Vitamin B12 deficiency", "Iron deficiency anemia",
        "Hypokalemia history", "Seasonal allergies / allergic rhinitis", "Chronic sinusitis",
        "Nasal polyps", "Eczema / atopic dermatitis", "Contact dermatitis", "Chronic urticaria / hives",
        "Angioedema history", "Exercise-induced asthma", "Bronchiectasis", "Long COVID",
        "Chronic fatigue syndrome (ME/CFS)", "Restless legs syndrome", "Insomnia",
        "Atrial flutter", "SVT / PSVT", "Wolff-Parkinson-White (WPW)", "Mitral valve prolapse",
        "Aortic stenosis", "Mitral regurgitation", "Syncope history", "Orthostatic hypotension",
        "POTS (postural orthostatic tachycardia)", "Raynaud's phenomenon",
        "Diabetic neuropathy", "Diabetic retinopathy", "Diabetic nephropathy",
        "Diabetic foot ulcer", "Peripheral neuropathy", "Carpal tunnel syndrome",
        "Plantar fasciitis", "Osteoarthritis of knee", "Osteoarthritis of hip",
        "Knee replacement", "Hip replacement", "Spinal fusion", "ACL reconstruction",
        "Rotator cuff tear / repair", "Chronic venous insufficiency", "Varicose veins",
        "Lymphedema", "Cellulitis history", "MRSA colonization / history", "C. diff history",
        "Shingles / postherpetic neuralgia", "HSV (cold sores / genital herpes)",
        "Psoriatic arthritis", "Ankylosing spondylitis", "Polymyalgia rheumatica",
        "Hashimoto's thyroiditis", "Graves' disease", "Goiter", "Thyroid nodule",
        "PCOS (polycystic ovary syndrome)", "Endometriosis", "Uterine fibroids",
        "Menopause / postmenopausal", "Premenstrual dysphoric disorder (PMDD)",
        "Erectile dysfunction", "Low testosterone / hypogonadism", "Infertility",
        "Alcohol use disorder", "Opioid use disorder", "Substance use disorder",
        "Tobacco / nicotine dependence", "Cannabis use disorder",
        "Eating disorder (anorexia/bulimia/BED)", "Generalized anxiety disorder",
        "Major depressive disorder", "Social anxiety disorder", "Insomnia disorder",
        "Borderline personality disorder", "Tourette syndrome", "Learning disability",
        "Dyslexia", "Mild cognitive impairment", "Lewy body dementia", "Vascular dementia",
        "Frontotemporal dementia", "Normal pressure hydrocephalus",
        "Meniere's disease", "BPPV / positional vertigo", "Tinnitus", "TMJ disorder",
        "Dysphagia / swallowing difficulty", "Aspiration risk", "Obstructive sleep apnea (treated)",
        "Central sleep apnea", "Obesity hypoventilation syndrome",
        "Coronary stent / PCI history", "CABG / bypass surgery history",
        "Heart valve replacement", "Mechanical heart valve", "Bioprosthetic heart valve",
        "Cardiac ablation history", "Watchman / LAA occluder", "TAVR history",
        "Carotid stenosis", "Bicuspid aortic valve", "Congenital heart disease",
        "Familial hypercholesterolemia", "Hypertriglyceridemia", "Statin intolerance",
        "Resistant hypertension", "White coat hypertension",
        "Polycystic kidney disease", "IgA nephropathy", "Nephrotic syndrome history",
        "Acute kidney injury history", "Kidney transplant waitlist",
        "Breast cancer history", "Prostate cancer history", "Colon cancer history",
        "Melanoma / skin cancer history", "Lung cancer history", "Thyroid cancer history",
        "Cancer in remission", "Chemotherapy history", "Radiation therapy history",
        "Immunocompromised", "Asplenia / splenectomy", "Steroid-dependent",
        "Bariatric surgery history", "Gastric bypass", "Sleeve gastrectomy",
        "Dumping syndrome", "Malnutrition", "High fall risk", "Frailty",
        "Pressure ulcer / bedsore risk", "Chronic wound", "Venous stasis ulcer",
        "Hearing aid dependent", "Cochlear implant", "CPAP/BiPAP dependent",
        "Home oxygen", "PICC line / mid-line", "Foley catheter dependent",
        "Intermittent self-catheterization", "Suprapubic catheter",
        "C-section history", "Postpartum depression", "Preterm birth history",
        "NICU graduate", "Developmental delay", "Speech delay", "Global developmental delay",
        "Cleft lip / palate", "Scoliosis (moderate)", "Joint hypermobility",
        "Hypermobility spectrum disorder", "Chronic migraine", "Vestibular migraine",
        "Cluster headache history", "Trigeminal neuralgia history",
        "Complex regional pain syndrome (CRPS)", "Myofascial pain syndrome",
        "Fibromyalgia (diagnosed)", "Chronic pain syndrome",
        "Seizure disorder — focal", "Seizure disorder — generalized",
        "Febrile seizure history", "Psychogenic non-epileptic seizures (PNES)",
        "Vagus nerve stimulator (VNS)", "Deep brain stimulator (DBS)",
        "Spinal cord stimulator", "Intrathecal pain / baclofen pump",
        "Pacemaker-dependent", "ICD shocks history", "LifeVest / wearable defibrillator",
        "Anticoagulation required (INR monitoring)", "Blood thinner dependent",
        // Rare / EMS-critical conditions
        "Malignant hyperthermia susceptibility", "Pseudocholinesterase deficiency",
        "G6PD deficiency", "Porphyria", "Acute intermittent porphyria",
        "Hereditary angioedema (HAE)", "Mast cell activation syndrome (MCAS)",
        "Systemic mastocytosis", "Ehlers-Danlos syndrome", "Marfan syndrome",
        "Loeys-Dietz syndrome", "Vascular Ehlers-Danlos (vEDS)",
        "Brugada syndrome", "Long QT syndrome", "Short QT syndrome",
        "Catecholaminergic polymorphic VT (CPVT)", "Arrhythmogenic right ventricular cardiomyopathy",
        "Hypertrophic cardiomyopathy (HCM)", "Dilated cardiomyopathy",
        "Left ventricular assist device (LVAD)", "Total artificial heart",
        "Heart transplant recipient", "Kidney transplant recipient", "Liver transplant recipient",
        "Lung transplant recipient", "Bone marrow / stem cell transplant",
        "Myasthenia gravis", "Lambert-Eaton myasthenic syndrome",
        "Amyotrophic lateral sclerosis (ALS)", "Muscular dystrophy", "Duchenne muscular dystrophy",
        "Spinal muscular atrophy (SMA)", "Myotonic dystrophy", "Charcot-Marie-Tooth disease",
        "Guillain-Barré syndrome history", "Transverse myelitis",
        "Addison's disease", "Cushing's syndrome", "Congenital adrenal hyperplasia",
        "Pheochromocytoma", "Primary aldosteronism", "Diabetes insipidus",
        "Hypoparathyroidism", "Hyperparathyroidism", "Multiple endocrine neoplasia (MEN)",
        "Cystic fibrosis", "Primary ciliary dyskinesia", "Alpha-1 antitrypsin deficiency",
        "Idiopathic pulmonary fibrosis", "Sarcoidosis", "Wegener's / GPA vasculitis",
        "Churg-Strauss / EGPA", "Goodpasture's syndrome", "Pulmonary alveolar proteinosis",
        "Phenylketonuria (PKU)", "Maple syrup urine disease", "Urea cycle disorder",
        "Organic acidemia", "Homocystinuria", "Galactosemia", "Glycogen storage disease",
        "Fabry disease", "Gaucher disease", "Pompe disease", "Mucopolysaccharidosis",
        "Tay-Sachs disease", "Niemann-Pick disease", "Wilson's disease", "Hemochromatosis",
        "Alpha-thalassemia", "Beta-thalassemia", "Sickle cell trait", "Hereditary spherocytosis",
        "Paroxysmal nocturnal hemoglobinuria (PNH)", "Aplastic anemia", "ITP", "TTP",
        "von Willebrand disease", "Factor V Leiden", "Antiphospholipid syndrome",
        "Protein C deficiency", "Protein S deficiency", "Antithrombin III deficiency",
        "Idiopathic thrombocytopenic purpura", "Hemolytic uremic syndrome",
        "Primary immunodeficiency", "SCID history", "Common variable immunodeficiency (CVID)",
        "Chronic granulomatous disease", "Complement deficiency",
        "Behcet's disease", "Sjogren's syndrome", "Scleroderma / systemic sclerosis",
        "Polymyositis / dermatomyositis", "Mixed connective tissue disease",
        "Antiphospholipid antibody syndrome", "Vasculitis", "Takayasu arteritis",
        "Giant cell arteritis / temporal arteritis", "Kawasaki disease history",
        "Rett syndrome", "Fragile X syndrome", "Prader-Willi syndrome", "Angelman syndrome",
        "Turner syndrome", "Klinefelter syndrome", "Noonan syndrome", "Williams syndrome",
        "DiGeorge / 22q11 deletion", "CHARGE syndrome", "Cornelia de Lange syndrome",
        "Tuberous sclerosis", "Neurofibromatosis type 1", "Neurofibromatosis type 2",
        "Von Hippel-Lindau disease", "Sturge-Weber syndrome", "Moyamoya disease",
        "Arnold-Chiari malformation", "Spina bifida", "Hydrocephalus / VP shunt",
        "Tracheostomy dependent", "Ventilator dependent", "Home oxygen dependent",
        "G-tube / feeding tube dependent", "Central line / port-a-cath",
        "Ostomy (colostomy/ileostomy)", "Nephrostomy", "Peritoneal dialysis",
        "Hemodialysis fistula / graft", "Insulin pump dependent",
        "Adrenal crisis risk", "Seizure cluster / status epilepticus risk",
        "Anaphylaxis history", "Severe asthma / brittle asthma",
        "Do Not Resuscitate (DNR) order", "POLST / advance directive on file",
        "Blood refusal (Jehovah's Witness)", "Language barrier — interpreter needed",
        "Hearing impairment — ASL user", "Blind / low vision — needs assistance",
        "Service animal dependent", "Cognitive impairment — needs caregiver",
        "Huntington's disease", "Creutzfeldt-Jakob disease risk",
        "Narcolepsy", "Cataplexy", "Idiopathic hypersomnia",
        "Cluster headache", "Trigeminal neuralgia", "Complex regional pain syndrome",
        "Eosinophilic esophagitis", "Eosinophilic gastroenteritis",
        "Microscopic colitis", "Short bowel syndrome", "Intestinal failure",
        "Primary biliary cholangitis", "Primary sclerosing cholangitis", "Autoimmune hepatitis",
        "Budd-Chiari syndrome", "Portal hypertension", "Esophageal varices",
        "Interstitial cystitis", "Neurogenic bladder", "Spinal cord injury",
        "Paraplegia", "Quadriplegia / tetraplegia", "Locked-in syndrome",
        "Brain tumor (active)", "Leukemia (active)", "Lymphoma (active)",
        "Multiple myeloma", "Myelodysplastic syndrome", "Aplastic anemia (severe)",
        "Postpartum / recent delivery", "Ectopic pregnancy risk", "Pre-eclampsia history",
        "Hyperemesis gravidarum", "Gestational diabetes",
        "Gender-affirming hormone therapy", "Post-surgical — recent major surgery",
        "Jehovah's Witness — no blood products", "Hard of hearing",
    ]
}
