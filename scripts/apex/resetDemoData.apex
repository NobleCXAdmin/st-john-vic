/**
 * @description Master Reset Script for St John VIC Salesforce Business Development & Event Services Demo (AT25).
 *              Safely removes only synthetic records tagged with 'SJV-DEMO-%' or matching the demo customer.
 *              Preserves real non-demo records, catalogue positions, products, and org configuration.
 *
 * To run:
 * sf apex run --file scripts/apex/resetDemoData.apex --target-org "St John VIC Demo Org"
 */

System.debug('--- STARTING ST JOHN VIC DEMO RESET (AT25) ---');

// 1. Delete Integration Items and Requests
List<SJV_Integration_Item__c> items = [
    SELECT Id FROM SJV_Integration_Item__c
    WHERE Source_Key__c LIKE 'SJV-DEMO-%'
       OR Integration_Request__r.Unique_Operation_Key__c LIKE 'SJV-DEMO-%'
];
if (!items.isEmpty()) {
    delete items;
    System.debug('Deleted ' + items.size() + ' SJV_Integration_Item__c records.');
}

List<SJV_Integration_Request__c> reqs = [
    SELECT Id FROM SJV_Integration_Request__c
    WHERE Unique_Operation_Key__c LIKE 'SJV-DEMO-%'
];
if (!reqs.isEmpty()) {
    delete reqs;
    System.debug('Deleted ' + reqs.size() + ' SJV_Integration_Request__c records.');
}

// 2. Delete JobPositionShifts and JobPositions
List<JobPositionShift> shifts = [
    SELECT Id FROM JobPositionShift
    WHERE SJV_Source_Shift_Key__c LIKE 'SJV-DEMO-%'
];
if (!shifts.isEmpty()) {
    delete shifts;
    System.debug('Deleted ' + shifts.size() + ' JobPositionShift records.');
}

List<JobPosition> jobs = [
    SELECT Id FROM JobPosition
    WHERE SJV_Source_Job_Key__c LIKE 'SJV-DEMO-%'
];
if (!jobs.isEmpty()) {
    delete jobs;
    System.debug('Deleted ' + jobs.size() + ' JobPosition records.');
}

// 3. Delete Resource Requirements and Risk Answers
List<SJV_Resource_Requirement__c> rReqs = [
    SELECT Id FROM SJV_Resource_Requirement__c
    WHERE Requirement_Key__c LIKE 'SJV-DEMO-%'
];
if (!rReqs.isEmpty()) {
    delete rReqs;
    System.debug('Deleted ' + rReqs.size() + ' SJV_Resource_Requirement__c records.');
}

List<SJV_Risk_Answer__c> answers = [
    SELECT Id FROM SJV_Risk_Answer__c
    WHERE Risk_Assessment__r.Unique_Version_Key__c LIKE '%DEMO%'
];
if (!answers.isEmpty()) {
    delete answers;
    System.debug('Deleted ' + answers.size() + ' SJV_Risk_Answer__c records.');
}

// 4. Delete Risk Assessments
List<SJV_Risk_Assessment__c> assessments = [
    SELECT Id FROM SJV_Risk_Assessment__c
    WHERE Unique_Version_Key__c LIKE '%DEMO%'
];
if (!assessments.isEmpty()) {
    delete assessments;
    System.debug('Deleted ' + assessments.size() + ' SJV_Risk_Assessment__c records.');
}

// 5. Delete Quote Acceptance Evidence
List<SJV_Quote_Acceptance__c> acceptances = [
    SELECT Id FROM SJV_Quote_Acceptance__c
    WHERE Terms_Hash__c LIKE '%DEMO%'
];
if (!acceptances.isEmpty()) {
    delete acceptances;
    System.debug('Deleted ' + acceptances.size() + ' SJV_Quote_Acceptance__c records.');
}

// 6. Delete Quotes and Line Items
List<Quote> quotes = [
    SELECT Id FROM Quote
    WHERE Name LIKE '%St Kilda%'
       OR Name LIKE '%DEMO%'
];
if (!quotes.isEmpty()) {
    delete quotes;
    System.debug('Deleted ' + quotes.size() + ' Quote records.');
}

// 7. Delete VolunteerInitiatives
List<VolunteerInitiative> initiatives = [
    SELECT Id FROM VolunteerInitiative
    WHERE SJV_Source_Event_Key__c LIKE 'SJV-DEMO-%'
];
if (!initiatives.isEmpty()) {
    delete initiatives;
    System.debug('Deleted ' + initiatives.size() + ' VolunteerInitiative records.');
}

// 8. Delete Opportunity
List<Opportunity> opps = [
    SELECT Id FROM Opportunity
    WHERE Name LIKE 'St Kilda Community Festival 2026%'
];
if (!opps.isEmpty()) {
    delete opps;
    System.debug('Deleted ' + opps.size() + ' Opportunity records.');
}

// 9. Delete Event Enquiries
List<SJV_Event_Enquiry__c> enquiries = [
    SELECT Id FROM SJV_Event_Enquiry__c
    WHERE Submission_Key__c LIKE 'SJV-DEMO-%'
];
if (!enquiries.isEmpty()) {
    delete enquiries;
    System.debug('Deleted ' + enquiries.size() + ' SJV_Event_Enquiry__c records.');
}

// 10. Delete Demo Client Account & Leads
List<Lead> demoLeads = [
    SELECT Id FROM Lead
    WHERE (LastName = 'Rostova' AND FirstName = 'Elena')
       OR (LastName = 'Vance' AND FirstName = 'Marcus')
       OR SJV_Event_Enquiry__r.Submission_Key__c LIKE 'SJV-DEMO-%'
];
if (!demoLeads.isEmpty()) {
    delete demoLeads;
    System.debug('Deleted ' + demoLeads.size() + ' Demo Lead records.');
}

List<Account> accounts = [
    SELECT Id FROM Account
    WHERE (LastName = 'Vance' AND FirstName = 'Marcus')
       OR (LastName = 'Rostova' AND FirstName = 'Elena')
];
if (!accounts.isEmpty()) {
    delete accounts;
    System.debug('Deleted ' + accounts.size() + ' Account records.');
}

System.debug('--- DEMO RESET COMPLETE (AT25) ---');
