# St John VIC: Salesforce business development demo

## Implementation plan for Antigravity

Version 1.0 | 9 November 2026 | Prepared for NobleCX

**Build objective:** demonstrate an event enquiry moving from an Experience Cloud form through lead follow-up, conversion, risk assessment, resource planning, costing, quoting and customer acceptance. A staff member then clicks **Create in Rosterfy** on the Salesforce event record to create the approved event and shifts through the Rosterfy API.

This is a development specification for a working demonstration, not evidence that a Salesforce org or Rosterfy connection has already been configured. It reflects the latest instruction to use a staff-operated button. Closing an Opportunity as Won makes the event eligible for transfer; it must not itself send the event to Rosterfy.

## 1. Instructions to Antigravity

Implement this as a Salesforce DX project in the authorised development org. Inspect the existing repository, org metadata, packages, licences and automation before creating anything. Reuse suitable existing components and record types. Do not assume a fresh org or overwrite existing business configuration.

Work in the ordered stages in section 13. Use Screen Flows for guided work, record-triggered/scheduled Flows for routine automation, and Apex for secure submission, version control, calculations that need atomic processing, and reliable asynchronous API integration. Use small Lightning Web Components only where standard Flow components do not provide the required interaction.

The core demo must include the real Salesforce records, saved risk versions, generated quote PDF, acceptance evidence, event/jobs/shifts, button and integration status. Use a labelled simulation for unavailable external services while developing. A simulated API response is not completion of the live Rosterfy requirement. Keep the remaining work explicit until the live test succeeds.

Before implementing a dependency, verify it. Do not invent Rosterfy endpoint paths, authentication details, request field names, status values or responses. Do not assume that Salesforce's volunteer objects exist in this org. Do not install another volunteer package or change the target object model silently.

Deliver metadata, Apex and LWC source where needed, tests, synthetic demo data, setup instructions, a reset script, a short demo runbook and a list of unresolved dependencies. Keep credentials outside source control. Build against the API version supported by the target org; the newer volunteer objects require API 64.0 or later.

## 2. Confirmed direction and important additions from the workshops

| Requirement | Implementation decision |
|---|---|
| Public enquiry becomes a Lead | A guided Experience Cloud Screen Flow collects contact and event details. Internal staff can use an equivalent assisted-entry flow. |
| Nurture and convert | Assigned owner, follow-up tasks, activity history, qualification and conversion to Account, Contact and Opportunity. |
| Risk assessment drives requirements | A versioned assessment produces proposed staffing/equipment requirements using an approved rule set, with human review where required. |
| Requirements drive costing and quotes | Keep internal cost separate from the price charged to the customer. Use Products, Price Books, Opportunity Products and standard Quotes where enabled. |
| Customer acceptance precedes Won | Capture acceptance of a specific quote version, then enforce the required internal checks before Closed Won. |
| Staff control the Rosterfy handoff | Create in Rosterfy opens a preview and queues an API request after server-side checks. Do not call automatically on Closed Won. |
| Salesforce volunteer jobs | Use the available Salesforce volunteer model to prepare jobs and shifts. Rosterfy remains responsible for applications, allocation, attendance and operational rostering. |
| Several assessments for an event | Keep an initial quoting assessment and later revisions, including per-day assessments for multi-day events. Never overwrite earlier approved answers, scores, requirements or approvals. |
| Pipeline visibility before confirmation | Operations needs a view of proposed dates, roles, quantities and equipment before acceptance. Provide this in Salesforce for authorised users. Publishing to Rosterfy remains a separate action. |
| Late changes may not change price | A revised risk assessment can increase internal cost while the accepted customer price stays fixed. A chargeable change requires explicit commercial approval and customer acceptance. |
| Clinical and operations review | Higher-risk events need review by the relevant teams before quoting. Exact score thresholds and approvers require St John confirmation. |
| Tasks and reminders | Include Sarah's examples: ask a division about coverage, follow up a quote, assign an owner and due date, and show overdue work on a dashboard. |
| Repeat events and venue requirements | Copy a previous event as a starting point, but ask staff to confirm current details and perform a fresh assessment. Bring across applicable parking, induction, access and contract instructions. |
| Customer warnings | Show an account credit warning and relevant account notes internally. A demo flag can illustrate this; do not claim a live SAP debtor feed. |
| Reporting and follow-up | Show enquiry pipeline, review delays, quotes awaiting response, expected cost/margin, upcoming demand and failed transfers. Add post-event feedback and next-year follow-up tasks. |

Workshop evidence is listed in section 17. References to regulatory obligations in the transcripts are client statements; this plan does not independently validate those obligations.

## 3. Salesforce volunteer object investigation and decision

### 3.1 Two distinct Salesforce models

| Purpose | Newer Salesforce Volunteer Management | Older Volunteers for Salesforce package |
|---|---|---|
| Event/programme container | `VolunteerInitiative` | `Campaign` |
| Role/job needed for the event | `JobPosition`, associated with a `Position` | Volunteer Job, including `GW_Volunteers__Volunteer_Job__c` |
| Dated work slot and capacity | `JobPositionShift` | Volunteer Shift |
| A person allocated to a shift | `JobPositionAssignment` | Volunteer Hours records also represent participation/status |
| Qualifications and availability | Related objects include `JobPositionQualification`, `PositionQualification` and `PersonLocationAvailability` | Package fields, recurrence schedules and related configuration; inspect the installed version |
| Availability in the org | Feature and licence dependent. Object documentation specifies `VolunteerManagementPsl` and Manage Volunteer Data permissions. | Managed package must be installed. It is not the same schema as the newer model. |

Salesforce documentation describes the newer initiative, job and shift objects as createable and updateable. That makes them suitable candidates for preparing demand in Salesforce, subject to the actual org permissions. It does not prove Rosterfy can consume them without a custom mapping.

