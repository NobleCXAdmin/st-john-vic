# St John Ambulance VIC — Salesforce Business Development & Event Services Demo

A complete end-to-end Salesforce solution demonstrating event health service enquiries, lead qualification, person account conversion, deterministic clinical risk assessment, resource requirements planning, commercial quoting, formal acceptance governance, Closed Won eligibility, and staff-operated operational handoff to Rosterfy.

Built for **NobleCX** | Version 1.0 | November 2026  
Target Org: `St John VIC Demo Org` (`00DgK00000fYpDNUA0`)

---

## Key Features & Architecture

1. **Public & Assisted Event Booking Wizard (`sjvEventEnquiryWizard`)**
   - Accessible 7-step guided intake form for Experience Cloud or internal assisted entry.
   - Captures organiser details, event demographics, multi-day scheduling, venue logistics, and clinical hazard questions.
   - Features the mandatory regulatory notice: *"Illustrative demo rules, not approved for operational use"*.

2. **Lead Conversion & Event Hierarchy (`SJV_LeadConversionService`, `sjvLeadConversionAction`)**
   - Standard Lead conversion tailored for Person Accounts default org configuration.
   - Creates the linked Event Opportunity and native Salesforce Volunteer Management hierarchy (`VolunteerInitiative` parent booking + operational child days).

3. **Deterministic Clinical Risk Assessment Engine (`SJV_RiskAssessmentService`, `sjvRiskAssessmentWidget`)**
   - Deterministic rule scoring across crowd attendance, venue environment, alcohol licensing, and high-risk activities.
   - Automatic version control (`Version 1`, `Version 2`) with immutable audit snapshots of questions and answers (`SJV_Risk_Answer__c`).
   - Resource requirements engine generating proposed staffing (First Aiders, Paramedics) and assets (Mobile Marquee Kit) with cost vs. selling rate separation.

4. **Operational Shift Demand Generation (`SJV_DemandAndQuoteService`)**
   - Idempotently maps approved requirements into native Salesforce `JobPosition` and `JobPositionShift` records using stable source keys (`SJV_Source_Job_Key__c`, `SJV_Source_Shift_Key__c`).

5. **Commercial Quoting & Formal Acceptance Governance (`SJV_QuoteAcceptanceService`, `sjvOpportunityCommercialWidget`)**
   - Generates standard Salesforce Quotes with cost vs selling price margin visibility.
   - Captures legally binding acceptance evidence records (`SJV_Quote_Acceptance__c`).
   - Enforces a 4-point server-side Closed Won gate:
     1. Formal Quote Acceptance
     2. Clinical Risk Review Approval
     3. Operations Feasibility Approval
     4. Finance Credit Clearance

6. **Closed Won Gate & Staff-Operated Rosterfy Transfer (`SJV_RosterfySubmissionService`, `sjvRosterfyHandoffWidget`)**
   - **Architectural Rule:** Opportunity Closed Won qualifies the event (`Ready`), but **never auto-sends** records to Rosterfy without explicit staff click.
   - Preview modal surfaces canonical JSON payload, Australia/Melbourne timezone, role keys, capacities, and draft publication mode (`Draft (Unpublished)`).
   - Idempotent API transfer service stamps remote IDs onto `VolunteerInitiative` and `JobPositionShift`.
   - Comprehensive error recovery: supports partial failure handling (AT16), safe retries, and post-acceptance revision updates with absorbed internal costs (AT19).

---

## Project Structure

```
├── St_John_VIC_Salesforce_Antigravity_Implementation_Plan.md
├── README.md
├── docs/
│   ├── org-discovery.md
│   └── demo-runbook.md
├── force-app/main/default/
│   ├── classes/
│   │   ├── SJV_EnquirySubmissionService.cls
│   │   ├── SJV_LeadConversionService.cls
│   │   ├── SJV_RiskAssessmentService.cls
│   │   ├── SJV_DemandAndQuoteService.cls
│   │   ├── SJV_QuoteAcceptanceService.cls
│   │   ├── SJV_RosterfySubmissionService.cls
│   │   ├── SJV_UIController.cls
│   │   └── SJV_ServicesTest.cls
│   ├── lwc/
│   │   ├── sjvEventEnquiryWizard/
│   │   ├── sjvLeadConversionAction/
│   │   ├── sjvRiskAssessmentWidget/
│   │   ├── sjvRosterfyHandoffWidget/
│   │   └── sjvOpportunityCommercialWidget/
│   ├── objects/
│   │   ├── SJV_Event_Enquiry__c/
│   │   ├── SJV_Risk_Assessment__c/
│   │   ├── SJV_Risk_Answer__c/
│   │   ├── SJV_Resource_Requirement__c/
│   │   ├── SJV_Quote_Acceptance__c/
│   │   ├── SJV_Integration_Request__c/
│   │   ├── SJV_Integration_Item__c/
│   │   ├── Lead/fields/
│   │   ├── Opportunity/fields/
│   │   ├── VolunteerInitiative/fields/
│   │   ├── JobPosition/fields/
│   │   ├── JobPositionShift/fields/
│   │   ├── Quote/fields/
│   │   └── QuoteLineItem/fields/
│   ├── tabs/
│   │   ├── SJV_Enquiry_Wizard.tab-meta.xml
│   │   ├── SJV_Event_Enquiry__c.tab-meta.xml
│   │   ├── SJV_Risk_Assessment__c.tab-meta.xml
│   │   ├── SJV_Quote_Acceptance__c.tab-meta.xml
│   │   └── SJV_Integration_Request__c.tab-meta.xml
│   ├── flexipages/
│   │   └── Volunteer_Initiative_Record_Page.flexipage-meta.xml
│   └── permissionsets/
│       └── SJV_St_John_Event_Services.permissionset-meta.xml
└── scripts/
    └── apex/
        ├── seedDemoData.apex
        └── resetDemoData.apex
```

---

## Quick Start & Demo Execution

### 1. Assign Permission Set
```bash
sf org assign permset --name SJV_St_John_Event_Services --target-org "St John VIC Demo Org"
```

### 2. Seed Pristine Demo Data
Creates the 2-day St Kilda Community Festival 2026 records ready for presentation:
```bash
sf apex run --file scripts/apex/seedDemoData.apex --target-org "St John VIC Demo Org"
```

### 3. Run Tests & Verify Code Coverage
```bash
sf apex test run --tests SJV_ServicesTest --target-org "St John VIC Demo Org" --code-coverage --result-format human
```
*Current test pass rate: **100%** with high coverage across all SJV Apex domain services.*

### 4. Reset Demo Data (AT25)
Deletes only synthetic demo records (`SJV-DEMO-%`) in under 3 seconds:
```bash
sf apex run --file scripts/apex/resetDemoData.apex --target-org "St John VIC Demo Org"
```

### 5. Follow the Presentation Runbook
See [`docs/demo-runbook.md`](docs/demo-runbook.md) for the complete 10-step presenter talk track and demonstration steps.
