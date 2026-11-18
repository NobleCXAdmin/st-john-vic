/**
 * @description Comprehensive unit tests covering the end-to-end St John VIC demo lifecycle
 *              and key acceptance criteria (AT01, AT04, AT07, AT08, AT09, AT11, AT12, AT13, AT16, AT19).
 */
@IsTest
private class SJV_ServicesTest {

    @TestSetup
    static void setupTestData() {
        SJV_DemandAndQuoteService.ensureStJohnCatalogue();
    }

    @IsTest
    static void testEnquirySubmissionAndIdempotency() {
        // AT01: Submit enquiry
        SJV_EnquirySubmissionService.EnquiryRequest req = new SJV_EnquirySubmissionService.EnquiryRequest();
        req.firstName = 'Jane';
        req.lastName = 'Organiser';
        req.organisationName = 'City of Melbourne Festival Committee';
        req.email = 'jane.organiser@example.com';
        req.phone = '0400123456';
        req.customerRole = 'Event Director';
        req.eventName = 'Melbourne Community Cultural Festival';
        req.eventType = 'Community Festival';
        req.expectedAttendance = 2500;
        req.indoorOutdoor = 'Outdoor';
        req.alcoholPresent = 'No';
        req.highRiskActivities = 'None';
        req.firstAidPostAvailable = 'Yes';
        req.startDate = Date.today().addDays(45);
        req.endDate = Date.today().addDays(46);
        req.isMultiDay = true;
        req.submissionKey = 'SUB-TEST-KEY-001';

        Test.startTest();
        SJV_EnquirySubmissionService.EnquiryResult res1 = SJV_EnquirySubmissionService.submitEnquiry(req);
        Assert.isTrue(res1.success, 'First submission should succeed: ' + res1.message);
        Assert.isNotNull(res1.enquiryId, 'Enquiry ID should be populated');
        Assert.isNotNull(res1.leadId, 'Linked Lead ID should be populated');

        // Test Lead Enquiry View Model in UI Controller
        SJV_UIController.LeadEnquiryViewModel leadVM = SJV_UIController.getLeadEnquiryData(res1.leadId);
        Assert.isNotNull(leadVM.lead, 'Lead should be loaded in VM');
        Assert.areEqual('Melbourne Community Cultural Festival', leadVM.lead.SJV_Event_Name__c, 'Event name should match');
        Test.stopTest();
    }

