/**
 * @description UI Controller facade for St John VIC Lightning Web Components.
 *              Provides reactive view models and coordinates actions between LWCs and backend services.
 */
public without sharing class SJV_UIController {

    public class InitiativeViewModel {
        @AuraEnabled public VolunteerInitiative initiative;
        @AuraEnabled public Opportunity opportunity;
        @AuraEnabled public List<SJV_Risk_Assessment__c> assessments;
        @AuraEnabled public SJV_Risk_Assessment__c currentAssessment;
        @AuraEnabled public List<SJV_Risk_Answer__c> answers;
        @AuraEnabled public List<SJV_Resource_Requirement__c> requirements;
        @AuraEnabled public List<JobPosition> jobPositions;
        @AuraEnabled public List<JobPositionShift> shifts;
        @AuraEnabled public String disclaimer;
    }

    public class OpportunityViewModel {
        @AuraEnabled public Opportunity opportunity;
        @AuraEnabled public List<Quote> quotes;
        @AuraEnabled public Quote acceptedQuote;
        @AuraEnabled public List<SJV_Quote_Acceptance__c> acceptanceHistory;
        @AuraEnabled public VolunteerInitiative initiative;
        @AuraEnabled public Boolean gateAcceptedQuote;
        @AuraEnabled public Boolean gateClinicalReview;
        @AuraEnabled public Boolean gateOperationsReview;
        @AuraEnabled public Boolean gateCreditClearance;
        @AuraEnabled public Boolean allGatesPassed;
    }

    public class LeadEnquiryViewModel {
        @AuraEnabled public Lead lead;
    }

    @AuraEnabled(cacheable=false)
    public static LeadEnquiryViewModel getLeadEnquiryData(Id leadId) {
        LeadEnquiryViewModel vm = new LeadEnquiryViewModel();
        vm.lead = [
            SELECT Id, Name, FirstName, LastName, Email, Phone, Company, Status,
                   Title, LeadSource, Description, Street, City, State, PostalCode,
                   IsConverted, ConvertedOpportunityId, ConvertedAccountId, ConvertedContactId,
                   SJV_Event_Name__c, SJV_Event_Type__c, SJV_Expected_Attendance__c,
                   SJV_Start_Date__c, SJV_End_Date__c, SJV_Daily_Hours_Description__c,
                   SJV_Venue_Name__c, SJV_Indoor_Outdoor__c, SJV_Alcohol_Present__c,
                   SJV_High_Risk_Activities__c, SJV_First_Aid_Post_Available__c,
                   SJV_Customer_Role__c, SJV_Previous_Customer__c,
                   SJV_Event_Day_Contact_Name__c, SJV_Event_Day_Contact_Phone__c,
                   SJV_Requested_Coverage_Notes__c, SJV_Setup_Access_Instructions__c,
                   SJV_Is_Multi_Day__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        return vm;
    }

    @AuraEnabled(cacheable=false)
    public static InitiativeViewModel getInitiativeData(Id recordId) {
        // Backward‑compatible wrapper for legacy calls (e.g., unit tests)
        // Calls the new two‑parameter method with initiativeId set to null.
        return getInitiativeData(recordId, null);
    }

        public static InitiativeViewModel getInitiativeData(Id recordId, Id initiativeId) {
        InitiativeViewModel vm = new InitiativeViewModel();
        vm.disclaimer = SJV_RiskAssessmentService.DISCLAIMER;

        Id oppId = null;
        Id initId = null;

        Id targetId = (recordId != null) ? recordId : initiativeId;
        if (targetId == null) {
            return vm;
        }
        String sObjType = targetId.getSobjectType().getDescribe().getName();
        if (sObjType == 'Opportunity') {
            oppId = recordId;
            vm.opportunity = [
                SELECT Id, Name, StageName, IsWon, Amount, SJV_Internal_Cost__c,
                       SJV_Estimated_Margin__c, SJV_Accepted_Quote__c,
                       SJV_Clinical_Review_Status__c, SJV_Operations_Review_Status__c,
                       SJV_Credit_Review_Status__c, SJV_Handoff_Readiness__c,
                       SJV_Volunteer_Initiative__c
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
            if (vm.opportunity.SJV_Volunteer_Initiative__c != null) {
                initId = vm.opportunity.SJV_Volunteer_Initiative__c;
            } else {
                List<VolunteerInitiative> existingInits = [
                    SELECT Id FROM VolunteerInitiative WHERE SJV_Opportunity__c = :oppId ORDER BY CreatedDate ASC LIMIT 1
                ];
                if (!existingInits.isEmpty()) {
                    initId = existingInits[0].Id;
                }
            }
        } else {
            initId = targetId;
        }

        if (initId != null) {
            vm.initiative = [
                SELECT Id, Name, StartDate, EndDate, Status, SJV_Opportunity__c,
                       SJV_Operational_Contact__c, SJV_Operational_Contact__r.Name,
                       SJV_Timezone__c, SJV_Venue_Instructions__c, SJV_Source_Event_Key__c,
                       SJV_Sync_State__c, SJV_Current_Approved_Assessment__c,
                       SJV_Approved_Plan_Revision__c, SJV_Remote_Event_Id__c,
                       SJV_Last_Sent_Time__c,
                       ParentVolunteerInitiativeId, ParentVolunteerInitiative.Name
                FROM VolunteerInitiative
                WHERE Id = :initId
                LIMIT 1
            ];
            if (oppId == null && vm.initiative.SJV_Opportunity__c != null) {
                oppId = vm.initiative.SJV_Opportunity__c;
                vm.opportunity = [
                    SELECT Id, Name, StageName, IsWon, Amount, SJV_Internal_Cost__c,
                           SJV_Estimated_Margin__c, SJV_Accepted_Quote__c,
                           SJV_Clinical_Review_Status__c, SJV_Operations_Review_Status__c,
                           SJV_Credit_Review_Status__c, SJV_Handoff_Readiness__c
                    FROM Opportunity
                    WHERE Id = :oppId
                    LIMIT 1
                ];
            }
        }

        if (initId != null && oppId != null) {
            vm.assessments = [
                SELECT Id, Name, Version_Number__c, Unique_Version_Key__c, Status__c,
                       Reason_For_Change__c, Total_Risk_Score__c, Risk_Band__c,
                       Proposed_Staff_Count__c, Proposed_Staff_Hours__c,
                       Estimated_Internal_Cost__c, Estimated_Selling_Price__c,
                       Reviewer_Decision__c, Reviewer__r.Name, Reviewed_Date_Time__c,
                       Rule_Set_Version__c, Rule_Set_Disclaimer__c
                FROM SJV_Risk_Assessment__c
                WHERE Volunteer_Initiative__c = :initId OR Opportunity__c = :oppId
                ORDER BY Version_Number__c DESC
            ];
        } else if (initId != null) {
            vm.assessments = [
                SELECT Id, Name, Version_Number__c, Unique_Version_Key__c, Status__c,
                       Reason_For_Change__c, Total_Risk_Score__c, Risk_Band__c,
                       Proposed_Staff_Count__c, Proposed_Staff_Hours__c,
                       Estimated_Internal_Cost__c, Estimated_Selling_Price__c,
                       Reviewer_Decision__c, Reviewer__r.Name, Reviewed_Date_Time__c,
                       Rule_Set_Version__c, Rule_Set_Disclaimer__c
                FROM SJV_Risk_Assessment__c
                WHERE Volunteer_Initiative__c = :initId
                ORDER BY Version_Number__c DESC
            ];
        } else if (oppId != null) {
            vm.assessments = [
                SELECT Id, Name, Version_Number__c, Unique_Version_Key__c, Status__c,
                       Reason_For_Change__c, Total_Risk_Score__c, Risk_Band__c,
                       Proposed_Staff_Count__c, Proposed_Staff_Hours__c,
                       Estimated_Internal_Cost__c, Estimated_Selling_Price__c,
                       Reviewer_Decision__c, Reviewer__r.Name, Reviewed_Date_Time__c,
                       Rule_Set_Version__c, Rule_Set_Disclaimer__c
                FROM SJV_Risk_Assessment__c
                WHERE Opportunity__c = :oppId
                ORDER BY Version_Number__c DESC
            ];
        } else {
            vm.assessments = new List<SJV_Risk_Assessment__c>();
        }

        if (!vm.assessments.isEmpty()) {
            Id activeAssessmentId = (vm.initiative != null && vm.initiative.SJV_Current_Approved_Assessment__c != null) ?
                vm.initiative.SJV_Current_Approved_Assessment__c : vm.assessments[0].Id;

            for (SJV_Risk_Assessment__c ra : vm.assessments) {
                if (ra.Id == activeAssessmentId) {
                    vm.currentAssessment = ra;
                    break;
                }
            }
            if (vm.currentAssessment == null) {
                vm.currentAssessment = vm.assessments[0];
            }

            vm.answers = [
                SELECT Id, Question_Key__c, Question_Text__c, Question_Category__c,
                       Answer_Value__c, Score_Contribution__c, Scoring_Explanation__c
                FROM SJV_Risk_Answer__c
                WHERE Risk_Assessment__c = :vm.currentAssessment.Id
                ORDER BY Question_Category__c, Question_Key__c
            ];

            vm.requirements = [
                SELECT Id, Requirement_Key__c, Category__c, Role_or_Item_Code__c,
                       Role_or_Item_Name__c, Quantity__c, Service_Date__c,
                       Duration_Hours__c, Total_Staff_Hours__c, Demand_Type__c,
                       Internal_Cost_Rate__c, Selling_Rate__c, Internal_Cost_Total__c,
                       Selling_Price_Total__c, Billable_Units__c, Unit_Basis__c
                FROM SJV_Resource_Requirement__c
                WHERE Risk_Assessment__c = :vm.currentAssessment.Id
                ORDER BY Category__c DESC, Role_or_Item_Name__c ASC
            ];
        } else {
            vm.answers = new List<SJV_Risk_Answer__c>();
            vm.requirements = new List<SJV_Resource_Requirement__c>();
        }

        if (initId != null) {
            vm.jobPositions = [
                SELECT Id, Name, Title, Status, PositionId, Position.Name,
                       SJV_Source_Job_Key__c, SJV_Role_Mapping_Key__c
                FROM JobPosition
                WHERE VolunteerInitiativeId = :initId
            ];

            vm.shifts = [
                SELECT Id, JobPositionId, JobPosition.Title, StartDate, EndDate,
                       StartTime, EndTime, MaximumAttendeesCount, Status,
                       SJV_Source_Shift_Key__c, SJV_Remote_Shift_Id__c, SJV_Sync_Status__c
                FROM JobPositionShift
                WHERE JobPosition.VolunteerInitiativeId = :initId
                ORDER BY StartDate, StartTime
            ];
        } else {
            vm.jobPositions = new List<JobPosition>();
            vm.shifts = new List<JobPositionShift>();
        }

        return vm;
    }

    @AuraEnabled(cacheable=false)
    public static OpportunityViewModel getOpportunityData(Id oppId) {
        OpportunityViewModel vm = new OpportunityViewModel();

        vm.opportunity = [
            SELECT Id, Name, StageName, IsWon, Amount, SJV_Internal_Cost__c,
                   SJV_Estimated_Margin__c, SJV_Accepted_Quote__c,
                   SJV_Clinical_Review_Status__c, SJV_Operations_Review_Status__c,
                   SJV_Credit_Review_Status__c, SJV_Handoff_Readiness__c,
                   SJV_Volunteer_Initiative__c, AccountId, Account.Name
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        if (vm.opportunity.SJV_Volunteer_Initiative__c != null) {
            vm.initiative = [
                SELECT Id, Name, StartDate, EndDate, Status, SJV_Sync_State__c,
                       SJV_Remote_Event_Id__c, SJV_Approved_Plan_Revision__c
                FROM VolunteerInitiative
                WHERE Id = :vm.opportunity.SJV_Volunteer_Initiative__c
                LIMIT 1
            ];
        }

        vm.quotes = [
            SELECT Id, Name, QuoteNumber, GrandTotal, Status, SJV_Acceptance_Status__c,
                   SJV_Internal_Cost_Total__c, SJV_Gross_Margin_Amount__c,
                   SJV_Gross_Margin_Percent__c, SJV_Assessment_Set_Snapshot__c, CreatedDate
            FROM Quote
            WHERE OpportunityId = :oppId
            ORDER BY CreatedDate DESC
        ];

        if (vm.opportunity.SJV_Accepted_Quote__c != null) {
            for (Quote q : vm.quotes) {
                if (q.Id == vm.opportunity.SJV_Accepted_Quote__c) {
                    vm.acceptedQuote = q;
                    break;
                }
            }
        }

        vm.acceptanceHistory = [
            SELECT Id, Name, Quote__c, Quote__r.Name, Customer_Contact__c, Customer_Contact__r.Name,
                   Received_Date_Time__c, Acceptance_Method__c, Evidence_Reference__c,
                   Accepted_Amount__c, Recorded_By__r.Name, Notes__c
            FROM SJV_Quote_Acceptance__c
            WHERE Opportunity__c = :oppId
            ORDER BY Received_Date_Time__c DESC
        ];

        // Evaluate Gates
        vm.gateAcceptedQuote = (vm.opportunity.SJV_Accepted_Quote__c != null &&
                                vm.acceptedQuote != null &&
                                vm.acceptedQuote.SJV_Acceptance_Status__c == 'Accepted');
        vm.gateClinicalReview = (vm.opportunity.SJV_Clinical_Review_Status__c == 'Approved');
        vm.gateOperationsReview = (vm.opportunity.SJV_Operations_Review_Status__c == 'Approved');
        vm.gateCreditClearance = (vm.opportunity.SJV_Credit_Review_Status__c != 'Warning / On Hold');
        vm.allGatesPassed = (vm.gateAcceptedQuote && vm.gateClinicalReview && vm.gateOperationsReview && vm.gateCreditClearance);

        return vm;
    }

    /**
     * @description Accepts individual scalar parameters from LWC (most reliable pattern —
     *              avoids any object-deserialization issues with cross-class inner types).
     */
    @AuraEnabled
    public static SJV_RiskAssessmentService.AssessmentResult calculateAssessment(
            String initiativeId,
            Integer expectedAttendance,
            String indoorOutdoor,
            String alcoholPresent,
            String highRiskActivities,
            String firstAidPostNeeded,
            Decimal durationHours,
            String reasonForChange,
            Boolean submitForReview) {

        if (String.isBlank(initiativeId)) {
            SJV_RiskAssessmentService.AssessmentResult err = new SJV_RiskAssessmentService.AssessmentResult();
            err.success = false;
            err.message = 'Initiative or Opportunity ID is required.';
            return err;
        }
        SJV_RiskAssessmentService.AssessmentInput inp = new SJV_RiskAssessmentService.AssessmentInput();
        inp.initiativeId       = (Id) initiativeId;
        inp.expectedAttendance = expectedAttendance;
        inp.indoorOutdoor      = indoorOutdoor;
        inp.alcoholPresent     = alcoholPresent;
        inp.highRiskActivities = highRiskActivities;
        inp.firstAidPostNeeded = firstAidPostNeeded;
        inp.durationHours      = durationHours;
        inp.reasonForChange    = reasonForChange;
        inp.submitForReview    = submitForReview;
        return SJV_RiskAssessmentService.calculateAndSaveAssessment(inp);
    }

    @AuraEnabled
    public static SJV_RiskAssessmentService.AssessmentResult approveAssessment(Id assessmentId, String comments) {
        return SJV_RiskAssessmentService.approveAssessment(assessmentId, comments);
    }

    @AuraEnabled
    public static SJV_DemandAndQuoteService.DemandResult generateOperationalDemand(Id assessmentId) {
        return SJV_DemandAndQuoteService.generateOperationalDemand(assessmentId);
    }

    @AuraEnabled
    public static SJV_DemandAndQuoteService.QuoteResult generateQuote(Id assessmentId) {
        return SJV_DemandAndQuoteService.generateQuote(assessmentId);
    }

    @AuraEnabled
    public static SJV_QuoteAcceptanceService.AcceptanceResult recordQuoteAcceptance(
            String quoteId,
            String contactId,
            String acceptanceMethod,
            String evidenceReference,
            String notes) {

        SJV_QuoteAcceptanceService.AcceptanceRequest req = new SJV_QuoteAcceptanceService.AcceptanceRequest();
        req.quoteId            = String.isNotBlank(quoteId) ? (Id) quoteId : null;
        req.contactId          = String.isNotBlank(contactId) ? (Id) contactId : null;
        req.acceptanceMethod   = acceptanceMethod;
        req.evidenceReference  = evidenceReference;
        req.notes              = notes;
        return SJV_QuoteAcceptanceService.recordAcceptance(req);
    }

    @AuraEnabled
    public static SJV_QuoteAcceptanceService.CloseWonResult closeOpportunityWon(Id oppId) {
        return SJV_QuoteAcceptanceService.closeOpportunityWon(oppId);
    }

    @AuraEnabled(cacheable=false)
    public static Boolean isRosterfyIntegrationActive() {
        return SJV_RosterfyService.isActive();
    }

    @AuraEnabled
    public static SJV_RosterfySubmissionService.PreviewPayload getRosterfyPreview(Id initiativeId) {
        return SJV_RosterfySubmissionService.getTransferPreview(initiativeId);
    }

    @AuraEnabled
    public static SJV_RosterfySubmissionService.TransferResult executeRosterfyTransfer(Id initiativeId, Boolean simulatePartialFailure) {
        return SJV_RosterfySubmissionService.executeTransfer(initiativeId, simulatePartialFailure);
    }
}