The older package requires Volunteer Jobs to sit under a Campaign. Inspect its actual object and field API names instead of translating labels from the newer model. These two models are alternatives, not interchangeable tables.

### 3.2 Recommended decision

**Prefer the newer Volunteer Management objects if the authorised demo org already has the feature, required licences and access.** For an existing V4S org, use its Campaign/Job/Shift model rather than introduce a second volunteer model just for this demo. If neither is available, report the provisioning dependency. A custom event/job/shift prototype is a separately labelled fallback and is not proof of native Volunteer Management.

The rest of this specification uses the newer model as its reference design. The V4S alternative maps the same behaviours onto its installed objects. Implement only the selected model, not both adapters by default.

### 3.3 Mandatory org discovery output

Create `docs/org-discovery.md` recording:

- Salesforce edition, enabled clouds, Experience Cloud availability and site template/runtime.
- Installed packages, including any V4S/NPSP package and any existing Rosterfy connector.
- Describe results for Lead, Account, Contact, Opportunity, Product2, Pricebook2, PricebookEntry, OpportunityLineItem, Quote and QuoteLineItem.
- Describe results, required fields, writable fields, permitted custom fields and relationships for the selected initiative/job/shift model, including `Position` where required.
- Access to Volunteer Management permission set licences and the permissions needed by BDM and operations users. API object lists alone do not establish entitlement.
- Existing lead-conversion rules, duplicate rules, validation rules, quote automation, customer account model and sharing settings.
- Whether the sandbox can reach the approved Rosterfy test tenant through its API. Public Rosterfy pages disagree on availability of the packaged connector in Salesforce sandboxes; confirm the tenant-specific position. This is distinct from validating a custom API callout.

**Decision output:** selected model, exact object/field mapping, relevant permissions, gaps, and any additional licences needed. Do this before generating schema-dependent Apex.

## 4. Ownership and end-to-end process

Salesforce owns the commercial enquiry, customer relationship, Opportunity, assessment versions, proposed resource requirements, cost estimates, quotes and customer acceptance. Rosterfy owns volunteer recruitment/application, operational eligibility checks, individual allocations, attendance and actual volunteer hours. This demo establishes demand, not a second allocation engine.

1. Customer completes the public enquiry wizard.
2. Salesforce creates a Lead and a linked event enquiry, assigns a BDM owner and creates a follow-up task.
3. BDM qualifies the enquiry and requests missing details. Existing customers are matched internally without exposing records on the public site.
4. Convert to an Account, Contact and Opportunity. Create the Salesforce event container and its day/job/shift planning structure.
5. Complete an initial risk assessment for each relevant event day. Calculate proposed requirements and submit for the necessary review.
6. Review internal costs, selling prices and resource feasibility. Build and send the quote linked to the approved assessment set.
7. Record the customer's acceptance of that exact quote. Close Won after the required internal checks.
8. On the event record, click **Create in Rosterfy**. Preview the target event(s), shifts, role requirements and publication setting. Confirm.
9. Queue the API work, create each event and its shifts, and store remote IDs. Show success only after required remote records are verified.
10. If conditions change, create and approve a new risk assessment version. Determine whether the change is absorbed internally or needs a new customer quote. Use **Send Approved Updates** for an existing remote event; never create it again.

For a multi-day booking, use a parent `VolunteerInitiative` linked to the Opportunity, with child initiatives for operational days through `ParentVolunteerInitiative`. Each operational day is the transfer unit and carries its own assessments and jobs/shifts. A single-day booking can use one initiative as both booking and transfer unit. This is a proposed mapping based on the workshop's daily-event discussion and must be confirmed with operations and Rosterfy.

The Salesforce calendar `Event` activity object is not the operational event container. Use it for meetings only. Do not duplicate the operational event into an activity record merely because both use the word event.

## 5. Data model and fields

All `SJV_` names below are proposed custom components. Confirm collisions and supported relationships against the target org. Create only the fields needed for the selected model.

