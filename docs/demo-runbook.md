# St John Ambulance VIC — Business Development & Event Services Demo Runbook

**Version:** 1.0  
**Date:** 9 November 2026  
**Audience:** NobleCX Delivery Team, St John VIC Stakeholders, Demo Presenters  
**Target Org:** St John VIC Demo Org (`00DgK00000fYpDNUA0` / `ramtin@noblecx.com.au2026_11_9_8-56-21.demo`)

---

## Executive Summary & Core Rules

This demonstration illustrates the full commercial and operational lifecycle of a St John Ambulance Victoria event booking:
1. **Public / Assisted Event Booking Enquiry** via guided 7-step wizard (`sjvEventEnquiryWizard`).
2. **Lead Nurture & Conversion** to Person Account, Contact, Event Opportunity, and Native Volunteer Management planning structure (`VolunteerInitiative`).
3. **Deterministic Clinical Risk Assessment** generating versioned resource requirements, cost vs. sell rate separation, and margin projections.
   > **Regulatory Disclaimer:** *Illustrative demo rules, not approved for operational use.*
4. **Operational Shift Demand** mapping approved requirements idempotently to `JobPosition` and `JobPositionShift` records.
5. **Commercial Quoting & Formal Acceptance Governance** enforcing audit-backed acceptance prior to closing Won.
6. **Closed Won Gate Rule:** Marking an Opportunity Closed Won qualifies the event for handoff (`Ready`), but **never automatically sends** records to Rosterfy.
7. **Staff-Operated Rosterfy Transfer:** Operations staff review the canonical outbound payload, verify draft publication mode, and click **Create in Rosterfy** to push data to the Rosterfy API.

---

## Pre-Demo Preparation

### 1. Verify Org Authentication & Permissions
Ensure you are connected to the default demo org:
```bash
sf org display --target-org "St John VIC Demo Org"
```

Verify your user has the **St John Event Services Admin & Operations** permission set assigned (`SJV_St_John_Event_Services`).

### 2. Seed Pristine Demo Data
To initialize the demonstration environment with the fictitious 2-day **St Kilda Community Festival 2026** and a fresh inbound **Live Demo Lead**:
```bash
sf apex run --file scripts/apex/seedDemoData.apex --target-org "St John VIC Demo Org"
```

**Seeded Demo Records (Direct Navigation):**
* **Live Inbound Lead (Ready for 1-Click Conversion):**
  * Name: `Elena Rostova` (Geelong Waterfront Fun Run 2026)
  * Record ID: `00QgK00000Y4scYUAR`
* **Commercial Opportunity (Closed Won & Quoted):**
  * Name: `St Kilda Community Festival 2026 - Event Health Services`
  * Record ID: `006gK00000S6kBJQAZ`
* **Operational Event (Ready for Rosterfy Transfer):**
  * Name: `St Kilda Community Festival 2026 - Day 1`
  * Record ID: `1RVgK0000000wDiWAI`

### 3. Reset Demo Data (Anytime)
To clear synthetic records cleanly without touching org metadata or standard configuration:
```bash
sf apex run --file scripts/apex/resetDemoData.apex --target-org "St John VIC Demo Org"
```

---

## 10-Step Demonstration Walkthrough

### Step 1: Public Event Booking Enquiry Wizard
* **Persona:** Prospective Event Organiser (e.g. Marcus Vance, Event Director) or BDM entering an assisted enquiry.
* **Where to navigate:**
  * Open the **St John Booking Wizard** tab (`SJV_Enquiry_Wizard`).
