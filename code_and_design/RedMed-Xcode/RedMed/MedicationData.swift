import Foundation

// Common prescription + OTC medications for autocomplete suggestions.
let commonMedications: [String] = [
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
    // Diabetes
    "Metformin", "Glipizide", "Glyburide", "Insulin glargine (Lantus)", "Insulin lispro (Humalog)",
    "Insulin aspart (Novolog)", "Sitagliptin (Januvia)", "Empagliflozin (Jardiance)",
    "Semaglutide (Ozempic)", "Liraglutide (Victoza)", "Dulaglutide (Trulicity)", "Pioglitazone",
    // Respiratory
    "Albuterol inhaler", "Fluticasone/salmeterol (Advair)", "Budesonide/formoterol (Symbicort)",
    "Montelukast (Singulair)", "Tiotropium (Spiriva)", "Prednisone", "Ipratropium (Atrovent)",
    // Mental health
    "Sertraline (Zoloft)", "Escitalopram (Lexapro)", "Fluoxetine (Prozac)", "Citalopram (Celexa)",
    "Paroxetine (Paxil)", "Bupropion (Wellbutrin)", "Venlafaxine (Effexor)", "Duloxetine (Cymbalta)",
    "Trazodone", "Mirtazapine (Remeron)", "Alprazolam (Xanax)", "Lorazepam (Ativan)", "Clonazepam (Klonopin)",
    "Diazepam (Valium)", "Buspirone", "Quetiapine (Seroquel)", "Aripiprazole (Abilify)", "Risperidone",
    "Olanzapine (Zyprexa)", "Lithium", "Lamotrigine (Lamictal)", "Valproic acid (Depakote)",
    // Pain / neuro (prescription)
    "Gabapentin (Neurontin)", "Pregabalin (Lyrica)", "Tramadol", "Hydrocodone/acetaminophen (Vicodin)",
    "Oxycodone", "Oxycodone/acetaminophen (Percocet)", "Morphine sulfate", "Fentanyl patch",
    "Cyclobenzaprine (Flexeril)", "Meloxicam (Mobic)", "Celecoxib (Celebrex)", "Diclofenac",
    "Sumatriptan (Imitrex)", "Topiramate (Topamax)", "Levetiracetam (Keppra)", "Baclofen",
    // Thyroid / hormone
    "Levothyroxine (Synthroid)", "Methimazole", "Liothyronine",
    // Antibiotics
    "Amoxicillin", "Azithromycin (Z-Pak)", "Ciprofloxacin", "Doxycycline", "Cephalexin (Keflex)",
    "Clindamycin", "Metronidazole (Flagyl)", "Trimethoprim/sulfamethoxazole (Bactrim)",
    "Levofloxacin", "Nitrofurantoin (Macrobid)", "Penicillin V",
    // GI (prescription)
    "Omeprazole", "Esomeprazole", "Pantoprazole (Protonix)", "Ranitidine", "Ondansetron (Zofran)",
    "Sucralfate", "Dicyclomine (Bentyl)", "Mesalamine",
    // Allergy / immune (prescription)
    "Hydroxyzine (Atarax)", "Cetirizine", "EpiPen (epinephrine auto-injector)", "Prednisolone",
    "Montelukast",
    // Blood thinners / anticoagulants extra
    "Heparin", "Enoxaparin (Lovenox)",
    // Women's health
    "Norethindrone/ethinyl estradiol (birth control)", "Medroxyprogesterone", "Estradiol", "Progesterone",
    // Misc chronic
    "Allopurinol", "Colchicine", "Finasteride", "Tamsulosin (Flomax)", "Sildenafil (Viagra)",
    "Tadalafil (Cialis)", "Latanoprost eye drops", "Timolol eye drops", "Methotrexate", "Hydroxychloroquine",
    "Adalimumab (Humira)", "Etanercept (Enbrel)",
    // Vitamins / supplements
    "Vitamin D3", "Vitamin B12", "Multivitamin", "Fish oil", "Iron supplement (ferrous sulfate)",
    "Calcium supplement", "Magnesium supplement", "Folic acid", "Biotin",
]

// Common allergies and adverse reactions for autocomplete suggestions.
let commonAllergies: [String] = [
    // Medications
    "Penicillin", "Amoxicillin", "Sulfa drugs (sulfonamides)", "Aspirin", "Ibuprofen (NSAIDs)",
    "Naproxen", "Codeine", "Morphine", "Cephalosporins", "Erythromycin", "Tetracycline",
    "Contrast dye (IV)", "Latex", "Local anesthetics (lidocaine/novocaine)", "ACE inhibitors",
    "Statins", "Insulin",
    // Foods
    "Peanuts", "Tree nuts (almonds, cashews, walnuts)", "Shellfish (shrimp, crab, lobster)",
    "Fish", "Milk / dairy", "Eggs", "Soy", "Wheat / gluten", "Sesame", "Corn",
    "Strawberries", "Kiwi", "Avocado", "Mustard", "Sulfites",
    // Insect / venom
    "Bee stings", "Wasp stings", "Fire ant bites", "Mosquito bites",
    // Environmental
    "Pollen", "Grass", "Ragweed", "Dust mites", "Mold", "Pet dander (cats)", "Pet dander (dogs)",
    // Other
    "Latex gloves", "Adhesive tape / bandages", "Nickel", "Iodine", "Chlorhexidine",
    "Hair dye (PPD)", "Fragrance / perfume",
]

// Common medical conditions for autocomplete suggestions.
let commonConditions: [String] = [
    // Cardiovascular
    "Hypertension (high blood pressure)", "Coronary artery disease", "Atrial fibrillation (AFib)",
    "Congestive heart failure", "Prior heart attack (MI)", "Pacemaker", "Implanted defibrillator (ICD)",
    "High cholesterol", "Deep vein thrombosis (DVT)", "Pulmonary embolism history", "Peripheral artery disease",
    "Stroke history", "Aortic aneurysm",
    // Endocrine / metabolic
    "Type 1 diabetes", "Type 2 diabetes", "Hypothyroidism", "Hyperthyroidism", "Obesity",
    "Adrenal insufficiency", "Osteoporosis",
    // Respiratory
    "Asthma", "COPD", "Sleep apnea", "Pulmonary fibrosis", "Chronic bronchitis",
    // Neurological
    "Epilepsy / seizure disorder", "Migraine", "Parkinson's disease", "Multiple sclerosis",
    "Alzheimer's / dementia", "Traumatic brain injury history",
    // Mental health
    "Depression", "Anxiety disorder", "Bipolar disorder", "PTSD", "Schizophrenia", "ADHD",
    // GI / renal
    "GERD / acid reflux", "Crohn's disease", "Ulcerative colitis", "Celiac disease",
    "Chronic kidney disease", "Dialysis patient", "Liver disease / cirrhosis", "Gallstones",
    // Blood / immune
    "Anemia", "Hemophilia", "Sickle cell disease", "Blood clotting disorder", "HIV/AIDS",
    "Autoimmune disorder", "Rheumatoid arthritis", "Lupus",
    // Other
    "Cancer (active treatment)", "Pregnancy", "Organ transplant recipient", "Glaucoma",
    "Chronic pain condition", "Fibromyalgia", "Gout",
]
