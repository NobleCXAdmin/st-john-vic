/**
 * @description HTTP client for the Rosterfy API v2.
 *              Pure HTTP layer — no Salesforce object types referenced here.
 *              Reads configuration from the SJV_Rosterfy_Config__mdt Custom Metadata
 *              record named "Default".
 *
 *              Bearer token must be set directly in the org via:
 *                Setup > Custom Metadata Types > SJV Rosterfy Config > Manage Records > Default
 *              Do NOT commit a real token to source control.
 */
public without sharing class SJV_RosterfyService {

    // ─── Custom exception ────────────────────────────────────────────────────
    public class SJV_RosterfyException extends Exception {}

    // ─── API Response wrapper ────────────────────────────────────────────────
    public class ApiResponse {
        public Integer statusCode;
        public String  body;
        public String  locationHeader; // Populated for 201 Created responses

        public Boolean isSuccess() {
            return statusCode != null && statusCode >= 200 && statusCode < 300;
        }

        public Map<String, Object> parsed() {
            if (String.isBlank(body)) return new Map<String, Object>();
            try {
                return (Map<String, Object>) JSON.deserializeUntyped(body);
            } catch (Exception e) {
                return new Map<String, Object>();
            }
        }

        public String errorMessage() {
            if (isSuccess()) return null;
            Map<String, Object> p = parsed();
            Object msg = p.get('message');
            return msg != null ? String.valueOf(msg) : ('HTTP ' + statusCode + ': ' + body);
        }

        /**
         * @description Extracts the numeric ID from the Location header URL.
         *              e.g. ".../api/v2/event/30100" → "30100"
         */
        public String locationId() {
            if (String.isBlank(locationHeader)) return null;
            String[] parts = locationHeader.split('/');
            return parts.isEmpty() ? null : parts[parts.size() - 1];
        }
    }

    // ─── Config lazy-load ────────────────────────────────────────────────────
    private static SJV_Rosterfy_Config__mdt configCache;
    private static Boolean configLoaded = false;

    private static SJV_Rosterfy_Config__mdt loadConfig() {
        if (!configLoaded) {
            List<SJV_Rosterfy_Config__mdt> records = [
                SELECT Base_URL__c, Bearer_Token__c, Default_Timezone__c,
                       Callout_Timeout_Seconds__c, Is_Active__c
                FROM SJV_Rosterfy_Config__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            configCache = records.isEmpty() ? null : records[0];
            configLoaded = true;
        }
        return configCache;
    }

    /**
     * @description Returns true only when the CMT record exists and Is_Active__c = true.
     *              Returns false (simulation mode) when the record is missing rather than throwing.
     */
    public static Boolean isActive() {
        SJV_Rosterfy_Config__mdt cfg = loadConfig();
        return cfg != null && cfg.Is_Active__c == true;
    }

    public static String defaultTimezone() {
        SJV_Rosterfy_Config__mdt cfg = loadConfig();
        if (cfg == null) return 'Australia/Melbourne';
        String tz = cfg.Default_Timezone__c;
        return String.isNotBlank(tz) ? tz : 'Australia/Melbourne';
    }

    // ─── Core HTTP helper ────────────────────────────────────────────────────
    private static ApiResponse callout(String method, String path, String jsonBody) {
        SJV_Rosterfy_Config__mdt cfg = loadConfig();

        if (cfg == null || cfg.Is_Active__c != true) {
            ApiResponse stub = new ApiResponse();
            stub.statusCode = 0;
            stub.body = '{"message":"Rosterfy integration is not active. Set Is_Active__c = true in SJV_Rosterfy_Config__mdt."}';
            return stub;
        }

        String token = cfg.Bearer_Token__c;
        if (String.isBlank(token) || token == 'REPLACE_WITH_REAL_BEARER_TOKEN') {
            throw new SJV_RosterfyException(
                'Rosterfy Bearer Token is not configured. '
                + 'Set Bearer_Token__c in Setup > Custom Metadata Types > SJV Rosterfy Config > Default.');
        }

        Integer timeoutMs = cfg.Callout_Timeout_Seconds__c != null
            ? Integer.valueOf(cfg.Callout_Timeout_Seconds__c) * 1000
            : 30000;

        HttpRequest req = new HttpRequest();
        req.setMethod(method);
        req.setEndpoint(cfg.Base_URL__c + path);
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(timeoutMs);

        if (String.isNotBlank(jsonBody)) {
            req.setHeader('Content-Type', 'application/json');
            req.setBody(jsonBody);
        }

        HttpResponse res = new Http().send(req);
        ApiResponse apiRes = new ApiResponse();
        apiRes.statusCode = res.getStatusCode();
        apiRes.body = res.getBody();
        // Capture Location header (Rosterfy returns new resource URL in Location on 201)
        String loc = res.getHeader('Location');
        if (String.isNotBlank(loc)) {
            apiRes.locationHeader = loc;
        }
        return apiRes;
    }

    // ─── Events ─────────────────────────────────────────────────────────────

    /** Creates an Event in Rosterfy. payload keys: name, start_at, end_at, timezone, description, status */
    public static ApiResponse createEvent(Map<String, Object> payload) {
        return callout('POST', '/event', JSON.serialize(payload));
    }

    /** Updates an existing Rosterfy Event (PATCH). */
    public static ApiResponse updateEvent(String remoteEventId, Map<String, Object> payload) {
        return callout('PATCH', '/event/' + remoteEventId, JSON.serialize(payload));
    }

    /** Retrieves an Event from Rosterfy by its remote ID. */
    public static ApiResponse getEvent(String remoteEventId) {
        return callout('GET', '/event/' + remoteEventId, null);
    }

    // ─── Shifts ─────────────────────────────────────────────────────────────

    /** Creates a Shift under a Rosterfy Event. payload keys: name, date, start_time, end_time, positions */
    public static ApiResponse createShift(String remoteEventId, Map<String, Object> payload) {
        return callout('POST', '/event/' + remoteEventId + '/shift', JSON.serialize(payload));
    }

    /** Updates an existing Rosterfy Shift. */
    public static ApiResponse updateShift(String remoteEventId, String remoteShiftId, Map<String, Object> payload) {
        return callout('PATCH', '/event/' + remoteEventId + '/shift/' + remoteShiftId, JSON.serialize(payload));
    }

    /** Retrieves a Shift from Rosterfy. */
    public static ApiResponse getShift(String remoteEventId, String remoteShiftId) {
        return callout('GET', '/event/' + remoteEventId + '/shift/' + remoteShiftId, null);
    }

    /** Lists all Shifts for a Rosterfy Event. */
    public static ApiResponse listShifts(String remoteEventId) {
        return callout('GET', '/event/' + remoteEventId + '/shift', null);
    }

    // ─── SF-ID lookup helpers ────────────────────────────────────────────────

    /**
     * @description After a 201 POST /event, search Rosterfy for the event whose
     *              custom_salesforce_event_id matches the Salesforce Initiative ID.
     *              Returns the Rosterfy numeric event ID as a String, or null if not found.
     */
    public static String findEventBySfId(String sfInitiativeId) {
        ApiResponse res = callout('GET', '/event?search=' + EncodingUtil.urlEncode(sfInitiativeId, 'UTF-8'), null);
        if (!res.isSuccess() || String.isBlank(res.body)) return null;
        try {
            List<Object> events = (List<Object>) JSON.deserializeUntyped(res.body);
            for (Object evObj : events) {
                Map<String, Object> ev  = (Map<String, Object>) evObj;
                Map<String, Object> obj = (Map<String, Object>) ev.get('object');
                if (obj == null) continue;
                Object sfId = obj.get('custom_salesforce_event_id');
                if (sfId != null && String.valueOf(sfId) == sfInitiativeId) {
                    return String.valueOf(obj.get('id'));
                }
            }
        } catch (Exception e) { /* ignore parse errors */ }
        return null;
    }

    /**
     * @description After a 201 POST /event/{id}/shift, list the event's shifts and
     *              find the one whose custom_salesforce_shift_id matches the SF shift ID.
     *              Returns the Rosterfy numeric shift ID as a String, or null if not found.
     */
    public static String findShiftBySfId(String remoteEventId, String sfShiftId) {
        ApiResponse res = listShifts(remoteEventId);
        if (!res.isSuccess() || String.isBlank(res.body)) return null;
        try {
            List<Object> shifts = (List<Object>) JSON.deserializeUntyped(res.body);
            for (Object shObj : shifts) {
                Map<String, Object> sh  = (Map<String, Object>) shObj;
                Map<String, Object> obj = sh.containsKey('object') ? (Map<String, Object>) sh.get('object') : sh;
                if (obj == null) continue;
                Object sfId = obj.get('custom_salesforce_shift_id');
                if (sfId != null && String.valueOf(sfId) == sfShiftId) {
                    return String.valueOf(obj.get('id'));
                }
            }
        } catch (Exception e) { /* ignore parse errors */ }
        return null;
    }

    // ─── SF-ID lookup helpers ────────────────────────────────────────────────

    /**
     * @description After a 201 POST /event, search Rosterfy for the event whose
     *              custom_salesforce_event_id matches the Salesforce Initiative ID.
     *              Returns the Rosterfy numeric event ID as a String, or null if not found.
     */
    public static String findEventBySfId(String sfInitiativeId) {
        ApiResponse res = callout('GET', '/event?search=' + EncodingUtil.urlEncode(sfInitiativeId, 'UTF-8'), null);
        if (!res.isSuccess() || String.isBlank(res.body)) return null;
        try {
            List<Object> events = (List<Object>) JSON.deserializeUntyped(res.body);
            for (Object evObj : events) {
                Map<String, Object> ev  = (Map<String, Object>) evObj;
                Map<String, Object> obj = (Map<String, Object>) ev.get('object');
                if (obj == null) continue;
                Object sfId = obj.get('custom_salesforce_event_id');
                if (sfId != null && String.valueOf(sfId) == sfInitiativeId) {
                    return String.valueOf(obj.get('id'));
                }
            }
        } catch (Exception e) { /* ignore parse errors */ }
        return null;
    }

    /**
     * @description After a 201 POST /event/{id}/shift, list the event's shifts and
     *              find the one whose custom_salesforce_shift_id matches the SF shift ID.
     *              Returns the Rosterfy numeric shift ID as a String, or null if not found.
     */
    public static String findShiftBySfId(String remoteEventId, String sfShiftId) {
        ApiResponse res = listShifts(remoteEventId);
        if (!res.isSuccess() || String.isBlank(res.body)) return null;
        try {
            List<Object> shifts = (List<Object>) JSON.deserializeUntyped(res.body);
            for (Object shObj : shifts) {
                Map<String, Object> sh  = (Map<String, Object>) shObj;
                Map<String, Object> obj = sh.containsKey('object') ? (Map<String, Object>) sh.get('object') : sh;
                if (obj == null) continue;
                Object sfId = obj.get('custom_salesforce_shift_id');
                if (sfId != null && String.valueOf(sfId) == sfShiftId) {
                    return String.valueOf(obj.get('id'));
                }
            }
        } catch (Exception e) { /* ignore parse errors */ }
        return null;
    }
}