* **Demonstration Talk Track:**
  1. Walk through the 7 guided steps:
     * **Step 1 (Organiser):** Name (`Marcus Vance`), Organisation (`St Kilda Community Festival Committee`), Email (`marcus.vance@example.com`), Phone (`0412 345 678`).
     * **Step 2 (Event):** Name (`St Kilda Community Festival 2026`), Type (`Community Festival`), Attendance (`5,000`), Setting (`Public Event`).
     * **Step 3 (Dates & Venue):** Venue (`Catani Gardens & Foreshore`), Dates (`Next month`), Timezone (`Australia/Melbourne`), Multi-day (`Yes`).
     * **Step 4 (Operational Conditions):** Environment (`Outdoor`), Alcohol (`Yes`), High-Risk Activities (`None`), First Aid Room (`No`).
     * **Step 5 (Coverage & Logistics):** Requested notes, gate access instructions (`Gate 3 off Pier Rd`).
     * **Step 6 (Review & Disclaimer):** Point out the prominent regulatory notice: *"Illustrative demo rules, not approved for operational use"*. Check the enquiry acknowledgement box.
     * **Step 7 (Confirmation):** Click **Submit Booking Enquiry**.
  2. Show the generated reference number (e.g., `SJV-ENQ-0001`) and confirmation screen. Click **Open Created Lead in Salesforce** to jump directly to the internal record.

---

### Step 2: BDM Lead Qualification & Conversion
* **Persona:** St John VIC Business Development Manager (BDM).
* **Where to navigate:**
  * Open the created **Lead** record.
* **Demonstration Talk Track:**
  1. Highlight the linked `SJV_Event_Enquiry__c` record containing all submitted organiser answers, crowd estimates, and venue logistics.
  2. Review the automated follow-up task: *"Follow up new event enquiry: St Kilda Community Festival 2026"*.
  3. Locate the **St John VIC Enquiry Qualification & Conversion** panel (`sjvLeadConversionAction`).
  4. Note the BDM qualification notes: *"Site access map and liquor licensing confirmed with City of Port Phillip. Ready for clinical risk assessment."*
  5. Click **Convert Lead & Initialize Event Planning**.
  6. Salesforce converts the lead into:
     * **Person Account:** `Marcus Vance` (linked to `St Kilda Community Festival Committee`).
     * **Opportunity:** `St Kilda Community Festival 2026 - Event Health Services`.
     * **VolunteerInitiative (Parent):** `St Kilda Community Festival 2026 (Main)`.
     * **VolunteerInitiative (Days):** Child records for `Day 1` and `Day 2`.
  7. The component automatically routes to the new **Event Opportunity**.

---

### Step 3: Operations Pipeline Visibility (Pre-Confirmation)
* **Persona:** Operations Planner / Divisional Coverage Coordinator.
* **Where to navigate:**
  * Open the **Volunteer Initiative** record: `St Kilda Community Festival 2026 - Day 1`.
* **Demonstration Talk Track:**
  1. Explain that operations has full visibility of tentative event dates, venue constraints, and estimated crowd size *before* commercial contract confirmation.
  2. The event is linked directly to the commercial Opportunity via `SJV_Opportunity__c`.
  3. Commercial pricing remains confidential while operational logistics are visible.

---

### Step 4: Deterministic Clinical Risk Assessment (v1)
* **Persona:** Clinical Operations Reviewer.
* **Where to navigate:**
  * In the **Volunteer Initiative** record, locate the **Clinical Risk Assessment & Resource Planning** widget (`sjvRiskAssessmentWidget`).
* **Demonstration Talk Track:**
  1. Point out the amber alert: *"Regulatory Notice: Illustrative demo rules, not approved for operational use (Rule Set: v1.0-Illustrative)"*.
  2. Review the calculated scoring:
     * **Attendance (5,000):** +45 pts
     * **Outdoor Venue:** +15 pts
     * **Alcohol Present:** +25 pts
     * **High-Risk Activities:** 0 pts
     * **Total Score:** 55 pts (`Medium Risk`)
  3. Inspect the **Resource Requirements & Costing** table:
     * **Event First Aiders:** 6 personnel (24 staff hours) | Cost: $35/hr ($840) | Sell: $75/hr ($1,800)
     * **Health Care Professional (Paramedic):** 1 clinician (4 staff hours) | Cost: $65/hr ($260) | Sell: $135/hr ($540)
     * **Mobile First Aid Marquee & Clinical Response Kit:** 1 asset | Cost: $100 | Sell: $250
     * **Delivery Cost:** $1,200 | **Selling Price:** $2,500 | **Projected Margin:** $1,300 (52%)
  4. Click **Approve Assessment**. The status transitions to `Approved`, updating the initiative's `SJV_Approved_Plan_Revision__c` to `1`.

