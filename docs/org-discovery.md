# Org Discovery & Baseline Assessment

**Date:** 9 November 2026  
**Org ID:** `00DgK00000fYpDNUA0`  
**Org Alias:** `St John VIC Demo Org`  
**Edition:** Enterprise Edition (Salesforce Demo Org / SDO)  
**API Version:** 68.0  
**Admin User:** Ramtin Sohrabian (`ramtin@noblecx.com.au2026_11_9_8-56-21.demo`)

---

## 1. Volunteer Model Decision

### Discovery Findings
- **Newer Salesforce Volunteer Management Model:** **Present and Fully Active.**
  - Objects verified:
    - `VolunteerInitiative` (Prefix: `1RV`, API active, createable, updateable)
    - `JobPosition` (Prefix: `0yi`, API active, createable, updateable)
    - `JobPositionShift` (Prefix: `1Qy`, API active, createable, updateable)
    - `Position` (Prefix: `1A9`, API active, createable, updateable)
  - Permission Set Licenses available:
    - `VolunteerManagementPsl` (Total: 20, Used: 1, Available: 19)
    - `VolunteerAssistiveAIPsl` (Total: 20, Used: 1)
    - `VolunteerManagementDigitalAgentPsl` (Total: 20, Used: 0)
    - `VolunteerManagementGuestAccessPsl` (Total: 20, Used: 0)
    - `VolunteerManagementExperienceCloudPsl` (Total: 20, Used: 0)
- **Legacy Volunteers for Salesforce (V4S / `GW_Volunteers`):** **Not installed** (0 package licenses found).
- **Rosterfy Connector Package:** **Not installed.**

### Architectural Decision
In accordance with Section 3.2 of the implementation plan, we adopt the **Newer Salesforce Volunteer Management Model** as our native demand preparation structure:
1. `VolunteerInitiative`: Event / Day container linked to the Opportunity (`ParentVolunteerInitiative` for multi-day parent/child hierarchy).
2. `Position`: Role catalogue (First Aider, Registered Nurse, Advanced Paramedic, etc.).
3. `JobPosition`: Requirement demand for a specific initiative/day and position.
4. `JobPositionShift`: Scheduled operational shift slots with capacity, start/end date-times, and timezone.

---

## 2. Commercial & Core CRM Schema

- **Lead, Account, Contact, Opportunity:** Fully active standard CRM objects.
- **Product2, Pricebook2, PricebookEntry, OpportunityLineItem:** Available and standard.
- **Standard Quotes (`Quote`, `QuoteLineItem`):** Fully active, createable, updateable, and layoutable.

---

## 3. Experience Cloud (Digital Experiences)

- Digital Experiences is enabled.
- Active networks include:
  - `SDO - Consumer` (`/consumer`)
  - `SDO - Professional` (`/professional`)
  - `Volunteer Signup` (`/volunteersignup`)
  - `Donor Portal` (`/donors`)
- The public Enquiry Wizard Flow will be packaged and prepared for Experience Cloud embedding, while also being made directly accessible via an internal assisted-entry Lightning Page / Utility Item for BDM demo resilience.

---

## 4. Integration Scope Confirmation

- **Rosterfy Live Integration:** Per instruction, deferred to a later stage.
- **Immediate Architecture:** Stage 5/6 will provide the `Create in Rosterfy` action, validation service, idempotent request tracking (`SJV_Integration_Request__c`), and status display component, with client abstraction ready for the live HTTP endpoint once vendor credentials and write specifications are provided.