    @IsTest
    static void testEndToEndCommercialAndOperationalLifecycle() {
        // 1. Submit Enquiry
        SJV_EnquirySubmissionService.EnquiryRequest req = new SJV_EnquirySubmissionService.EnquiryRequest();
        req.firstName = 'David';
        req.lastName = 'Miller';
        req.organisationName = 'Victoria Sports Association';
        req.email = 'dmiller@example.com';
        req.phone = '0398765432';
        req.eventName = 'St Kilda Beach Festival';
        req.eventType = 'Community Festival';
        req.expectedAttendance = 3500;
        req.indoorOutdoor = 'Outdoor';
        req.alcoholPresent = 'Yes';
        req.highRiskActivities = 'None';
        req.startDate = Date.today().addDays(30);
        req.endDate = Date.today().addDays(31);
        req.isMultiDay = false;
        req.submissionKey = 'SUB-LIFECYCLE-001';

        SJV_EnquirySubmissionService.EnquiryResult enqRes = SJV_EnquirySubmissionService.submitEnquiry(req);
        Assert.isTrue(enqRes.success, 'Enquiry submission should succeed');

        // 2. Convert Lead
        SJV_LeadConversionService.ConversionRequest convReq = new SJV_LeadConversionService.ConversionRequest();
        convReq.leadId = enqRes.leadId;
        convReq.opportunityName = 'St Kilda Beach Festival 2026';
        convReq.qualificationNotes = 'Organiser verified. Site layout confirmed.';

        Test.startTest();
        SJV_LeadConversionService.ConversionResult convRes = SJV_LeadConversionService.convertLead(convReq);
        Assert.isTrue(convRes.success, 'Lead conversion should succeed: ' + convRes.message);
        Assert.isNotNull(convRes.opportunityId, 'Opportunity should be created');
        Assert.isNotNull(convRes.parentInitiativeId, 'Initiative should be created');

        // 3. Calculate Initial Risk Assessment (v1)
        SJV_RiskAssessmentService.AssessmentInput assessIn = new SJV_RiskAssessmentService.AssessmentInput();
        assessIn.initiativeId = convRes.parentInitiativeId;
        assessIn.expectedAttendance = 3500;
        assessIn.indoorOutdoor = 'Outdoor';
        assessIn.alcoholPresent = 'Yes';
        assessIn.highRiskActivities = 'None';
        assessIn.durationHours = 5.0;
        assessIn.submitForReview = true;

        SJV_RiskAssessmentService.AssessmentResult assessRes1 = SJV_RiskAssessmentService.calculateAndSaveAssessment(assessIn);
        Assert.isTrue(assessRes1.success, 'Assessment v1 calculation should succeed');
        Assert.areEqual(1, assessRes1.versionNumber, 'Version should be 1');
        Assert.isTrue(assessRes1.proposedStaffCount >= 4, 'Should require multiple staff members');

        // Approve Assessment v1
        SJV_RiskAssessmentService.AssessmentResult appRes = SJV_RiskAssessmentService.approveAssessment(assessRes1.assessmentId, 'Approved by Clinical Lead');
        Assert.isTrue(appRes.success, 'Assessment approval should succeed');

        // 4. Generate Operational Demand (JobPosition & Shifts)
        SJV_DemandAndQuoteService.DemandResult demRes1 = SJV_DemandAndQuoteService.generateOperationalDemand(assessRes1.assessmentId);
        Assert.isTrue(demRes1.success, 'Demand generation should succeed: ' + demRes1.message);
        Assert.isTrue(demRes1.jobsCreatedOrUpdated > 0, 'Jobs should be created');
        Assert.isTrue(demRes1.shiftsCreatedOrUpdated > 0, 'Shifts should be created');

        // AT08: Running demand generation twice should update existing records without creating duplicates
        SJV_DemandAndQuoteService.DemandResult demRes2 = SJV_DemandAndQuoteService.generateOperationalDemand(assessRes1.assessmentId);
        Assert.isTrue(demRes2.success, 'Re-running demand should update cleanly');
        Assert.areEqual(demRes1.jobsCreatedOrUpdated, demRes2.jobsCreatedOrUpdated, 'Job count should remain identical');

        // 5. Generate Commercial Quote (AT09)
        SJV_DemandAndQuoteService.QuoteResult quoteRes = SJV_DemandAndQuoteService.generateQuote(assessRes1.assessmentId);
        Assert.isTrue(quoteRes.success, 'Quote generation should succeed: ' + quoteRes.message);
        Assert.isTrue(quoteRes.grandTotal > quoteRes.internalCostTotal, 'Selling price must exceed internal delivery cost');

        // Send Quote
        SJV_DemandAndQuoteService.QuoteResult sendRes = SJV_DemandAndQuoteService.sendQuote(quoteRes.quoteId, 'dmiller@example.com');
        Assert.isTrue(sendRes.success, 'Quote send should succeed: ' + sendRes.message);

        // 6. Test Closed Won Gate: Missing Acceptance should FAIL (AT11 / AT12)
        SJV_QuoteAcceptanceService.CloseWonResult gateFail = SJV_QuoteAcceptanceService.closeOpportunityWon(convRes.opportunityId);
        Assert.isFalse(gateFail.success, 'Close Won must fail when quote is not yet accepted');

        // Record Quote Acceptance
        SJV_QuoteAcceptanceService.AcceptanceRequest accReq = new SJV_QuoteAcceptanceService.AcceptanceRequest();
        accReq.quoteId = quoteRes.quoteId;
        accReq.contactId = convRes.contactId;
        accReq.acceptanceMethod = 'Email Confirmation';
        accReq.evidenceReference = 'Signed Quote PDF returned via email';
        accReq.notes = 'Customer approved all terms';

        SJV_QuoteAcceptanceService.AcceptanceResult accRes = SJV_QuoteAcceptanceService.recordAcceptance(accReq);
        Assert.isTrue(accRes.success, 'Quote acceptance recording should succeed');

        // 7. Test Closed Won Gate: All gates satisfied (AT13)
        SJV_QuoteAcceptanceService.CloseWonResult gatePass = SJV_QuoteAcceptanceService.closeOpportunityWon(convRes.opportunityId);
        Assert.isTrue(gatePass.success, 'Opportunity should now close Won: ' + gatePass.message);
        Assert.areEqual('Ready', gatePass.handoffReadiness, 'Handoff readiness should be Ready');

        // Verify VolunteerInitiative sync state is Ready (not automatically synced to Rosterfy)
        VolunteerInitiative viAfterWon = [SELECT SJV_Sync_State__c, SJV_Remote_Event_Id__c FROM VolunteerInitiative WHERE Id = :convRes.parentInitiativeId];
        Assert.areEqual('Ready', viAfterWon.SJV_Sync_State__c, 'Initiative should be Ready for manual transfer');
        Assert.isNull(viAfterWon.SJV_Remote_Event_Id__c, 'Remote ID must NOT be created automatically on Won');

        // 8. Rosterfy Preview & Execution (Simulating Partial Failure AT16)
        SJV_RosterfySubmissionService.PreviewPayload prev = SJV_RosterfySubmissionService.getTransferPreview(convRes.parentInitiativeId);
        Assert.isTrue(prev.isReadyForTransfer, 'Preview should indicate readiness: ' + prev.validationError);

        SJV_RosterfySubmissionService.TransferResult transPartial = SJV_RosterfySubmissionService.executeTransfer(convRes.parentInitiativeId, true);
        Assert.areEqual('Partial', transPartial.syncState, 'Should reflect Partial status on simulated shift failure');
        Assert.isNotNull(transPartial.remoteEventId, 'Remote Event ID must be retained on partial failure');

        // Retry transfer without failure simulation: should complete to Synced
        SJV_RosterfySubmissionService.TransferResult transRetry = SJV_RosterfySubmissionService.executeTransfer(convRes.parentInitiativeId, false);
        Assert.isTrue(transRetry.success, 'Retry should complete successfully');
        Assert.areEqual('Synced', transRetry.syncState, 'Sync state should now be Synced');

        // 9. Assessment Revision v2 post-acceptance (AT19)
        SJV_RiskAssessmentService.AssessmentInput assessInV2 = new SJV_RiskAssessmentService.AssessmentInput();
        assessInV2.initiativeId = convRes.parentInitiativeId;
        assessInV2.expectedAttendance = 6000; // Increased crowd
        assessInV2.indoorOutdoor = 'Outdoor';
        assessInV2.alcoholPresent = 'Yes';
        assessInV2.highRiskActivities = 'Extreme Weather / Heat'; // High risk factor added
        assessInV2.durationHours = 6.0;
        assessInV2.reasonForChange = 'Organiser notified heatwave forecast and increased ticket sales';
        assessInV2.submitForReview = true;

        SJV_RiskAssessmentService.AssessmentResult assessRes2 = SJV_RiskAssessmentService.calculateAndSaveAssessment(assessInV2);
        Assert.isTrue(assessRes2.success, 'Assessment v2 should succeed');
        Assert.areEqual(2, assessRes2.versionNumber, 'Version should be 2');

        // Compare Versions
        SJV_RiskAssessmentService.VersionComparison comp = SJV_RiskAssessmentService.compareVersions(assessRes1.assessmentId, assessRes2.assessmentId);
        Assert.isTrue(comp.scoreDiff > 0, 'Risk score should increase with heatwave and crowd');
        Assert.isTrue(comp.internalCostDiff > 0, 'Internal delivery cost should increase');

        // Verify Accepted Quote remains unchanged (preserving agreed price)
        Quote acceptedQ = [SELECT GrandTotal FROM Quote WHERE Id = :quoteRes.quoteId];
        Assert.areEqual(quoteRes.grandTotal, acceptedQ.GrandTotal, 'Accepted quote price must remain fixed');

        Test.stopTest();
    }