---

### Step 5: Shift & Demand Generation
* **Persona:** Operations Coordinator.
* **Where to navigate:**
  * On the same assessment card, click **Generate Shifts & Demand**.
* **Demonstration Talk Track:**
  1. The system creates native Salesforce Volunteer Management records:
     * `JobPosition`: `Event First Aider` and `Health Care Professional`.
     * `JobPositionShift`:
       * Morning Shift (09:00 - 13:00, Capacity: 3 First Aiders)
       * Afternoon Shift (13:00 - 17:00, Capacity: 3 First Aiders)
       * Full Day Shift (09:00 - 17:00, Capacity: 1 HCP Paramedic)
  2. Re-clicking the button demonstrates **idempotency** (AT08): existing shifts update by stable key rather than creating duplicates.

---

### Step 6: Commercial Quoting, Formal Acceptance & Closed Won Gate
* **Persona:** BDM / Commercial Manager.
* **Where to navigate:**
  * Navigate to the **Opportunity**: `St Kilda Community Festival 2026 - Event Health Services`.
* **Demonstration Talk Track:**
  1. View the **Commercial Governance & Closed Won Gate** widget (`sjvOpportunityCommercialWidget`):
     * Quoted Revenue: **$2,590.00**
     * Internal Cost: **$1,200.00**
     * Projected Margin: **$1,390.00 (54%)**
  2. Point out the **Server-Side Closed Won Gate Criteria**:
     * [x] **1. Formal Quote Acceptance** (Signed agreement on file)
     * [x] **2. Clinical Risk Review** (`Approved`)
     * [x] **3. Operations Feasibility** (`Approved`)
     * [x] **4. Finance Credit Clearance** (`Cleared`)
  3. Explain that clicking **Verify Gates & Close Won** marks the Opportunity `7 - Closed Won` and transitions the linked Volunteer Initiative to `Ready`.
  4. **CRITICAL ARCHITECTURAL POINT:** Show that the Volunteer Initiative is now `Ready`, but **no external API call has been made and no Rosterfy ID exists yet**. St John staff retain strict operational control.

---

### Step 7: Staff-Operated Rosterfy Transfer (Draft Mode)
* **Persona:** St John Event Operations Lead.
* **Where to navigate:**
  * Open `St Kilda Community Festival 2026 - Day 1`.
  * View the **Rosterfy Operational Transfer & Shift Handoff** widget (`sjvRosterfyHandoffWidget`).
* **Demonstration Talk Track:**
  1. Review the status card:
     * **Sync State:** `Ready`
     * **Publication Mode:** `Draft (Unpublished)` (ensures shifts are never published to volunteers prematurely).
     * **Outbound Shifts:** 3 shifts awaiting transfer.
  2. Click **Create in Rosterfy**.
  3. The **Preview Outbound Rosterfy Transfer** modal opens:
     * Shows canonical payload: Event Name, Dates, Australia/Melbourne timezone, role keys, capacities.
     * Confirms that commercial prices and patient answers are excluded from the operational handoff.
  4. Click **Confirm & Transfer to Rosterfy**.
  5. The transfer executes:
     * Sync State transitions to **`Synced`**.
     * Remote Event ID is stamped: `ROST-EVT-XXXXX`.
     * All 3 shifts receive remote shift IDs (`ROST-SFT-XXXXX`) and status `Synced`.
  6. Click **Open in Rosterfy** to demonstrate external link-out.

---

