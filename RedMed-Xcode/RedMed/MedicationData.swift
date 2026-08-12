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
        "Thiamine (B1)", "Zinc supplement", "Coenzyme Q10",
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