| Record | Core fields/relationships and behaviour |
|---|---|
| Lead | Standard contact/company fields, source, owner and status; enquiry reference and permission to contact about the enquiry. Separate optional marketing consent. |
| `SJV_Event_Enquiry__c` | Submission key: Text, Unique External ID; Lead/Account/Contact/Opportunity links as available; event name/type; venue/address; timezone; initial dates; attendance estimate; structured enquiry answers; missing-information status; submitted timestamp. Preserve after lead conversion. |
| Account/Contact | Customer and billing contacts, event-day contact; internal credit-review flag, review date, reason and owner. Do not infer verified financial data from an Opportunity stage. |
| Opportunity | Event container link; review stage; approved assessment-set reference/hash; accepted Quote; estimated internal cost, quoted revenue, margin; credit/resource approval status; handoff readiness. Standard Amount represents sales value, not delivery cost. |
| Volunteer Initiative / selected event container | Commercial Opportunity link; parent/day relationship; event date/timezone; operational contact; venue instructions; lifecycle status; current approved assessment; approved plan revision; risk review required flag; remote event ID; sync state; last sent revision/time; last checked time; remote link. |
| `SJV_Risk_Assessment__c` | Event/day link; unique EventDay+Version key; version number; previous version; status; reason for change; questionnaire/rule-set version; answers snapshot; score/band; reviewer decision, reviewer/time; input/output hashes; approval-set reference; printable assessment file reference. |
| `SJV_Risk_Answer__c` | Assessment parent; stable question key; exact question text/version; typed answer or normalised answer JSON; scoring contribution and explanation. Required for answer-level comparison/reporting. |
| `SJV_Resource_Requirement__c` | Assessment parent; stable requirement key; category Staff/Vehicle/Equipment/Other; role/skill mapping key; quantity; service date/start/end/timezone; paid/volunteer demand distinction; internal cost rate, selling rate, billable units and basis; rule/manual origin; override reason/approver. Approved rows are immutable snapshots. |
| Position / Job Position | Reuse approved role catalogue where possible. Job belongs to the relevant initiative/day; role code, description and mapped Rosterfy role/eligibility configuration. Job represents demand, not a named person. |
| Job Position Shift | Job relationship; start/end date and time, timezone and capacity using verified native fields; source requirement key; plan revision; remote event/shift mapping and last sent revision. Do not rely on an autonumber or name as the integration key. |
| Standard Quote / QuoteLineItem | Quote revision, Opportunity, Price Book, explicit event/day assessment-set snapshot, pricing snapshot, valid-until date, customer-visible terms, PDF version and acceptance status. Each line retains the source requirement key and day for traceability. |
| `SJV_Quote_Acceptance__c` | Quote/version, customer Contact, received date/time, method, evidence file/message reference, recorded-by user; price and terms snapshot/hash. A stored Quote status by itself is not sufficient acceptance evidence. |
| Task / activity history | Owner, due date, status and related Lead/Opportunity/event. Tasks for missing information, division coverage, clinical review, quote follow-up, overdue action and next-year contact. Enable activities on a custom object if needed. |
| `SJV_Integration_Request__c` | Unique operation key; source event/day; operation Create/Update/Cancel; approved revision and payload hash; environment; state; attempt count; next attempt; correlation ID; requesting user; sanitised error; request snapshot. |
| `SJV_Integration_Item__c` | Request parent; event or shift source key; remote ID; item status; response code; attempt timestamp; recovery status. Preserve partial success across retries. |

Use custom metadata for rule-set definitions, role mappings, endpoint capability settings and field mappings, with a controlled publication process. Keep business-editable price lists in Price Books or a versioned rate table. Do not put secrets in custom metadata.

Risk requirements remain historical snapshots; job/shift planning records represent the latest approved operational plan. Applying an approved version updates that plan by stable source key, rather than creating another copy of every job on every calculation.

Do not equate number of roster positions with billable hours. For example, two positions for four hours create eight staff-hours of demand but may have different internal cost and selling rates. Equipment can be charged per event or per day instead of per hour.

## 6. Experience Cloud enquiry wizard

### Intended experience

Create an accessible, mobile-friendly, multi-step Screen Flow embedded in an Experience Cloud page. It should feel like a guided event booking enquiry: clear progress, short explanations, conditional questions, review before submission and an acknowledgement reference. Avoid presenting an internal risk-scoring form to the public.

| Step | Capture and behaviour |
|---|---|
| 1. About the organiser | Name, organisation, email, phone, role and whether they have used St John before. No public Account/Contact search results. |
| 2. About the event | Name, type, description, expected attendance, public/private setting and whether details are provisional. |
| 3. Dates and location | Venue/address, event dates, operating hours and timezone. Support multiple days and different daily times. Use a bounded repeater or small LWC if necessary. |
| 4. Event conditions | Conditional organiser questions needed for assessment, such as indoor/outdoor setting, first aid facilities and relevant activities. Mark unknown answers explicitly rather than silently treating them as low risk. The final question set comes from the approved St John form. |
| 5. Service and access details | Requested coverage, setup/access arrangements, event-day contact and additional instructions. Customer requests are inputs, not approved staffing decisions. |
| 6. Review and submit | Editable summary, clear enquiry disclaimer, privacy acknowledgement and separate optional marketing choice. No automated clinical recommendation or binding instant quote. |
| 7. Confirmation | Human-readable reference, acknowledgement and next steps. A reference must not provide unauthenticated access to internal records. |

Repeat-event reuse is an internal authenticated action for the first demo. Do not let a guest retrieve previous event details simply by providing an email address or Salesforce ID. Public draft resume is deferred; if added later it needs a separately reviewed, expiring access mechanism. Do not persist contact details in browser local storage by default.

### Secure submission contract

- The public flow runs with minimal access and receives no internal record IDs from customer input.
- Prefer a create-only `SJV_Event_Enquiry__c` boundary. A narrowly scoped submission service validates allowed fields, formats, lengths, dates and maximum day count, then creates the enquiry. Trusted internal automation creates the linked Lead and assigns ownership.
- Where elevated execution is necessary, isolate it to the submission operation. Do not grant broad system-context read/update access or make internal Lead/Opportunity records public.
- Never accept owner IDs, cost rates, approval flags, risk scores, account IDs or integration configuration from the browser. Recompute and validate on the server.
- A random submission key handles double clicks and repeat network submissions. The same key returns a generic acknowledgement without exposing an existing record. Rate limiting/bot protection must be chosen and tested for the deployed site; CAPTCHA must not be a client-only checkbox.
- No public file upload in the initial demo. If required, design a separate restricted upload path with file type/size limits and no public document access.
- Enable only the intended flow, Apex entry points and required create permissions for the guest profile. Disable guest Flow pause. Test anonymous access in a separate browser session.
- Use verified sender configuration and a test mailbox for acknowledgement emails. Quote delivery failure must be visible and must not be treated as delivery or acceptance.

## 7. Lead nurture, conversion and pipeline visibility

Use proposed Lead statuses New, Contacting, Awaiting Information, Qualified and Disqualified, mapped to the org's existing values. Use proposed Opportunity stages Discovery, Assessment in Progress, Internal Review, Quote Preparation, Quote Sent, Negotiation, Closed Won and Closed Lost. Do not replace existing stages without reviewing their dependencies.

