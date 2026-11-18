/**
 * @description Service to convert Lead into Account, Contact, Opportunity,
 *              convert the Lead into Account, Contact, and Opportunity, and initialize the VolunteerInitiative structure.
 */
public without sharing class SJV_LeadConversionService {

    public class ConversionRequest {
        @AuraEnabled public Id leadId;
        @AuraEnabled public Id accountId; // Optional existing Account
        @AuraEnabled public Id contactId; // Optional existing Contact
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String qualificationNotes;
    }

    public class ConversionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id parentInitiativeId;
        @AuraEnabled public Id initiativeId;
        @AuraEnabled public List<Id> dayInitiativeIds;
        @AuraEnabled public String message;
    }

    public static ConversionResult convertLead(ConversionRequest req) {
        return convertLead(req, null, null);
    }

    @AuraEnabled
    public static ConversionResult convertLead(ConversionRequest req, Id leadId, String qualificationNotes) {
        if (req == null) {
            req = new ConversionRequest();
            req.leadId = leadId;
            req.qualificationNotes = qualificationNotes;
        } else if (req.leadId == null && leadId != null) {
            req.leadId = leadId;
            if (String.isBlank(req.qualificationNotes)) {
                req.qualificationNotes = qualificationNotes;
            }
        }

        ConversionResult result = new ConversionResult();
        result.dayInitiativeIds = new List<Id>();

        Savepoint sp = Database.setSavepoint();
        try {
            if (req == null || req.leadId == null) {
                result.success = false;
                result.message = 'Lead ID is required for conversion.';
                return result;
            }

            Lead ld = [
                SELECT Id, FirstName, LastName, Company, Email, Phone, Description,
                       SJV_Event_Name__c, SJV_Event_Type__c, SJV_Expected_Attendance__c,
                       SJV_Start_Date__c, SJV_End_Date__c, SJV_Daily_Hours_Description__c,
                       SJV_Venue_Name__c, Street, SJV_Indoor_Outdoor__c,
                       SJV_Alcohol_Present__c, SJV_High_Risk_Activities__c,
                       SJV_First_Aid_Post_Available__c, SJV_Customer_Role__c,
                       SJV_Previous_Customer__c, SJV_Event_Day_Contact_Name__c,
                       SJV_Event_Day_Contact_Phone__c, SJV_Requested_Coverage_Notes__c,
                       SJV_Setup_Access_Instructions__c, SJV_Is_Multi_Day__c,
                       IsConverted
                FROM Lead
                WHERE Id = :req.leadId
                LIMIT 1
            ];

            if (ld.IsConverted) {
                result.success = false;
                result.message = 'This lead has already been converted.';
                return result;
            }

            // Find converted Lead status
            LeadStatus convertStatus = [
                SELECT Id, MasterLabel
                FROM LeadStatus
                WHERE IsConverted = true
                ORDER BY SortOrder ASC
                LIMIT 1
            ];

            // Perform standard Lead conversion
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(ld.Id);
            lc.setConvertedStatus(convertStatus.MasterLabel);

            if (req.accountId != null) {
                lc.setAccountId(req.accountId);
            } else {
                String accName = String.isNotBlank(ld.Company) ? ld.Company : (ld.FirstName + ' ' + ld.LastName);
                List<Account> existingAccs = [SELECT Id FROM Account WHERE Name = :accName LIMIT 1];
                if (!existingAccs.isEmpty()) {
                    lc.setAccountId(existingAccs[0].Id);
                }
            }
            if (req.contactId != null) {
                lc.setContactId(req.contactId);
            }

            String orgLabel = String.isNotBlank(ld.Company) ? ld.Company : 'Community Client';
            String oppName = String.isNotBlank(req.opportunityName) ? req.opportunityName :
                             (String.isNotBlank(ld.SJV_Event_Name__c) ? ld.SJV_Event_Name__c + ' - ' + orgLabel : 'Event Opportunity');
            lc.setOpportunityName(oppName);

            Database.DMLOptions dml = new Database.DMLOptions();
            dml.duplicateRuleHeader.allowSave = true;
            dml.duplicateRuleHeader.runAsCurrentUser = true;

            Database.LeadConvertResult lcr = Database.convertLead(lc, dml);
            if (!lcr.isSuccess()) {
                Database.rollback(sp);
                result.success = false;
                result.message = 'Conversion failed: ' + lcr.getErrors()[0].getMessage();
                return result;
            }

            result.accountId = lcr.getAccountId();
            result.opportunityId = lcr.getOpportunityId();

            // Retrieve Contact ID (for Person Account or standard contact)
            Id conId = lcr.getContactId();
            if (conId == null && result.accountId != null) {
                List<Account> accList = [SELECT Id, PersonContactId FROM Account WHERE Id = :result.accountId];
                if (!accList.isEmpty()) {
                    conId = accList[0].PersonContactId;
                }
            }
            result.contactId = conId;

            // Set initial Opportunity fields
            Opportunity opp = [
                SELECT Id, StageName, SJV_Volunteer_Initiative__c, SJV_Clinical_Review_Status__c,
                       SJV_Operations_Review_Status__c, SJV_Credit_Review_Status__c, SJV_Handoff_Readiness__c
                FROM Opportunity
                WHERE Id = :result.opportunityId
            ];
            List<OpportunityStage> initStages = [SELECT ApiName FROM OpportunityStage WHERE IsActive = true AND IsClosed = false AND ApiName = 'Event Qualification' LIMIT 1];
            if (!initStages.isEmpty()) {
                opp.StageName = initStages[0].ApiName;
            } else {
                List<OpportunityStage> fallbackStages = [SELECT ApiName FROM OpportunityStage WHERE IsActive = true AND IsClosed = false AND ApiName LIKE '%Qualification%' ORDER BY SortOrder ASC LIMIT 1];
                opp.StageName = fallbackStages.isEmpty() ? 'Event Qualification' : fallbackStages[0].ApiName;
            }
            opp.SJV_Clinical_Review_Status__c = 'Pending Review';
            opp.SJV_Operations_Review_Status__c = 'Pending Review';
            opp.SJV_Credit_Review_Status__c = 'Cleared';
            opp.SJV_Handoff_Readiness__c = 'Not Ready';

            // Assign Event Opportunity Record Type created for St John VIC event conversions
            List<RecordType> eventRts = [
                SELECT Id FROM RecordType 
                WHERE SObjectType = 'Opportunity' AND (DeveloperName = 'Event' OR DeveloperName = 'Event_Opportunity') AND IsActive = true 
                LIMIT 1
            ];
            if (!eventRts.isEmpty()) {
                opp.RecordTypeId = eventRts[0].Id;
            }

            // Create VolunteerInitiative record(s)
            String eventName = String.isNotBlank(ld.SJV_Event_Name__c) ? ld.SJV_Event_Name__c : oppName;
            Date startDate = ld.SJV_Start_Date__c != null ? ld.SJV_Start_Date__c : Date.today().addDays(30);
            Date endDate = (ld.SJV_End_Date__c != null && ld.SJV_End_Date__c >= startDate) ? ld.SJV_End_Date__c : startDate.addDays(1);
            Boolean isMultiDay = ld.SJV_Is_Multi_Day__c || (startDate != endDate);

            // Parent / Primary Initiative
            VolunteerInitiative parentInit = new VolunteerInitiative();
            parentInit.Name = eventName + ' (Main)';
            parentInit.Description = ld.Description;
            parentInit.StartDate = startDate;
            parentInit.EndDate = endDate;
            parentInit.Status = 'Upcoming';
            parentInit.SJV_Opportunity__c = opp.Id;
            parentInit.SJV_Operational_Contact__c = result.contactId;
            parentInit.SJV_Timezone__c = 'Australia/Melbourne';
            parentInit.SJV_Venue_Instructions__c = String.isNotBlank(ld.SJV_Setup_Access_Instructions__c) ? ld.SJV_Setup_Access_Instructions__c : '';
            parentInit.SJV_Source_Event_Key__c = 'SJV-EVT-' + System.currentTimeMillis();
            parentInit.SJV_Sync_State__c = 'Not Ready';
            insert parentInit;

            result.parentInitiativeId = parentInit.Id;
            result.initiativeId = parentInit.Id;
            opp.SJV_Volunteer_Initiative__c = parentInit.Id;
            update opp;

            // If multi-day, create child day initiatives; otherwise parent initiative is the operational day unit
            if (isMultiDay) {
                Integer totalDays = startDate.daysBetween(endDate) + 1;
                // Bound to max 5 days for demo safety
                if (totalDays > 5) totalDays = 5;

                List<VolunteerInitiative> dayInits = new List<VolunteerInitiative>();
                for (Integer i = 0; i < totalDays; i++) {
                    Date dayDate = startDate.addDays(i);
                    VolunteerInitiative dayInit = new VolunteerInitiative();
                    dayInit.Name = eventName + ' - Day ' + (i + 1);
                    dayInit.ParentVolunteerInitiativeId = parentInit.Id;
                    dayInit.StartDate = dayDate;
                    dayInit.EndDate = dayDate.addDays(1);
                    dayInit.Status = 'Upcoming';
                    dayInit.SJV_Opportunity__c = opp.Id;
                    dayInit.SJV_Operational_Contact__c = result.contactId;
                    dayInit.SJV_Timezone__c = parentInit.SJV_Timezone__c;
                    dayInit.SJV_Venue_Instructions__c = parentInit.SJV_Venue_Instructions__c;
                    dayInit.SJV_Source_Event_Key__c = parentInit.SJV_Source_Event_Key__c + '-DAY-' + (i + 1);
                    dayInit.SJV_Sync_State__c = 'Not Ready';
                    dayInits.add(dayInit);
                }
                insert dayInits;

                for (VolunteerInitiative di : dayInits) {
                    result.dayInitiativeIds.add(di.Id);
                }
            } else {
                result.dayInitiativeIds.add(parentInit.Id);
            }


            // Create initial task on Opportunity
            Task oppTask = new Task();
            oppTask.WhatId = opp.Id;
            oppTask.Subject = 'Complete Initial Risk Assessment for: ' + eventName;
            oppTask.Description = 'Review organiser conditions, run risk scoring rule engine, and generate proposed staffing demand.';
            oppTask.ActivityDate = Date.today().addDays(2);
            oppTask.Priority = 'High';
            oppTask.Status = 'Not Started';
            insert oppTask;

            result.success = true;
            result.message = 'Lead successfully converted. Opportunity and Volunteer Initiative planning structure initialized.';
            return result;

        } catch (Exception ex) {
            Database.rollback(sp);
            result.success = false;
            result.message = 'Error converting lead: ' + ex.getMessage();
            return result;
        }
    }
}
