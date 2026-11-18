/**
 * @description Secure service for processing public and internal event enquiries.
 *              Validates input, creates standard Lead with event logistics and clinical risk fields, and schedules BDM follow-up.
 */
public with sharing class SJV_EnquirySubmissionService {

    public class EnquiryRequest {
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String organisationName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String customerRole { get; set; }
        @AuraEnabled public String previousCustomer { get; set; } // Yes, No, Unsure
        @AuraEnabled public String eventName { get; set; }
        @AuraEnabled public String eventType { get; set; }
        @AuraEnabled public String eventDescription { get; set; }
        @AuraEnabled public Integer expectedAttendance { get; set; }
        @AuraEnabled public String publicOrPrivate { get; set; }
        @AuraEnabled public Boolean isProvisional { get; set; }
        @AuraEnabled public String venueName { get; set; }
        @AuraEnabled public String venueAddress { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public String dailyHoursDescription { get; set; }
        @AuraEnabled public String timezone { get; set; }
        @AuraEnabled public Boolean isMultiDay { get; set; }
        @AuraEnabled public String indoorOutdoor { get; set; }
        @AuraEnabled public String alcoholPresent { get; set; }
        @AuraEnabled public String highRiskActivities { get; set; }
        @AuraEnabled public String firstAidPostAvailable { get; set; }
        @AuraEnabled public String requestedCoverageNotes { get; set; }
        @AuraEnabled public String setupAccessInstructions { get; set; }
        @AuraEnabled public String eventDayContactName { get; set; }
        @AuraEnabled public String eventDayContactPhone { get; set; }
        @AuraEnabled public Boolean marketingConsent { get; set; }
        @AuraEnabled public String leadSource { get; set; }
        @AuraEnabled public String submissionKey { get; set; }
    }

    public class EnquiryResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String enquiryId { get; set; }
        @AuraEnabled public String enquiryNumber { get; set; }
        @AuraEnabled public String leadId { get; set; }
        @AuraEnabled public String submissionKey { get; set; }
        @AuraEnabled public String message { get; set; }
    }

    @AuraEnabled
    public static EnquiryResult submitEnquiryJson(String requestJson) {
        if (String.isBlank(requestJson)) {
            EnquiryResult r = new EnquiryResult();
            r.success = false;
            r.message = 'Enquiry request payload cannot be empty.';
            return r;
        }
        EnquiryRequest req = (EnquiryRequest) JSON.deserialize(requestJson, EnquiryRequest.class);
        return submitEnquiry(req);
    }

    @AuraEnabled
    public static EnquiryResult submitEnquiry(EnquiryRequest req) {
        EnquiryResult result = new EnquiryResult();
        try {
            if (req == null) {
                result.success = false;
                result.message = 'Enquiry request cannot be null';
                return result;
            }

            // Basic validation
            if (String.isBlank(req.lastName) || String.isBlank(req.email) || String.isBlank(req.eventName)) {
                result.success = false;
                result.message = 'Last Name, Email, and Event Name are required.';
                return result;
            }

            // Generate submission key if not supplied
            String subKey = String.isNotBlank(req.submissionKey) ? req.submissionKey : 'SUB-' + System.currentTimeMillis() + '-' + Crypto.getRandomInteger();

            String orgName = String.isNotBlank(req.organisationName) ? req.organisationName : ('Individual / ' + req.lastName);
            String evName = String.isNotBlank(req.eventName) ? req.eventName : 'Event Service Enquiry';
            String evType = String.isNotBlank(req.eventType) ? req.eventType : 'Community Festival';
            Date startDate = req.startDate != null ? req.startDate : Date.today().addDays(30);
            Date endDate = req.endDate != null ? req.endDate : startDate;
            Boolean isMulti = req.isMultiDay != null ? req.isMultiDay : (startDate != endDate);

            // Create Lead directly
            Lead ld = new Lead();
            ld.FirstName = req.firstName;
            ld.LastName = req.lastName;
            ld.Company = orgName;
            ld.Email = req.email;
            ld.Phone = req.phone;
            ld.LeadSource = String.isNotBlank(req.leadSource) ? req.leadSource : 'Website';
            ld.Status = 'New';
            ld.Description = 'Event Enquiry: ' + evName + ' (' + evType + '). Venue: ' + req.venueName + '. Expected Attendance: ' + req.expectedAttendance;
            ld.Street = req.venueAddress;
            ld.SJV_Event_Name__c = evName;
            ld.SJV_Event_Type__c = evType;
            ld.SJV_Expected_Attendance__c = req.expectedAttendance != null ? req.expectedAttendance : 500;
            ld.SJV_Start_Date__c = startDate;
            ld.SJV_End_Date__c = endDate;
            ld.SJV_Is_Multi_Day__c = isMulti;
            ld.SJV_Daily_Hours_Description__c = req.dailyHoursDescription;
            ld.SJV_Venue_Name__c = req.venueName;
            ld.SJV_Indoor_Outdoor__c = String.isNotBlank(req.indoorOutdoor) ? req.indoorOutdoor : 'Outdoor';
            ld.SJV_Alcohol_Present__c = String.isNotBlank(req.alcoholPresent) ? req.alcoholPresent : 'No';
            ld.SJV_High_Risk_Activities__c = String.isNotBlank(req.highRiskActivities) ? req.highRiskActivities : 'None';
            ld.SJV_First_Aid_Post_Available__c = String.isNotBlank(req.firstAidPostAvailable) ? req.firstAidPostAvailable : 'Yes';
            ld.SJV_Customer_Role__c = req.customerRole;
            ld.SJV_Previous_Customer__c = String.isNotBlank(req.previousCustomer) ? req.previousCustomer : 'Unsure';
            ld.SJV_Requested_Coverage_Notes__c = req.requestedCoverageNotes;
            ld.SJV_Setup_Access_Instructions__c = req.setupAccessInstructions;
            ld.SJV_Event_Day_Contact_Name__c = req.eventDayContactName;
            ld.SJV_Event_Day_Contact_Phone__c = req.eventDayContactPhone;

            Database.DMLOptions dml = new Database.DMLOptions();
            dml.duplicateRuleHeader.allowSave = true;
            dml.duplicateRuleHeader.runAsCurrentUser = true;
            Database.insert(ld, dml);

            // Create follow-up Task for BDM owner
            Task t = new Task();
            t.WhoId = ld.Id;
            t.Subject = 'Follow up new event enquiry: ' + evName;
            t.Description = 'Contact organiser to qualify event requirements.\nOrganisation: ' + orgName + '\nDates: ' + startDate + ' to ' + endDate;
            t.ActivityDate = Date.today().addDays(1);
            t.Priority = 'High';
            t.Status = 'Not Started';
            insert t;

            result.success = true;
            result.leadId = ld.Id;
            result.enquiryId = ld.Id;
            result.enquiryNumber = 'ENQ-' + String.valueOf(ld.Id).right(6);
            result.submissionKey = subKey;
            result.message = 'Thank you! Your event enquiry has been received (Ref: ' + result.enquiryNumber + '). A St John representative will contact you shortly.';
            return result;

        } catch (Exception ex) {
            result.success = false;
            result.message = 'Error submitting enquiry: ' + ex.getMessage();
            return result;
        }
    }
}