Create a BDM workspace with a guided next-action panel, event summary, missing-information list, upcoming deadlines, internal warnings, tasks and activity history. Nurture in this demo means owner-led follow-up, approved email templates and task reminders; it does not assume Marketing Cloud or automated marketing journeys are licensed.

Use standard lead conversion, with an Apex conversion action only if the guided process requires it. Existing Account/Contact matching happens internally with duplicate rules and a review path for ambiguous matches. Preserve the enquiry and its dates/answers, transfer links to the new Opportunity and create the event container once. Lead conversion is not event confirmation.

Give authorised clinical, operations and divisional staff a pipeline report/calendar showing tentative date, venue, expected roles, quantities, equipment and confidence/status before the event is won. Do not expose customer pricing to every operational user. Salesforce access/licensing for these users is an explicit decision. If they need visibility solely inside Rosterfy, that requires a separately approved draft-event API pattern; it is not part of the confirmed-event-only handoff by default.

Show a repeat-booking action that copies logistics and contact context, then creates a new enquiry/Opportunity and a new assessment. Do not copy old approval or acceptance statuses. Include a record of which previous event was used.

## 8. Risk management, versions and review

### Version behaviour

Use Draft, Submitted, Approved, Rejected and Superseded as the conceptual lifecycle. Map to the implemented status fields. Drafts may be edited. Once submitted, answers and calculated outputs cannot be edited in place; return for changes by cloning a new draft version. Approving a new version supersedes the previous approved version but retains its contents and decision history.

Store answers, question labels, scoring rules/version, score, band, requirements, costs, reviewer, date/time and reasons. Field History Tracking is supplementary; it does not replace saved assessment versions. Published rule sets are immutable: deploy a new version rather than editing the rule definition used by existing records.

Provide **New Assessment**, **Revise Assessment**, **Compare Versions**, **Submit for Review** and **View Assessment PDF** actions. Comparison shows changed answers, score/band, staff/equipment quantities, internal cost and whether the agreed selling price changes. Number versions server-side using a locked parent counter or equivalent atomic strategy and a unique EventDay+Version key.

Maintain distinct pointers to the assessment set used for the accepted quote and the latest approved operational assessment set. A weather-related revision must not rewrite the accepted quote's historical basis. For a multi-day event, the quote snapshot contains the assessment IDs/versions for all covered days, not just one lookup to the latest version.

### Calculation and approval

Separate three steps: assessment scoring, resource requirements and commercial pricing. Use deterministic rules with explanations, not AI-generated clinical advice. Missing answers stop finalisation. A human reviewer can override proposed resources only with a reason and the required approval; do not silently reduce approved clinical requirements to improve margin.

The actual SJC questionnaire, scoring weights, thresholds, minimum staffing rules, medical-plan requirements and escalation matrix were not supplied in the reviewed material. Build the rule engine and schema, but request these inputs before claiming faithful St John scoring. Synthetic demo rules must be clearly labelled **Illustrative demo rules, not approved for operational use** on internal assessment screens and exports.

Higher-risk review creates assigned tasks/notifications for clinical and operations staff and records each decision. Choose the org-supported approval mechanism after discovery. A single green checkbox editable by BDM users is not the approval control. Review assignment, due date, reminders and rejection reasons must be visible.

Any material change to attendance, venue, event date, activity, weather or staffing marks the event for reassessment. An open material revision blocks the initial Rosterfy handoff. The previously accepted quote and already-created event remain auditable while the new version is assessed.

## 9. Costing, quotes and acceptance

Use standard Salesforce Quotes and a demo Price Book if available; do not introduce CPQ/Revenue Cloud solely for this demonstration. Each resource line has a quantity and unit basis, internal rate and selling rate. Include setup/travel/equipment/other charges only where configured. Currency, tax treatment, rounding and discounts require agreed settings; do not hard-code a presumed tax treatment.

Opportunity Amount is the proposed/accepted selling value. Store internal cost and expected margin separately. Retain the original approved commercial cost snapshot and the latest operational forecast so absorbed extra staffing can reduce margin without changing revenue.

Generate quote lines from the approved requirements through an explicit action. Stamp the quote with its assessment-set and pricing snapshots. Standard quote sync supports only one synced quote per Opportunity and can update line items both ways; control when it is enabled. Do not allow future pricing or resource edits to mutate a sent/accepted quote. Copy to a new quote revision, keep the previous PDF and acceptance evidence, and manage the selected/synced quote deliberately. Do not assume custom snapshot fields sync automatically.

The customer receives a clear PDF with scope, dates, service lines, price, assumptions, exclusions, validity and acceptance instructions. Keep internal risk scoring, margin, debtor notes and volunteer personal information out of it. Attach medical-plan content only if approved for customer distribution.

For the first demo, send the quote to an authorised test mailbox and record acceptance internally against the received email or signed PDF. This is a demonstrable process without assuming an e-signature licence. An authenticated acceptance portal or approved signing provider is a later option. Never use a bare public Salesforce record ID to accept a quote.

Enforce the Closed Won gate server-side: a valid accepted quote version, current required risk approvals, accepted commercial terms, resource review and any required credit clearance. Stale/superseded/expired quote acceptance must not close the Opportunity. Repeated processing of the same acceptance must be harmless.

For changes after acceptance:

- **Absorbed cost:** approve the operational change, update the latest cost forecast and staffing plan, and leave the accepted customer quote unchanged.
- **Chargeable change:** create a new quote/change revision linked to the prior quote, approve it and obtain customer acceptance before sending the chargeable plan change. Decide whether the business wants a replacement quote or a delta quote; label it consistently and prevent double-counting revenue.
- **Safety change pending commercial decision:** flag for operations review. Do not invent an automatic reduction in resources or silently change the bill. The emergency handling policy requires St John approval.

