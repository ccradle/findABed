# Shelter Edit — Demo Walkthrough

> Every hour a shelter isn't in the system is an hour a family can't find it.

This walkthrough tells the story of a CoC administrator onboarding new partner shelters and making them operational. It follows Marcus Okafor through three acts: importing shelter data from NC 211, correcting details that came through wrong, and protecting a domestic violence shelter.

---

## Act 1: Import — Three shelters join the network

**Who:** Marcus Okafor, CoC Administrator
**What:** Bulk import from the region's 211 database

Marcus receives a CSV export from NC 211 — three shelters that just agreed to participate in the coordinated entry system. He navigates to the Import 211 page, uploads the file, and the system maps the columns automatically. Agency name becomes shelter name. Street address, city, state, ZIP, phone — all matched without manual mapping.

He reviews the preview, confirms the import, and three new shelters appear in the Shelters tab. What used to take an afternoon of phone calls and manual data entry is done in seconds.

**Why this matters:** Until these shelters are in the system, outreach workers like Darius can't find them. Families searching for beds at midnight won't see them. Every minute of onboarding friction is a minute someone might not find safety.

*Screenshots: Import 211 page with file selected → Column mapping preview → Import success (3 created)*

---

## Act 2: Correct — Sandra will need this number tonight

**Who:** Marcus Okafor, CoC Administrator
**What:** Fix a phone number that came through wrong in the import

The import brought in Sunrise Family Center with phone number 919-555-0000 — clearly a placeholder from the 211 database. Sandra Kim, the shelter coordinator, will need the correct number tonight when outreach workers call about incoming clients.

Marcus clicks Edit on Sunrise Family Center, updates the phone to the real number, and saves. Three taps. The correct number is now visible to every outreach worker in the system.

**Why this matters:** A wrong phone number doesn't just inconvenience someone — it breaks the chain of trust. If Darius calls a dead number at midnight with a family in the car, he loses confidence in the entire platform. Data quality is care quality.

*Screenshots: Admin Shelters tab with Edit link → Edit form with phone field → Save confirmation*

---

## Act 3: Protect — Safety isn't a setting, it's a commitment

**Who:** CoC Administrator (dvAccess required)
**What:** Enable DV safeguards on Safe Passage House

Safe Passage House in Durham serves domestic violence survivors. The 211 import brought it in as a regular shelter — addresses visible, no special protections. That needs to change before anyone searches.

The administrator opens the edit form and enables the DV Shelter toggle. The change is immediate: the address disappears from public view. Only users with explicit DV authorization can see where this shelter is. The system logs the change — who enabled it, when, and what the previous state was.

If someone tries to turn DV protection off, the system requires explicit confirmation: *"This will make the shelter address visible to all users including outreach workers without DV authorization."* Removing protection is never an accident.

**Why this matters:** A survivor's safety depends on their shelter's address being invisible. This isn't a feature checkbox — it's a promise. The confirmation dialog, the audit log, the role restriction — they exist because the cost of getting this wrong is measured in lives, not error codes.

*Screenshots: Edit form with DV toggle → Confirmation dialog (for off→on this doesn't appear, but the true→false path shows it) → Shelter showing DV protection active*

---

## The Coordinator's View

Sandra Kim sees a different edit form. She can update phone numbers, hours, and operational details — the things that change week to week. But shelter name, address, and the DV flag are read-only for her role. A tooltip explains: *"Contact your CoC administrator to change DV status."*

This isn't a limitation — it's protection. The fields that affect a shelter's identity and safety status require a different level of authority. Sandra has full control over the information she needs to keep current. The structural decisions stay with Marcus.

*Screenshot: Coordinator edit form with operational fields editable, structural fields grayed out*

---

## The Complete Story

| Step | Who | What | Time |
|------|-----|------|------|
| 1. Import | Marcus | Upload 211 CSV, confirm mapping, 3 shelters created | 30 seconds |
| 2. Correct | Marcus | Fix wrong phone number on Sunrise Family Center | 10 seconds |
| 3. Protect | Admin | Enable DV safeguards on Safe Passage House | 15 seconds |
| 4. Operate | Sandra | Update phone/hours from coordinator dashboard | Ongoing |

From CSV to operational in under a minute. Three shelters that families can now find. One shelter whose survivors are now protected. One phone number that will work when Sandra answers tonight.

---

*Reviewed through the lenses of Simone Okafor (story-first, technology-invisible), Keisha Thompson (dignity in every interaction), Riley Cho (what happens if this fails?), and Marcus Okafor (can I explain this in plain English?).*