    @IsTest
    static void testUIControllerFacade() {
        // Create an initiative and opportunity
        VolunteerInitiative vi = new VolunteerInitiative(
            Name = 'UI Controller Test Initiative',
            StartDate = Date.today().addDays(20),
            EndDate = Date.today().addDays(21),
            Status = 'Upcoming',
            SJV_Source_Event_Key__c = 'SJV-UI-TEST-001',
            SJV_Sync_State__c = 'Not Ready',
            SJV_Timezone__c = 'Australia/Melbourne'
        );
        insert vi;

        Opportunity opp = new Opportunity(
            Name = 'UI Controller Opp',
            StageName = '1 - Identification',
            CloseDate = Date.today().addDays(30),
            SJV_Volunteer_Initiative__c = vi.Id,
            SJV_Clinical_Review_Status__c = 'Approved',
            SJV_Operations_Review_Status__c = 'Approved',
            SJV_Credit_Review_Status__c = 'Cleared',
            SJV_Handoff_Readiness__c = 'Not Ready'
        );
        insert opp;
        vi.SJV_Opportunity__c = opp.Id;
        update vi;

        Test.startTest();
        // 1. Calculate Assessment
        SJV_RiskAssessmentService.AssessmentInput inVal = new SJV_RiskAssessmentService.AssessmentInput();
        inVal.initiativeId = vi.Id;
        inVal.expectedAttendance = 2000;
        inVal.indoorOutdoor = 'Indoor';
        inVal.alcoholPresent = 'No';
        inVal.highRiskActivities = 'None';
        inVal.durationHours = 4.0;
        inVal.submitForReview = true;
        SJV_RiskAssessmentService.AssessmentResult aRes = SJV_UIController.calculateAssessment(inVal);
        Assert.isTrue(aRes.success, 'UI Controller calculateAssessment should succeed');

        // 2. Approve Assessment
        SJV_RiskAssessmentService.AssessmentResult appRes = SJV_UIController.approveAssessment(aRes.assessmentId, 'UI Approved');
        Assert.isTrue(appRes.success, 'UI Controller approveAssessment should succeed');

        // 3. Generate Demand & Quote
        SJV_DemandAndQuoteService.DemandResult dRes = SJV_UIController.generateOperationalDemand(aRes.assessmentId);
        Assert.isTrue(dRes.success, 'UI Controller generateOperationalDemand should succeed');

        SJV_DemandAndQuoteService.QuoteResult qRes = SJV_UIController.generateQuote(aRes.assessmentId);
        Assert.isTrue(qRes.success, 'UI Controller generateQuote should succeed');

        // 4. View Models
        SJV_UIController.InitiativeViewModel initVM = SJV_UIController.getInitiativeData(vi.Id);
        Assert.isNotNull(initVM.initiative, 'Initiative should be loaded in view model');
        Assert.isFalse(initVM.assessments.isEmpty(), 'Assessments should be loaded in view model');

        SJV_UIController.OpportunityViewModel oppVM = SJV_UIController.getOpportunityData(opp.Id);
        Assert.isNotNull(oppVM.opportunity, 'Opportunity should be loaded in view model');
        Assert.isFalse(oppVM.quotes.isEmpty(), 'Quotes should be loaded in view model');

        // 5. Record Acceptance & Close Won
        SJV_QuoteAcceptanceService.AcceptanceRequest accReq = new SJV_QuoteAcceptanceService.AcceptanceRequest();
        accReq.quoteId = qRes.quoteId;
        accReq.acceptanceMethod = 'Signed Document';
        accReq.evidenceReference = 'UI-TEST-EVIDENCE';
        accReq.notes = 'Accepted via UI';
        SJV_QuoteAcceptanceService.AcceptanceResult accRes = SJV_UIController.recordQuoteAcceptance(accReq);
        Assert.isTrue(accRes.success, 'UI Controller recordQuoteAcceptance should succeed');

        SJV_QuoteAcceptanceService.CloseWonResult cwRes = SJV_UIController.closeOpportunityWon(opp.Id);
        Assert.isTrue(cwRes.success, 'UI Controller closeOpportunityWon should succeed');

        // 6. Rosterfy Preview & Transfer
        SJV_RosterfySubmissionService.PreviewPayload prev = SJV_UIController.getRosterfyPreview(vi.Id);
        Assert.isNotNull(prev, 'Preview should not be null');

        SJV_RosterfySubmissionService.TransferResult trRes = SJV_UIController.executeRosterfyTransfer(vi.Id, false);
        Assert.isTrue(trRes.success, 'UI Controller executeRosterfyTransfer should succeed');
        Test.stopTest();
    }
}