## 10. Create in Rosterfy button and API integration

### User interaction

Place **Create in Rosterfy** on the operational initiative/event record. On a parent multi-day booking, it may launch a batch preview of all eligible child event days. Also show Open in Rosterfy, Refresh Status, Retry Failed Items and, after creation, Send Approved Updates. Restrict actions by permission.

The preview shows selected days, jobs/roles, shift times/timezone, capacities, relevant qualification mappings, venue, approved assessment versions, operational instructions and publication mode. Hide internal rates, margin, debtor notes and full risk answers from the outbound operational payload. Require a user confirmation to queue the transfer.

Start with **draft/unpublished creation**, followed by operations review in Rosterfy before volunteer applications open. Verify that the API supports this state. If it cannot be controlled, stop and agree a safe alternative; do not allow an apparently harmless demo button to publish real volunteer opportunities.

The server must independently check the record and permissions, even if the button is hidden or disabled. Required conditions: Closed Won; accepted quote remains applicable; current approved assessments and resource plan; no unresolved material revision; valid dates/timezone; mapped venue/type/roles; all required approvals; active test/live configuration; no pending duplicate request; no existing remote event for a Create operation.

### Integration shape

Use a Named Credential and External Credential for the approved Rosterfy API. The browser never receives the token. A button-triggered Screen Flow calls an invocable Apex service to validate and save an integration request. A Queueable Apex worker performs the HTTP calls after the transaction commits and returns status to Salesforce. Do not hold a browser request open until all remote records are created.

Use one external operation per worker transaction where practical. Do not perform DML and then attempt a callout with uncommitted work in the same transaction. Persist the result after the callout and queue the next unit. Handle platform limits in a bounded worker, not one unbounded loop across all event days.

Proposed components:

- `SJV_RosterfySubmissionService`: permissions, readiness checks, request uniqueness and approval snapshot.
- `SJV_RosterfyPayloadMapper`: maps the selected Salesforce model into a canonical event/shift demand structure.
- `SJV_RosterfyClient`: interface implemented by an HTTP client and an explicitly labelled demo stub.
- `SJV_RosterfySyncQueueable`: processes event/shift operations and persists results.
- `SJV_RosterfyRecoveryService`: retries safe failures and reconciles uncertain outcomes.
- `SJV_IntegrationStatus` LWC or standard related-list/status panel: per-event and per-shift progress, errors and permitted actions.

These are proposed names, not existing components. Prefer a straightforward single integration implementation over a generic integration framework.

### Mapping that must be validated

| Salesforce source | Canonical demand | Rosterfy target to verify |
|---|---|---|
| Initiative/day | Event name, reference, timezone, dates, location, instructions | Event |
| Job Position | Role, scope/qualification requirements and demand category | Shift role/eligibility configuration and/or Role Offer, only as supported by the tenant |
| Job Position Shift | Start/end, capacity, role mapping, breaks, publication state | Event Shift |
| Approved assessment | Safe operational instructions, assessment version/reference and approved requirements | Approved custom fields/notes or protected document reference; do not send the full assessment automatically |
| Stable source key | Cross-system identity | Supported external/custom field or a verified lookup strategy |
| Named volunteer assignment | Out of scope for this outbound demo | Remains managed in Rosterfy |

There is no established one-to-one equivalence between a Salesforce Job Position and a Rosterfy Role Offer. For the first slice, a role-specific Salesforce shift can map to a role-specific Rosterfy shift using a preconfigured role/eligibility mapping. If creating Role Offers is necessary, verify that write API separately. Labels in shift names do not enforce qualification or supervision rules.

Minimum live proof: click once in Salesforce, show the resulting draft event and at least one correctly configured shift in the Rosterfy test tenant, and show the returned IDs/status on the Salesforce source records. Then add a second role/shift and prove the same event is reused.

### Canonical payload, not the Rosterfy HTTP contract

The following is the internal data transfer object only. The HTTP adapter must translate it using the vendor's verified schema. It is not permission to send these field names directly to a guessed endpoint.

```json
{
  "sourceEventKey": "SJV-DEMO-EVENT-001-DAY-01",
  "approvedPlanRevision": 1,
  "assessmentVersions": ["SJV-DEMO-RA-001-V1"],
  "name": "DEMO Community Event - Day 1",
  "timezone": "Australia/Melbourne",
  "startLocal": "2026-12-05T09:00:00+11:00",
  "endLocal": "2026-12-05T17:00:00+11:00",
  "publicationMode": "Draft",
  "venueMappingKey": "DEMO-VENUE-01",
  "shifts": [
    {
      "sourceShiftKey": "SJV-DEMO-SHIFT-001",
      "roleMappingKey": "DEMO-APPROVED-ROLE-A",
      "startLocal": "2026-12-05T09:00:00+11:00",
      "endLocal": "2026-12-05T13:00:00+11:00",
      "capacity": 2
    }
  ]
}
```

### Idempotency, partial failure and safe retry

1. Maintain a stable source event/day key and stable shift keys independent of name, date and current revision. Store the returned remote IDs immediately after each successful unit.
2. The integration request has a unique operation key, such as environment + source key + operation + revision. Lock/check the source state when queueing. Double clicks, simultaneous users and replayed actions must not create two active Create requests.
3. Create the event first, then its shifts. If one shift fails, retain the event and successful shift IDs. The state is Partial, not Synced. Retry only failed/missing items; never delete the successful event as a generic rollback.
4. If the API supports idempotency keys or source-key lookup, use the documented behaviour. A timeout after a POST may mean creation succeeded remotely. Reconcile before retrying. If no safe lookup exists, stop in Needs Reconciliation and require an operator to verify the remote outcome; do not blindly POST again.
5. Retry transient failures with bounded backoff and any documented rate-limit guidance. Authentication failures, invalid mappings and validation errors require correction. Record attempt counts and a clear owner/action.
6. Queue the approved snapshot. Recheck that it has not been superseded before processing. If a newer plan is approved during transfer, complete/reconcile the known result, then mark Update Required rather than sending a mixed set of revisions.
7. A complete local request is not proof of remote success. Read back the remote event/shifts when supported and compare key dates, timezone, capacity and role configuration. Store the last verified time.
8. Protect the record from repeat Create once remote IDs exist. Reopening/reclosing an Opportunity must not duplicate the event. Date changes, cancellation and capacity updates use verified update/cancel methods and preserve assignments; if unsupported, create an explicit operational action instead of deleting/recreating.

