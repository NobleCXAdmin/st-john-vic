/**
 * @description Outbound Rosterfy transfer service.
 *              Validates handoff readiness, calls SJV_RosterfyService to make real
 *              HTTP calls to the Rosterfy API v2, creates SJV_Integration_Request__c
 *              and SJV_Integration_Item__c outbox records, stamps remote IDs onto
 *              VolunteerInitiative and JobPositionShift, and supports safe partial-failure retry.
 *
 *              To enable real API calls:
 *                1. Set Bearer_Token__c in SJV_Rosterfy_Config__mdt (Default record)
 *                2. Set Is_Active__c = true on that same record
 *                3. Add app.rosterfy.com to Setup > Remote Site Settings (or the Named Credential endpoint)
 */
public without sharing class SJV_RosterfySubmissionService {

    // ─── Inner types ─────────────────────────────────────────────────────────

    public class PreviewPayload {
        @AuraEnabled public Id     initiativeId;
        @AuraEnabled public String eventName;
        @AuraEnabled public String sourceEventKey;
        @AuraEnabled public Date   startDate;
        @AuraEnabled public Date   endDate;
        @AuraEnabled public String timezone;
        @AuraEnabled public String publicationMode;
        @AuraEnabled public Integer approvedRevision;
        @AuraEnabled public String venueInstructions;
        @AuraEnabled public List<ShiftPayload> shifts;
        @AuraEnabled public Boolean isReadyForTransfer;
        @AuraEnabled public String validationError;
        @AuraEnabled public Boolean integrationActive;
    }

    public class ShiftPayload {
        @AuraEnabled public Id     shiftId;
        @AuraEnabled public String sourceShiftKey;
        @AuraEnabled public String roleName;
        @AuraEnabled public String roleCode;
        @AuraEnabled public Date   shiftDate;
        @AuraEnabled public Time   startTime;
        @AuraEnabled public Time   endTime;
        @AuraEnabled public Integer capacity;
        @AuraEnabled public String remoteShiftId;
        @AuraEnabled public String syncStatus;
    }

    public class TransferResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id      requestId;
        @AuraEnabled public String  requestNumber;
        @AuraEnabled public String  syncState;
        @AuraEnabled public String  remoteEventId;
        @AuraEnabled public String  remoteEventUrl;
        @AuraEnabled public Integer successfulShifts;
        @AuraEnabled public Integer failedShifts;
        @AuraEnabled public String  message;
    }

    // ─── Preview ─────────────────────────────────────────────────────────────

    /**
     * @description Previews the outbound payload and validates readiness server-side.
     *              No HTTP calls are made during a preview.
     */
    @AuraEnabled
    public static PreviewPayload getTransferPreview(Id initiativeId) {
        PreviewPayload p     = new PreviewPayload();
        p.initiativeId       = initiativeId;
        p.shifts             = new List<ShiftPayload>();
        p.publicationMode    = 'Draft (Unpublished)';
        p.integrationActive  = SJV_RosterfyService.isActive();

        VolunteerInitiative vi = [
            SELECT Id, Name, StartDate, EndDate,
                   SJV_Opportunity__c, SJV_Opportunity__r.StageName,
                   SJV_Opportunity__r.IsWon,
                   SJV_Opportunity__r.SJV_Handoff_Readiness__c,
                   SJV_Opportunity__r.SJV_Accepted_Quote__c,
                   SJV_Source_Event_Key__c, SJV_Timezone__c,
                   SJV_Approved_Plan_Revision__c, SJV_Venue_Instructions__c,
                   SJV_Remote_Event_Id__c, SJV_Sync_State__c
            FROM VolunteerInitiative
            WHERE Id = :initiativeId
            LIMIT 1
        ];

        p.eventName       = vi.Name;
        p.sourceEventKey  = vi.SJV_Source_Event_Key__c;
        p.startDate       = vi.StartDate;
        p.endDate         = vi.EndDate;
        p.timezone        = String.isNotBlank(vi.SJV_Timezone__c) ? vi.SJV_Timezone__c : SJV_RosterfyService.defaultTimezone();
        p.approvedRevision = (vi.SJV_Approved_Plan_Revision__c != null) ? Integer.valueOf(vi.SJV_Approved_Plan_Revision__c) : 1;
        p.venueInstructions = vi.SJV_Venue_Instructions__c;

        // Validation
        Boolean isWon = (vi.SJV_Opportunity__r != null && vi.SJV_Opportunity__r.IsWon == true);
        if (vi.SJV_Opportunity__r == null || !isWon) {
            p.isReadyForTransfer = false;
            p.validationError = 'Transfer blocked: Opportunity must be Closed Won before creating in Rosterfy.';
        } else if (vi.SJV_Opportunity__r.SJV_Handoff_Readiness__c != 'Ready'
                && vi.SJV_Sync_State__c != 'Ready'
                && vi.SJV_Sync_State__c != 'Partial'
                && vi.SJV_Sync_State__c != 'Update Required') {
            p.isReadyForTransfer = false;
            p.validationError = 'Transfer blocked: Handoff readiness is not Ready (Current: ' + vi.SJV_Sync_State__c + ').';
        } else {
            p.isReadyForTransfer = true;
        }

        // Shifts preview
        for (JobPositionShift s : [
            SELECT Id, SJV_Source_Shift_Key__c, StartDate, StartTime, EndTime,
                   MaximumAttendeesCount, SJV_Remote_Shift_Id__c, SJV_Sync_Status__c,
                   JobPosition.Title, JobPosition.SJV_Role_Mapping_Key__c
            FROM JobPositionShift
            WHERE JobPosition.VolunteerInitiativeId = :vi.Id
            ORDER BY StartDate, StartTime
        ]) {
            ShiftPayload sp  = new ShiftPayload();
            sp.shiftId       = s.Id;
            sp.sourceShiftKey = s.SJV_Source_Shift_Key__c;
            sp.roleName      = s.JobPosition.Title;
            sp.roleCode      = s.JobPosition.SJV_Role_Mapping_Key__c;
            sp.shiftDate     = s.StartDate;
            sp.startTime     = s.StartTime;
            sp.endTime       = s.EndTime;
            sp.capacity      = s.MaximumAttendeesCount != null ? Integer.valueOf(s.MaximumAttendeesCount) : 1;
            sp.remoteShiftId = s.SJV_Remote_Shift_Id__c;
            sp.syncStatus    = s.SJV_Sync_Status__c;
            p.shifts.add(sp);
        }

        return p;
    }

    // ─── Transfer ────────────────────────────────────────────────────────────

    /**
     * @description Executes the Rosterfy transfer.
     *              Creates (or updates) the Event in Rosterfy, then creates any Shifts
     *              not yet synced. Stamping of remote IDs back to Salesforce is done
     *              after each successful API call.
     *              When Is_Active__c = false on SJV_Rosterfy_Config__mdt, the method
     *              runs in simulation mode (generates fake IDs, no real HTTP calls).
     *
     * @param initiativeId          The VolunteerInitiative to transfer.
     * @param simulatePartialFailure  When true (and integration inactive), simulates
     *                                a partial failure on the second shift for demo purposes.
     */
    @AuraEnabled
    public static TransferResult executeTransfer(Id initiativeId, Boolean simulatePartialFailure) {
        TransferResult res = new TransferResult();
        res.successfulShifts = 0;
        res.failedShifts     = 0;

        try {
            // ── 1. Load data (all SOQL before any DML or callouts) ───────────
            VolunteerInitiative vi = [
                SELECT Id, Name, StartDate, EndDate,
                       SJV_Opportunity__c, SJV_Opportunity__r.IsWon,
                       SJV_Opportunity__r.SJV_Handoff_Readiness__c,
                       SJV_Source_Event_Key__c, SJV_Timezone__c,
                       SJV_Venue_Instructions__c, SJV_Remote_Event_Id__c,
                       SJV_Sync_State__c, SJV_Approved_Plan_Revision__c
                FROM VolunteerInitiative
                WHERE Id = :initiativeId
                LIMIT 1
            ];

            List<JobPositionShift> shifts = [
                SELECT Id, SJV_Source_Shift_Key__c, StartDate, EndDate,
                       StartTime, EndTime, MaximumAttendeesCount,
                       SJV_Remote_Shift_Id__c, SJV_Sync_Status__c,
                       JobPosition.Title, JobPosition.SJV_Role_Mapping_Key__c
                FROM JobPositionShift
                WHERE JobPosition.VolunteerInitiativeId = :vi.Id
                ORDER BY StartDate, StartTime
            ];

            Boolean integrationActive = SJV_RosterfyService.isActive();

            // ── 2. ALL HTTP callouts BEFORE any DML ──────────────────────────
            String remoteEventId  = vi.SJV_Remote_Event_Id__c;
            String remoteEventUrl = null;

            // Accumulators for shift results (populated during callout phase)
            List<String>  shiftRemoteIds   = new List<String>();
            List<Boolean> shiftSuccesses   = new List<Boolean>();
            List<Integer> shiftStatusCodes = new List<Integer>();
            List<String>  shiftErrors      = new List<String>();

            if (integrationActive) {
                // 2a. Create / update the Event
                Map<String, Object> eventPayload = buildEventPayload(vi);
                SJV_RosterfyService.ApiResponse eventRes = String.isBlank(remoteEventId)
                    ? SJV_RosterfyService.createEvent(eventPayload)
                    : SJV_RosterfyService.updateEvent(remoteEventId, eventPayload);

                if (!eventRes.isSuccess()) {
                    res.success = false;
                    res.message = 'Rosterfy event creation failed: ' + eventRes.errorMessage();
                    return res;
                }

                // Extract remote ID from custom_salesforce_event_id reverse-lookup
                // (Rosterfy 201 response body doesn't include the new record's ID)
                String lookedUpId = SJV_RosterfyService.findEventBySfId(vi.Id);
                if (String.isNotBlank(lookedUpId)) {
                    remoteEventId = lookedUpId;
                }
                remoteEventUrl = 'https://sja-aus.uat.rosterfy.com/event/' + remoteEventId;

                // 2b. Create / update each Shift
                for (Integer i = 0; i < shifts.size(); i++) {
                    JobPositionShift s = shifts[i];
                    if (String.isNotBlank(s.SJV_Remote_Shift_Id__c) && s.SJV_Sync_Status__c == 'Synced') {
                        // Already synced — record as success without calling out
                        shiftRemoteIds.add(s.SJV_Remote_Shift_Id__c);
                        shiftSuccesses.add(true);
                        shiftStatusCodes.add(200);
                        shiftErrors.add(null);
                        continue;
                    }
                    Map<String, Object> shiftPayload = buildShiftPayload(s);
                    SJV_RosterfyService.ApiResponse shiftRes = SJV_RosterfyService.createShift(remoteEventId, shiftPayload);
                    if (shiftRes.isSuccess()) {
                        // Shift 201 response includes the new ID directly in response body under 'object'
                        Map<String, Object> shiftBody = shiftRes.parsed();
                        Map<String, Object> shiftObj  = shiftBody.containsKey('object')
                            ? (Map<String, Object>) shiftBody.get('object') : shiftBody;
                        String shiftId = shiftObj.get('id') != null ? String.valueOf(shiftObj.get('id')) : null;
                        shiftRemoteIds.add(String.isNotBlank(shiftId) ? shiftId : ('SHIFT-' + i));
                        shiftSuccesses.add(true);
                        shiftStatusCodes.add(201);
                        shiftErrors.add(null);
                    } else {
                        shiftRemoteIds.add(null);
                        shiftSuccesses.add(false);
                        shiftStatusCodes.add(shiftRes.statusCode);
                        shiftErrors.add(shiftRes.errorMessage());
                    }
                }

            } else {
                // Simulation mode — generate fake IDs (no callouts)
                if (String.isBlank(remoteEventId)) {
                    remoteEventId = 'SIM-EVT-' + Crypto.getRandomInteger();
                }
                remoteEventUrl = 'https://app.rosterfy.com/events/' + remoteEventId;

                for (Integer i = 0; i < shifts.size(); i++) {
                    JobPositionShift s = shifts[i];
                    Boolean failThis = (simulatePartialFailure == true && i == 1 && String.isBlank(s.SJV_Remote_Shift_Id__c));
                    if (failThis) {
                        shiftRemoteIds.add(null);
                        shiftSuccesses.add(false);
                        shiftStatusCodes.add(503);
                        shiftErrors.add('Simulated transient timeout on shift transfer.');
                    } else {
                        String sid = String.isNotBlank(s.SJV_Remote_Shift_Id__c)
                            ? s.SJV_Remote_Shift_Id__c : 'SIM-SHF-' + Crypto.getRandomInteger();
                        shiftRemoteIds.add(sid);
                        shiftSuccesses.add(true);
                        shiftStatusCodes.add(200);
                        shiftErrors.add(null);
                    }
                }
            }

            // ── 3. All DML AFTER callouts ────────────────────────────────────
            Integer successCount = 0;
            Integer failCount    = 0;

            // 3a. Integration Request header record
            SJV_Integration_Request__c req = new SJV_Integration_Request__c();
            req.Volunteer_Initiative__c = vi.Id;
            req.Target_System__c        = 'Rosterfy';
            req.Status__c               = 'In Progress';
            req.Attempt_Count__c        = 1;
            req.Correlation_Id__c       = 'CORR-' + System.currentTimeMillis();
            insert req;

            // 3b. Event outbox item
            SJV_Integration_Item__c evtItem = new SJV_Integration_Item__c();
            evtItem.Integration_Request__c = req.Id;
            evtItem.Item_Type__c           = 'Event';
            evtItem.Source_Key__c          = vi.SJV_Source_Event_Key__c;
            evtItem.Remote_Id__c           = remoteEventId;
            evtItem.Status__c              = 'Synced';
            evtItem.Response_Code__c       = integrationActive ? 201 : 200;
            evtItem.Attempt_Timestamp__c   = System.now();
            insert evtItem;

            // 3c. Shift outbox items + stamp shifts
            List<SJV_Integration_Item__c> shiftItems    = new List<SJV_Integration_Item__c>();
            List<JobPositionShift>         shiftsToUpdate = new List<JobPositionShift>();

            for (Integer i = 0; i < shifts.size(); i++) {
                JobPositionShift s = shifts[i];
                if (String.isNotBlank(s.SJV_Remote_Shift_Id__c) && s.SJV_Sync_Status__c == 'Synced'
                        && integrationActive) {
                    successCount++;
                    continue; // already synced, no outbox item needed
                }

                Boolean ok  = shiftSuccesses[i];
                String  sid = shiftRemoteIds[i];

                SJV_Integration_Item__c sItem = new SJV_Integration_Item__c();
                sItem.Integration_Request__c = req.Id;
                sItem.Item_Type__c           = 'Shift';
                sItem.Source_Key__c          = s.SJV_Source_Shift_Key__c;
                sItem.Attempt_Timestamp__c   = System.now();
                sItem.Status__c              = ok ? 'Synced' : 'Failed';
                sItem.Remote_Id__c           = sid;
                sItem.Response_Code__c       = shiftStatusCodes[i];
                if (!ok) sItem.Error_Message__c = shiftErrors[i];

                s.SJV_Remote_Shift_Id__c = ok ? sid : s.SJV_Remote_Shift_Id__c;
                s.SJV_Sync_Status__c     = ok ? 'Synced' : 'Failed';

                if (ok) { successCount++; } else { failCount++; }
                shiftItems.add(sItem);
                shiftsToUpdate.add(s);
            }

            if (!shiftItems.isEmpty())     insert shiftItems;
            if (!shiftsToUpdate.isEmpty()) update shiftsToUpdate;

            // 3d. Stamp VolunteerInitiative
            vi.SJV_Remote_Event_Id__c    = remoteEventId;
            vi.SJV_Last_Sent_Revision__c = vi.SJV_Approved_Plan_Revision__c;
            vi.SJV_Last_Sent_Time__c     = System.now();
            if (String.isNotBlank(remoteEventUrl)) {
                vi.SJV_Remote_Event_Url__c = remoteEventUrl;
            }
            vi.SJV_Sync_State__c = (failCount > 0) ? 'Partial' : 'Synced';
            update vi;

            // 3e. Close the Integration Request
            req.Status__c = (failCount > 0) ? 'Partial' : 'Synced';
            if (failCount > 0) {
                req.Error_Summary__c = failCount + ' shift(s) failed. Remote Event ID retained: '
                    + remoteEventId + '. Safe retry available.';
            }
            update req;

            SJV_Integration_Request__c freshReq = [SELECT Id, Name FROM SJV_Integration_Request__c WHERE Id = :req.Id];

            res.success          = (failCount == 0);
            res.requestId        = freshReq.Id;
            res.requestNumber    = freshReq.Name;
            res.syncState        = vi.SJV_Sync_State__c;
            res.remoteEventId    = remoteEventId;
            res.remoteEventUrl   = remoteEventUrl;
            res.successfulShifts = successCount;
            res.failedShifts     = failCount;

            String mode = integrationActive ? '' : ' [SIMULATION MODE]';
            res.message = failCount > 0
                ? mode + 'Transfer PARTIAL. Event ' + remoteEventId + ' created. '
                    + successCount + ' shift(s) synced, ' + failCount + ' failed. Use Retry to complete.'
                : mode + 'Event and ' + successCount + ' shift(s) successfully sent to Rosterfy. '
                    + 'Remote Event ID: ' + remoteEventId;
            return res;

        } catch (Exception ex) {
            res.success = false;
            res.message = 'Error executing Rosterfy transfer: ' + ex.getMessage();
            return res;
        }
    }

    // ─── Payload builders ────────────────────────────────────────────────────

    /**
     * @description Builds a Rosterfy event payload map from a VolunteerInitiative.
     */
    private static Map<String, Object> buildEventPayload(VolunteerInitiative vi) {
        String tz = String.isNotBlank(vi.SJV_Timezone__c)
            ? vi.SJV_Timezone__c
            : SJV_RosterfyService.defaultTimezone();
        String startAt = vi.StartDate != null ? String.valueOf(vi.StartDate) + 'T00:00:00' : null;
        String endAt   = vi.EndDate   != null ? String.valueOf(vi.EndDate)   + 'T23:59:59' : null;
        String descVal = String.isNotBlank(vi.SJV_Venue_Instructions__c)
            ? vi.SJV_Venue_Instructions__c
            : 'St John Ambulance Victoria - Volunteer Event';
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('name',                       vi.Name);
        payload.put('start_at',                   startAt);
        payload.put('end_at',                     endAt);
        payload.put('timezone',                   tz);
        payload.put('description',                descVal);
        payload.put('status',                     'published');
        payload.put('address',                    new List<Object>{ 'Melbourne VIC, Australia' });
        // Custom field on Rosterfy event — allows reverse-lookup by Salesforce ID after POST
        payload.put('custom_salesforce_event_id', String.valueOf(vi.Id));
        return payload;
    }

    /**
     * @description Builds a Rosterfy shift payload map from a JobPositionShift.
     *              Requires JobPosition.Title to be queried on the shift.
     */
    private static Map<String, Object> buildShiftPayload(JobPositionShift jps) {
        // Rosterfy API v2 requires start_timestamp / end_timestamp as "YYYY-MM-DD HH:mm:ss"
        // and max_demand (not positions). address must be array for POST.
        String dateStr = jps.StartDate != null ? String.valueOf(jps.StartDate) : '2026-01-01';
        String startTs = dateStr + ' ' + (jps.StartTime != null ? String.valueOf(jps.StartTime).left(5) + ':00' : '09:00:00');
        String endTs   = dateStr + ' ' + (jps.EndTime   != null ? String.valueOf(jps.EndTime).left(5)   + ':00' : '17:00:00');
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('name',                       jps.JobPosition.Title);
        payload.put('start_timestamp',            startTs);
        payload.put('end_timestamp',              endTs);
        payload.put('max_demand',                 jps.MaximumAttendeesCount != null ? Integer.valueOf(jps.MaximumAttendeesCount) : 1);
        payload.put('address',                    new List<Object>{ 'Melbourne VIC, Australia' });
        // Custom field on Rosterfy shift — allows ID extraction from 201 response body
        payload.put('custom_salesforce_shift_id', String.valueOf(jps.Id));
        return payload;
    }
}
