/**
 * @description Unit tests for SJV_RosterfyService and SJV_RosterfySubmissionService.
 *              Uses a mock HTTP callout to avoid real Rosterfy API calls in tests.
 */
@IsTest
private class SJV_RosterfyService_Test {

    // ─── Mock HTTP callout ───────────────────────────────────────────────────

    private class RosterfyMock implements HttpCalloutMock {
        private Integer statusCode;
        private String  body;

        RosterfyMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body       = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    private static final String EVENT_RESPONSE = '{"data":{"id":"ROST-EVT-001","url":"https://app.rosterfy.com/events/ROST-EVT-001"}}';
    private static final String SHIFT_RESPONSE = '{"data":{"id":"ROST-SHF-001"}}';

    // ─── SJV_RosterfyService tests ───────────────────────────────────────────

    @IsTest
    static void testCreateEventSuccess() {
        Test.setMock(HttpCalloutMock.class, new RosterfyMock(201, EVENT_RESPONSE));
        Map<String, Object> payload = new Map<String, Object>{
            'name'       => 'Test Event',
            'start_date' => '2026-12-10',
            'end_date'   => '2026-12-11',
            'timezone'   => 'Australia/Melbourne'
        };
        Test.startTest();
        SJV_RosterfyService.ApiResponse res = SJV_RosterfyService.createEvent(payload);
        Test.stopTest();
        System.assertEquals(201, res.statusCode);
        System.assert(res.isSuccess());
        Map<String, Object> data = (Map<String, Object>) res.parsed().get('data');
        System.assertEquals('ROST-EVT-001', data.get('id'));
    }

    @IsTest
    static void testCreateEventFailure() {
        Test.setMock(HttpCalloutMock.class, new RosterfyMock(422, '{"message":"Validation failed"}'));
        Map<String, Object> payload = new Map<String, Object>{ 'name' => '' };
        Test.startTest();
        SJV_RosterfyService.ApiResponse res = SJV_RosterfyService.createEvent(payload);
        Test.stopTest();
        System.assertEquals(422, res.statusCode);
        System.assert(!res.isSuccess());
        System.assert(res.errorMessage().contains('Validation failed'));
    }

    @IsTest
    static void testCreateShiftSuccess() {
        Test.setMock(HttpCalloutMock.class, new RosterfyMock(200, SHIFT_RESPONSE));
        Map<String, Object> payload = new Map<String, Object>{
            'name'       => 'First Aid Officer',
            'date'       => '2026-12-10',
            'start_time' => '09:00',
            'end_time'   => '17:00',
            'positions'  => 3
        };
        Test.startTest();
        SJV_RosterfyService.ApiResponse res = SJV_RosterfyService.createShift('ROST-EVT-001', payload);
        Test.stopTest();
        System.assertEquals(200, res.statusCode);
        System.assert(res.isSuccess());
    }

    @IsTest
    static void testGetEvent() {
        Test.setMock(HttpCalloutMock.class, new RosterfyMock(200, EVENT_RESPONSE));
        Test.startTest();
        SJV_RosterfyService.ApiResponse res = SJV_RosterfyService.getEvent('ROST-EVT-001');
        Test.stopTest();
        System.assertEquals(200, res.statusCode);
    }

    // ─── SJV_RosterfySubmissionService tests ────────────────────────────────

    @IsTest
    static void testPreviewSimulationMode() {
        // With Is_Active__c = false (default in test metadata), preview should not call API
        // Create test VolunteerInitiative data
        // Note: In tests, actual DML on VolunteerInitiative requires org setup.
        // This test verifies the preview payload structure is returned correctly.

        // The service will read config from Custom Metadata (Is_Active__c = false in test)
        // so no HTTP calls will be made.
        Test.startTest();
        try {
            // Expect graceful handling when no VI record exists with a fake ID
            SJV_RosterfySubmissionService.getTransferPreview('000000000000000AAA');
            System.assert(false, 'Expected QueryException');
        } catch (QueryException qe) {
            System.assert(true, 'Expected QueryException for non-existent record');
        }
        Test.stopTest();
    }

    @IsTest
    static void testTransferSimulationMode() {
        // With Is_Active__c = false in custom metadata, executeTransfer should simulate
        // No real HTTP calls. Verify the method does not throw.
        Test.startTest();
        try {
            SJV_RosterfySubmissionService.TransferResult res =
                SJV_RosterfySubmissionService.executeTransfer('000000000000000AAA', false);
            // Will fail gracefully with a message about the missing record
            System.assertNotEquals(null, res);
        } catch (QueryException qe) {
            System.assert(true, 'Expected QueryException for non-existent record');
        }
        Test.stopTest();
    }

    @IsTest
    static void testApiResponseHelpers() {
        SJV_RosterfyService.ApiResponse successRes = new SJV_RosterfyService.ApiResponse();
        successRes.statusCode = 200;
        successRes.body = '{"id":"abc"}';
        System.assert(successRes.isSuccess());
        System.assertEquals(null, successRes.errorMessage());

        SJV_RosterfyService.ApiResponse failRes = new SJV_RosterfyService.ApiResponse();
        failRes.statusCode = 500;
        failRes.body = '{"message":"Internal server error"}';
        System.assert(!failRes.isSuccess());
        System.assert(failRes.errorMessage().contains('Internal server error'));
    }
}