Use separate commercial and integration states. Proposed sync states: Not Ready, Ready, Queued, In Progress, Partial, Synced, Failed, Needs Reconciliation and Update Required. Show the user a plain-language result and correlation reference. Logs must redact tokens, personal information and customer financial details.

### Rosterfy information required before live implementation

Obtain the current API/OpenAPI documentation and test tenant details directly from Rosterfy: base URL/version; authentication; event create/read/update/cancel; shift create/read/update/cancel; required fields and IDs; draft/publish controls; timezone format; role and qualification configuration; supported external identifiers; search/idempotency; pagination; rate limits; error schema; permissions and licence entitlements.

The reviewed public connector documentation describes operational event/shift data flowing from Rosterfy to Salesforce. It does not establish the requested outbound create path. Public API documentation could not be read sufficiently to validate the write contract. Therefore the outbound adapter is a required custom API proof, with its exact endpoints unresolved at the time of this plan.

If an existing inbound connector is also enabled, prevent it from creating duplicate Salesforce events/jobs/shifts after this outbound process. Agree cross-system IDs, field ownership, origin markers and conflict handling before enabling both. For the initial demo, keep overlapping inbound operational creation disabled unless it can upsert the same records reliably.

## 11. Permissions and boundaries

| Persona | Intended access |
|---|---|
| Public enquiry visitor | Submit their enquiry and receive a generic acknowledgement only. |
| BDM | Leads, customer contacts, Opportunities, quotes, follow-up tasks and proposal preparation. Cannot self-approve restricted clinical decisions. |
| Clinical reviewer | Relevant assessments and requirements, review decisions and operational context. Financial access only if separately granted. |
| Operations reviewer | Pipeline demand, event/day/job/shift plans, operational approvals and permitted Rosterfy actions. |
| Finance/commercial approver | Rates, discounts, credit warnings and chargeable/absorbed change decisions. |
| Integration operator | Request status, redacted diagnostics, mapping maintenance and authorised recovery actions. |

Use permission sets and sharing rules that fit the existing org. Enforce record access and field permissions in internal Apex as well as in the UI. Keep integration worker privileges separate from the initiating user's right to request a transfer. Scope background writes to the recorded approved request.

The public enquiry wizard does not grant access to customer event history, risk answers, internal costs, volunteer records or roster gaps. Any future customer portal must have a separate, restricted view. Existing staff SSO/MFA policy applies; do not weaken it to prepare a demo.

## 12. Demo scope and later work

**Build for the main demo:** guided enquiry; Lead conversion; BDM tasks; approved risk version 1; job/shift demand; cost versus price; quote PDF/email; evidence-backed acceptance; Closed Won; manual API handoff; returned IDs; partial-failure recovery; risk version 2 with an absorbed cost change; pre-confirmation operations view.

**Keep as clearly identified follow-up work:** SAP invoicing/debtor integration, Dayforce payroll, payments, full electronic signing, authenticated customer portal, production marketing journeys, asset reservation/conflict engine, full service-history migration, SIMON replacement, CAD/Atlas, Dispatcher welfare, radio allocation and ePCR. The event handoff does not prove those SJC dependencies can be retired.

Customer credit warning, feedback and renewal tasks can be lightweight demo examples. Invoice generation and payments must not be presented as included merely because a Quote or Closed Won Opportunity exists. Likewise, showing a contractual four-minute target in event instructions does not measure response time; that needs operational dispatch timestamps.

## 13. Ordered implementation backlog

| Stage | Build tasks | Completion evidence |
|---|---|---|
| 0. Discovery and dependency proof | Inspect org/repo; choose volunteer schema; confirm Quotes/Experience Cloud; obtain risk form/rates; validate Rosterfy event and shift write capabilities in test tenant. | Org discovery file, schema mapping, API capability matrix and explicit blockers. No invented endpoints. |
| 1. Record model and permissions | Create required fields/custom records, record pages, permissions, source keys and relationships. Seed role and venue mappings. | BDM/clinical/operations views show appropriate data; guest has no internal read access. |
| 2. Enquiry and BDM flow | Build public wizard, secure submission, acknowledgement, assignment, tasks, lead conversion and event planning record creation. | One test enquiry produces one Lead and later one linked Opportunity/event with all submitted details retained. |
| 3. Assessment engine and versions | Build internal risk flow, version service, answer comparison, deterministic rules, approvals and PDF output. | Submitted versions cannot be edited; a second version retains the first and shows a clear comparison. |
| 4. Demand and commercial quote | Map approved requirements into jobs/shifts and price lines. Separate cost/sell amounts. Generate quote PDF, send to test mailbox and record acceptance. | Quote snapshot matches approved requirements; accepted version cannot be silently changed. |
| 5. API button and worker | Build preview, server checks, request/outbox, Named Credential, client, asynchronous worker, returned IDs and status panel. | Live test creates a draft event plus shifts in Rosterfy and saves IDs in Salesforce. |
| 6. Updates and recovery | Add double-click prevention, partial failure, uncertain timeout recovery, approved updates and stale-version checks. | Failure/retry tests create no duplicate event or shift and never report Partial as Synced. |
| 7. Finish demo and handover | Pipeline/task dashboards, synthetic data, permissions tests, runbook, deploy/reset instructions and unresolved decisions. | Demo can be repeated cleanly, with live versus simulated functions identified. |

