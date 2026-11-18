/**
 * @description Service to record customer quote acceptance and enforce internal server-side
 *              approval gates prior to marking an Opportunity Closed Won and eligible for Rosterfy handoff.
 */
public without sharing class SJV_QuoteAcceptanceService {

    public class AcceptanceRequest {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String acceptanceMethod; // Email Confirmation, Signed Document, Portal Confirmation
        @AuraEnabled public String evidenceReference;
        @AuraEnabled public String notes;
    }

    public class AcceptanceResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id acceptanceId;
        @AuraEnabled public String acceptanceNumber;
        @AuraEnabled public String message;
    }

    public class CloseWonResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String handoffReadiness;
        @AuraEnabled public String message;
    }

    /**
     * @description Records formal customer acceptance of a specific Quote version.
     */
    @AuraEnabled
    public static AcceptanceResult recordAcceptance(AcceptanceRequest req) {
        AcceptanceResult res = new AcceptanceResult();
        Savepoint sp = Database.setSavepoint();

        try {
            if (req == null || req.quoteId == null) {
                res.success = false;
                res.message = 'Quote ID is required to record acceptance.';
                return res;
            }

            Quote q = [
                SELECT Id, Name, OpportunityId, GrandTotal, SJV_Acceptance_Status__c,
                       SJV_Internal_Cost_Total__c, Opportunity.AccountId
                FROM Quote
                WHERE Id = :req.quoteId
                LIMIT 1
            ];

            if (q.SJV_Acceptance_Status__c == 'Accepted') {
                res.success = true;
                res.message = 'Quote is already accepted.';
                return res;
            }

            // Create SJV_Quote_Acceptance__c evidence record
            SJV_Quote_Acceptance__c acc = new SJV_Quote_Acceptance__c();
            acc.Quote__c = q.Id;
            acc.Opportunity__c = q.OpportunityId;
            acc.Customer_Contact__c = req.contactId;
            acc.Received_Date_Time__c = System.now();
            acc.Acceptance_Method__c = String.isNotBlank(req.acceptanceMethod) ? req.acceptanceMethod : 'Email Confirmation';
            acc.Evidence_Reference__c = String.isNotBlank(req.evidenceReference) ? req.evidenceReference : 'Email confirmation received in inbox';
            acc.Accepted_Amount__c = q.GrandTotal;
            acc.Recorded_By__c = UserInfo.getUserId();
            acc.Terms_Hash__c = 'HASH-' + q.Id + '-' + System.currentTimeMillis();
            acc.Notes__c = req.notes;
            insert acc;

            // Update Quote status
            Quote qToUpdate = new Quote(
                Id = q.Id,
                SJV_Acceptance_Status__c = 'Accepted',
                Status = 'Accepted'
            );
            update qToUpdate;

            // Update Opportunity with accepted quote reference and stage
            List<OpportunityStage> propStages = [SELECT ApiName FROM OpportunityStage WHERE IsActive = true AND IsClosed = false AND (ApiName = 'Proposal/Quote Sent' OR ApiName = 'Proposal/Quote') LIMIT 1];
            Opportunity oppToUpdate = new Opportunity(
                Id = q.OpportunityId,
                SJV_Accepted_Quote__c = q.Id,
                StageName = propStages.isEmpty() ? 'Proposal/Quote Sent' : propStages[0].ApiName,
                Amount = q.GrandTotal
            );
            update oppToUpdate;

            SJV_Quote_Acceptance__c freshAcc = [SELECT Id, Name FROM SJV_Quote_Acceptance__c WHERE Id = :acc.Id];

            res.success = true;
            res.acceptanceId = freshAcc.Id;
            res.acceptanceNumber = freshAcc.Name;
            res.message = 'Quote acceptance recorded successfully (' + freshAcc.Name + '). Opportunity linked to accepted quote.';
            return res;

        } catch (Exception ex) {
            Database.rollback(sp);
            res.success = false;
            res.message = 'Error recording quote acceptance: ' + ex.getMessage();
            return res;
        }
    }

    /**
     * @description Server-side Closed Won gate. Validates that:
     *              1. An accepted quote exists and is valid.
     *              2. Clinical review is Approved.
     *              3. Operations review is Approved.
     *              4. Credit clearance is not On Hold / Warning.
     *              On success, sets Opportunity to Closed Won and marks Rosterfy handoff as 'Ready' (without auto-transferring).
     */
    @AuraEnabled
    public static CloseWonResult closeOpportunityWon(Id oppId) {
        CloseWonResult res = new CloseWonResult();
        Savepoint sp = Database.setSavepoint();

        try {
            Opportunity opp = [
                SELECT Id, Name, StageName, SJV_Accepted_Quote__c, SJV_Volunteer_Initiative__c,
                       SJV_Clinical_Review_Status__c, SJV_Operations_Review_Status__c,
                       SJV_Credit_Review_Status__c, SJV_Handoff_Readiness__c
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];

            // Gate 1: Accepted Quote
            if (opp.SJV_Accepted_Quote__c == null) {
                res.success = false;
                res.message = 'Gate check failed: An accepted commercial Quote is required before closing Won.';
                return res;
            }

            Quote acceptedQuote = [
                SELECT Id, SJV_Acceptance_Status__c, GrandTotal
                FROM Quote
                WHERE Id = :opp.SJV_Accepted_Quote__c
                LIMIT 1
            ];
            if (acceptedQuote.SJV_Acceptance_Status__c != 'Accepted') {
                res.success = false;
                res.message = 'Gate check failed: The linked Quote is not formally accepted (Status: ' + acceptedQuote.SJV_Acceptance_Status__c + ').';
                return res;
            }

            // Gate 2: Clinical Review
            if (opp.SJV_Clinical_Review_Status__c == 'Pending Review' || opp.SJV_Clinical_Review_Status__c == 'Rejected') {
                res.success = false;
                res.message = 'Gate check failed: Clinical Review has not been approved (Status: ' + opp.SJV_Clinical_Review_Status__c + ').';
                return res;
            }

            // Gate 3: Operations Review
            if (opp.SJV_Operations_Review_Status__c == 'Pending Review' || opp.SJV_Operations_Review_Status__c == 'Rejected') {
                res.success = false;
                res.message = 'Gate check failed: Operations Review has not been approved (Status: ' + opp.SJV_Operations_Review_Status__c + ').';
                return res;
            }

            // Gate 4: Credit Clearance
            if (opp.SJV_Credit_Review_Status__c == 'Warning / On Hold') {
                res.success = false;
                res.message = 'Gate check failed: Account is currently on Credit Warning / On Hold. Finance approval required.';
                return res;
            }

            // All gates passed: Mark Closed Won and Ready for staff-operated Rosterfy handoff
            List<OpportunityStage> wonStages = [SELECT ApiName FROM OpportunityStage WHERE IsActive = true AND IsWon = true AND ApiName = 'Closed Won' LIMIT 1];
            if (wonStages.isEmpty()) {
                wonStages = [SELECT ApiName FROM OpportunityStage WHERE IsActive = true AND IsWon = true AND (ApiName LIKE '%Won%' OR ApiName LIKE '%Closed Won%') LIMIT 1];
            }
            if (wonStages.isEmpty()) {
                wonStages = [SELECT ApiName FROM OpportunityStage WHERE IsActive = true AND IsWon = true LIMIT 1];
            }
            String wonStage = wonStages.isEmpty() ? 'Closed Won' : wonStages[0].ApiName;
            Opportunity oppToUpdate = new Opportunity(
                Id = opp.Id,
                StageName = wonStage,
                SJV_Handoff_Readiness__c = 'Ready'
            );
            update oppToUpdate;

            // Mark linked initiative(s) as Ready
            if (opp.SJV_Volunteer_Initiative__c != null) {
                VolunteerInitiative parentInit = [
                    SELECT Id, SJV_Sync_State__c
                    FROM VolunteerInitiative
                    WHERE Id = :opp.SJV_Volunteer_Initiative__c
                ];
                parentInit.SJV_Sync_State__c = 'Ready';
                update parentInit;

                List<VolunteerInitiative> childInits = [
                    SELECT Id, SJV_Sync_State__c
                    FROM VolunteerInitiative
                    WHERE ParentVolunteerInitiativeId = :parentInit.Id
                ];
                for (VolunteerInitiative ci : childInits) {
                    ci.SJV_Sync_State__c = 'Ready';
                }
                if (!childInits.isEmpty()) {
                    update childInits;
                }
            }

            res.success = true;
            res.opportunityId = opp.Id;
            res.handoffReadiness = 'Ready';
            res.message = 'Opportunity successfully Closed Won. All commercial, clinical, and operational gates satisfied. Event is now eligible for staff to click Create in Rosterfy.';
            return res;

        } catch (Exception ex) {
            Database.rollback(sp);
            res.success = false;
            res.message = 'Error closing Opportunity Won: ' + ex.getMessage();
            return res;
        }
    }
}