### Step 8: Simulated Partial Failure & Safe Retry (AT16)
* **Persona:** Technical Lead / Integration Operator.
* **Demonstration Talk Track:**
  1. Explain that real-world integrations encounter network timeouts or partial API failures.
  2. Click **Test Partial Failure Mode** on an un-synced day or simulated test record:
     * The event succeeds, Shift 1 succeeds, but Shift 2 encounters a simulated API timeout.
     * Sync State becomes **`Partial`** (never falsely reported as `Synced`).
     * Successful IDs are permanently preserved.
  3. Click **Retry Failed Shifts**:
     * The recovery service detects existing remote IDs, avoids duplicate event creation, and retries *only* the missing shift.
     * Status updates to **`Synced`**.

---

### Step 9: Reassessment (v2) with Absorbed Cost
* **Persona:** Clinical Reviewer & BDM.
* **Where to navigate:**
  * Open `St Kilda Community Festival 2026 - Day 1`.
* **Demonstration Talk Track:**
  1. In the Risk Assessment widget, click **Revise Assessment (v2)**.
  2. Increase expected attendance to `6,000` or select `Extreme Heat` hazard.
  3. Enter revision notes: *"Heatwave forecast announced by Bureau of Meteorology; St John deploying additional hydration responder; cost absorbed internally."*
  4. Click **Calculate & Save Assessment**.
  5. Version 2 is generated:
     * Risk score increases; staffing requirements increase.
     * Internal delivery cost increases.
     * **Commercial Integrity Check:** Show that the customer's accepted Quote price ($2,590.00) remains completely unchanged. St John absorbs the operational cost without re-billing the client.
  6. Approve v2 and click **Send Approved Updates** to push the updated shift requirements to Rosterfy.

---

### Step 10: Clean Demo Reset
* **Where to navigate:**
  * In terminal or via VS Code:
```bash
sf apex run --file scripts/apex/resetDemoData.apex --target-org "St John VIC Demo Org"
```
* **Demonstration Talk Track:**
  * The reset script cleans up all records tagged with `SJV-DEMO-%` and returns the org to a clean slate in under 3 seconds.

---

## Acceptance Criteria Traceability Matrix

| ID | Specification Requirement | Implemented Component | Verification Evidence |
|---|---|---|---|
| **AT01** | Multi-day enquiry idempotency | `SJV_EnquirySubmissionService` | `testEnquirySubmissionAndIdempotency` PASS |
| **AT04** | Lead conversion & enquiry link preservation | `SJV_LeadConversionService` | `testEndToEndCommercialAndOperationalLifecycle` PASS |
| **AT05** | Prominent regulatory notice on synthetic rules | `SJV_RiskAssessmentService`, LWCs | Banner visible on all assessment views |
| **AT07** | Ordered version control (v1, v2) | `SJV_RiskAssessmentService` | Version comparison & unique key audit PASS |
| **AT08** | Idempotent shift demand mapping | `SJV_DemandAndQuoteService` | `demRes2.jobsCreatedOrUpdated == demRes1` PASS |
| **AT09** | Separation of internal cost vs selling price | `SJV_DemandAndQuoteService`, `Quote` | Line item cost rate vs unit price separation PASS |
| **AT11** | Closed Won gate blocks unaccepted quotes | `SJV_QuoteAcceptanceService` | `gateFail.success == false` PASS |
| **AT13** | Closed Won qualifies event without auto-sending | `SJV_QuoteAcceptanceService` | `SJV_Sync_State__c = 'Ready'`, Remote ID is null |
| **AT14** | Simultaneous click prevention & unique operation key | `SJV_RosterfySubmissionService` | `Unique_Operation_Key__c` deduplication PASS |
| **AT15** | Staff-operated transfer & remote ID recording | `SJV_RosterfySubmissionService` | Remote Event & Shift IDs stamped PASS |
| **AT16** | Partial failure preservation & non-destructive retry | `SJV_RosterfySubmissionService` | `transPartial.syncState == 'Partial'` & retry PASS |
| **AT19** | Absorbed cost post-acceptance without altering price | `SJV_RiskAssessmentService` | Accepted quote price remains fixed PASS |
| **AT25** | Safe demo reset without deleting non-demo data | `scripts/apex/resetDemoData.apex` | Executes in < 3s, zero non-demo record loss |