Stages 1–4 can proceed with approved illustrative data while vendor API details are pending. Stage 5 is not complete until a real create/readback test passes. This is an implementation sequence, not a fixed effort estimate; estimate after Stage 0 establishes org and API readiness.

## 14. Acceptance tests

| ID | Test | Required result |
|---|---|---|
| AT01 | Submit a multi-day guest enquiry and click twice | One submission/Lead, correct day data, generic acknowledgement and no leaked record identifiers. |
| AT02 | Tamper with a public request using internal IDs, approval flags or rates | Server rejects/ignores prohibited fields; no internal data returned or changed. |
| AT03 | Existing customer and ambiguous duplicate match | Staff choose the correct Account/Contact; no public match disclosure or automatic unsafe merge. |
| AT04 | Convert Lead | Linked enquiry persists; Account, Contact, Opportunity and event references are correct; rerun creates no duplicate event. |
| AT05 | Missing assessment answer or unapproved risk rules | Assessment cannot become operationally approved; demo rules remain visibly labelled. |
| AT06 | Higher-risk review | Correct review tasks and approval records; BDM cannot bypass restricted approval. |
| AT07 | Concurrent assessment revisions | Unique ordered versions; no overwrite; each retains its questions/rules/answers/outputs. |
| AT08 | Apply approved requirements twice | Existing job/shift planning records update by stable keys; no duplicate demand. |
| AT09 | Two people for four hours plus daily equipment | Headcount, staff-hours, equipment units, internal cost, selling price and margin are calculated separately and correctly. |
| AT10 | Send quote then change rates/assessment | Sent PDF and snapshot remain unchanged; new proposal uses a new revision. |
| AT11 | Accept an obsolete/expired quote | Close Won and handoff are blocked until current acceptance and reviews are satisfied. |
| AT12 | Close Won with missing credit/resource/clinical approval | Server-side validation prevents bypass through UI or API. |
| AT13 | Close Won with all checks satisfied | Event becomes Ready; no API call occurs until a permitted user clicks Create in Rosterfy. |
| AT14 | Two users click Create simultaneously | One active Create operation and one remote event per transfer unit. |
| AT15 | Live API transfer | Draft event and all intended shifts exist in Rosterfy with correct role mappings, capacity and timezone; IDs saved locally. |
| AT16 | Event succeeds, second shift fails | Partial status; successful remote IDs retained; retry creates only missing work. |
| AT17 | Timeout after remote creation | Lookup/idempotency resolves the outcome, or Needs Reconciliation prevents blind duplicate creation. |
| AT18 | Validation failure, expired token, rate limit | Clear action-specific error and bounded retry policy; no exposed secret. |
| AT19 | Risk revision increases resources after acceptance | New operational version and forecast cost; original agreed price unchanged unless a chargeable variation is accepted. |
| AT20 | New plan approved while an old request is queued | Worker detects stale snapshot; no mixed-version handoff or silent overwrite. |
| AT21 | Overnight/multi-day event and daylight-saving boundary | Local display, UTC conversion, duration and remote dates match the event's timezone. |
| AT22 | Change/cancel an event already in Rosterfy | Uses verified update/cancel path or controlled manual exception; never deletes/recreates assigned shifts indiscriminately. |
| AT23 | Existing inbound connector echoes an outbound event | Same records matched by approved keys; no loop or duplicate Salesforce event. |
| AT24 | Restricted reviewer or guest opens a direct record URL | Access denied to unauthorised records, financials and sensitive content. |
| AT25 | Demo reset | Deletes/resets only explicitly tagged synthetic records in the approved test environments; preserves real data and pending API work. |

Automate Apex service/calculation/version/integration tests with `HttpCalloutMock`, meaningful positive and negative assertions, and the org's required deployment coverage. Add LWC tests where custom components implement validation or state changes. Verify site/Flow behaviour manually in the appropriate user sessions. Include volume tests for a realistic multi-day event and multiple shifts, not only one-record examples.

## 15. Demonstration script and sample data

Use a fictitious customer, venue and event, with approved test email addresses. No real patient or volunteer health data is needed.

1. Submit a two-day community event enquiry on the Experience Cloud site. Use different hours for each day and leave one detail unknown to demonstrate follow-up.
2. Open the BDM workspace, show the assigned Lead, follow-up task, account warning example and the enquiry summary. Resolve the missing detail and convert.
3. Show operations the tentative event and estimated demand before it is confirmed.
4. Complete the initial assessment, explain why the illustrative rules produce the proposed requirements, and obtain the necessary review.
5. Generate two role-specific jobs and their shifts. Show the headcount, hours, cost and selling-price distinction.
6. Generate the quote PDF, send it to the test mailbox, record acceptance evidence, and mark the Opportunity Won. Show that nothing has yet been created in Rosterfy.
7. Click Create in Rosterfy, review the payload summary and submit. Open the new draft event and shifts in the test tenant. Return to Salesforce to show IDs and success status.
8. Demonstrate a failed shift request and safe retry using a controlled test condition. Do not cause failures in a production tenant.
9. Revise one day's assessment because conditions changed. Compare versions and approve extra resources with costs absorbed. Show unchanged accepted revenue and revised forecast margin. Send the approved update where the API permits it.
10. Finish with tasks, quote follow-up, review backlog, upcoming demand and integration failures on the dashboard.

Do not set the number of clinicians, score thresholds or prices as operational recommendations. Seed illustrative values only. The runbook must state which inputs are synthetic and which have been approved by St John.

## 16. Decisions and inputs still needed

| Input/decision | Why it matters | Suggested owner |
|---|---|---|
| Actual demo org, packages and licences | Select the volunteer objects and portal/quote features that can be built. | NobleCX / Salesforce admin |
| Current risk questionnaire, scoring rules, escalation matrix and sample completed assessments | Reproduce St John's process rather than invent clinical policy. | St John clinical and operations leads |
| Rates, pricing units, taxes, discount approval, quote terms and credit policy | Generate meaningful commercial examples and approval gates. | BDM / Finance |
| One Rosterfy event per operational day versus another grouping | Determines API cardinality, identifiers and daily assessments. | Operations / Rosterfy |
| Event/shift API contract and write permission | Required for the live button demonstration. | Rosterfy technical team |
| Job-to-role/shift qualification mapping | Prevent a label-only job from being mistaken for enforced eligibility. | Rosterfy / Clinical / Operations |
| Draft creation and later publishing responsibility | Controls when volunteers can see/apply for shifts. | Operations / Rosterfy |
| Operations visibility before confirmation and user access | Avoid the workshop's concern that proposed work becomes invisible until Won. | St John sponsor / Operations |
| Accepted quote changes and absorbed versus billable costs | Preserve the commercial agreement while risk requirements change. | BDM / Finance / Operations |
| Existing inbound connector and field ownership | Avoid duplicate records and conflicting updates. | Salesforce admin / Rosterfy |

## 17. Evidence and technical references

### Project evidence

- [Discovery Workshops Framework](https://docs.google.com/document/d/1nVzQXYImCyG3buoRRl4r1OyVZU7pD-FYwlNRMXDUHyo/edit): unresolved risk, resource, API, permissions and reporting requirements.
- [Workshop 3 transcript](https://drive.google.com/file/d/16QiaeIDTydEhF-cGf41EBCrcTkPk_enB/view): 10:42–10:45 recurring customers, venue instructions and contractual KPIs; 10:45–10:49 quoting and system boundaries; 11:03–11:11 risk scoring, clinical/operations review, daily assessments, later revisions and absorbed costs; 11:12–11:17 customer follow-up and Sarah's tasks; 11:25–11:29 review collaboration and pipeline visibility; 11:32–11:37 client confidentiality, debt warnings and proposed-event visibility.
- [Workshop 4 transcript](https://drive.google.com/file/d/1GUezHA1FVtAKbt6JOej7JYAc8TYOpeqT/view): 13:15–13:23 identity and API considerations; 13:25–13:45 CAD/Atlas, Dispatcher and radio allocation; 13:52–13:58 ePCR role access and audit. These remain separate dependencies beyond this commercial demo.
- Ramtin's latest instructions: event enquiry as Lead, nurture and conversion, assessment-generated requirements/cost, quote acceptance, Closed Won, Salesforce jobs/shifts and an explicit button to send the event through the Rosterfy API.

### Primary product references checked 9 November 2026

- [Salesforce Volunteer Management objects](https://developer.salesforce.com/docs/industries/nonprofit-cloud/guide/volunteer-mgmt-standard-objects.html).
- [VolunteerInitiative object](https://developer.salesforce.com/docs/industries/nonprofit-cloud/guide/volunteer-mgmt-api-objects-volunteer-initiative.html).
- [JobPosition object](https://developer.salesforce.com/docs/industries/nonprofit-cloud/guide/volunteer-mgmt-api-objects-jobposition.html).
- [JobPositionShift object](https://developer.salesforce.com/docs/industries/nonprofit-cloud/guide/volunteer-mgmt-api-objects-jobpositionshift.html).
- [Volunteers for Salesforce FAQ](https://help.salesforce.com/s/articleView?id=sfdo.V4S_FAQ.htm&language=en_US&type=5): legacy Campaign/Job/Shift hierarchy.
- [Salesforce quote syncing](https://help.salesforce.com/s/articleView?id=sales.quotes_synch_overview.htm&language=en_US&type=5): only one quote can be synced to an Opportunity at a time; line items sync in both directions.
- [Experience Cloud Flow security](https://developer.salesforce.com/docs/platform/communities-dev/guide/communities-dev-security-guest-users-flows.html).
- [Named Credentials for Apex callouts](https://developer.salesforce.com/docs/platform/apex-dev/references/apex-dev/apex-callouts-named-credentials.html).
- [Apex HTTP callouts](https://developer.salesforce.com/docs/platform/apex-dev/references/apex-dev/apex-classes-restful-http.html): account for pending-DML restrictions.
- [Rosterfy Salesforce integration explanation](https://www.rosterfy.com/uk-en/integrations/salesforce-how-it-works/): operational data flows from Rosterfy into Salesforce; does not validate the requested reverse creation path.
- [Rosterfy connector help](https://helpdesk.rosterfy.uk/en/articles/11614921-salesforce-two-way-integration): compare with the preceding page and confirm sandbox support directly because their statements differ.
- [Rosterfy object guide](https://helpdesk.rosterfy.uk/en/articles/15928812-rosterfy-objects-reference-guide): distinguish Event, Event Shift, Event Shift User and Role Offer.
- [Rosterfy event creation](https://helpdesk.rosterfy.uk/en/articles/11615123-create-and-update-an-event) and [shift creation](https://helpdesk.rosterfy.uk/en/articles/11615092-creating-a-shift): UI concepts and draft/publication behaviour; these pages are not write-API specifications.

The public APIary documentation endpoint could not be read successfully during this review. No write endpoint or authentication scheme is asserted in this plan. Obtain the current tenant-supported API contract before implementing the live adapter.
