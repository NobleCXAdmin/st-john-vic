/**
 * @description Master Seed Script for St John VIC Salesforce Business Development & Event Services Demo.
 *              Creates complete fictitious 2-day St Kilda Community Festival records (Lead, Account,
 *              Opportunity, VolunteerInitiatives, Risk Assessment v1, JobPositions, Shifts, Quote,
 *              Acceptance Evidence, and sets Closed Won gate to Ready for staff Rosterfy transfer).
 *
 * To run:
 * sf apex run --file scripts/apex/seedDemoData.apex --target-org "St John VIC Demo Org"
 */

System.debug('--- STARTING ST JOHN VIC DEMO SEED ---');

// 1. Ensure Catalogue (Positions, Products, PricebookEntries)
SJV_DemandAndQuoteService.ensureStJohnCatalogue();

Id stdPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

// 2. Create Person Account / Client
Account acc = new Account(
    FirstName = 'Marcus',
    LastName = 'Vance',
    PersonEmail = 'marcus.vance@example.com',
    Phone = '0412 345 678'
);
insert acc;

Account refreshedAcc = [SELECT Id, PersonContactId FROM Account WHERE Id = :acc.Id];
Id contactId = refreshedAcc.PersonContactId;
System.debug('Created Account: ' + acc.Id + ' with Contact: ' + contactId);

// 3. Create Event Enquiry
Date eventStartDate = Date.today().addDays(30);
Date eventEndDate = eventStartDate.addDays(1);

SJV_Event_Enquiry__c enq = new SJV_Event_Enquiry__c(
    Submission_Key__c = 'SJV-DEMO-ENQ-001',
    First_Name__c = 'Marcus',
    Last_Name__c = 'Vance',
    Organisation_Name__c = 'St Kilda Community Festival Committee',
    Email__c = 'marcus.vance@example.com',
    Phone__c = '0412 345 678',
    Customer_Role__c = 'Event Operations Director',
    Previous_Customer__c = 'Yes',
    Event_Name__c = 'St Kilda Community Festival 2026',
    Event_Type__c = 'Community Festival',
    Event_Description__c = 'Annual 2-day community festival along St Kilda foreshore featuring live music, food stalls, and family activities.',
    Expected_Attendance__c = 5000,
    Public_or_Private__c = 'Public Event',
    Venue_Name__c = 'Catani Gardens & Foreshore',
    Venue_Address__c = 'Pier Road, St Kilda VIC 3182',
    Start_Date__c = eventStartDate,
    End_Date__c = eventEndDate,
    Daily_Hours_Description__c = 'Day 1: 09:00 - 17:00, Day 2: 10:00 - 16:00',
    Timezone__c = 'Australia/Melbourne',
    Is_Multi_Day__c = true,
    Indoor_Outdoor__c = 'Outdoor',
    Alcohol_Present__c = 'Yes',
    High_Risk_Activities__c = 'None',
    First_Aid_Post_Available__c = 'No',
    Requested_Coverage_Notes__c = 'Requesting visible first aid post marquee plus roving first responders throughout the park.',
    Setup_Access_Instructions__c = 'Vehicle access gate 3 off Pier Road. Parking permits supplied for St John command vehicle.',
    Event_Day_Contact_Name__c = 'Marcus Vance',
    Event_Day_Contact_Phone__c = '0412 345 678',
    Status__c = 'Qualified / Converted',
    Missing_Information_Notes__c = 'Site access map and liquor licensing confirmed with City of Port Phillip.',
    Account__c = acc.Id,
    Contact__c = contactId
);
insert enq;
System.debug('Created Enquiry: ' + enq.Id);

// 4. Create Opportunity
Opportunity opp = new Opportunity(
    Name = 'St Kilda Community Festival 2026 - Event Health Services',
    AccountId = acc.Id,
    CloseDate = Date.today().addDays(7),
    StageName = 'Proposal/Quote',
    Pricebook2Id = stdPbId,
    SJV_Clinical_Review_Status__c = 'Approved',
    SJV_Operations_Review_Status__c = 'Approved',
    SJV_Credit_Review_Status__c = 'Cleared',
    SJV_Handoff_Readiness__c = 'Not Ready',
    Amount = 4550.00,
    SJV_Internal_Cost__c = 2220.00,
    SJV_Estimated_Margin__c = 2330.00
);
insert opp;
enq.Opportunity__c = opp.Id;
update enq;
System.debug('Created Opportunity: ' + opp.Id);

// 5. Create VolunteerInitiative Hierarchy (Parent + Day 1 + Day 2)
VolunteerInitiative parentInit = new VolunteerInitiative(
    Name = 'St Kilda Community Festival 2026 (Main)',
    Description = 'St John VIC Event Health Services for 2-day St Kilda Community Festival',
    StartDate = eventStartDate,
    EndDate = eventEndDate.addDays(1), // validation rule StartDate < EndDate
    Status = 'Upcoming',
    SJV_Opportunity__c = opp.Id,
    SJV_Operational_Contact__c = contactId,
    SJV_Timezone__c = 'Australia/Melbourne',
    SJV_Venue_Instructions__c = 'Pier Rd Gate 3 access. St John Marquee at Catani Gardens central lawn.',
    SJV_Source_Event_Key__c = 'SJV-DEMO-EVT-MAIN-001',
    SJV_Sync_State__c = 'Not Ready',
    SJV_Approved_Plan_Revision__c = 1
);
insert parentInit;

opp.SJV_Volunteer_Initiative__c = parentInit.Id;
update opp;
enq.Volunteer_Initiative__c = parentInit.Id;
update enq;

// Child Day 1
VolunteerInitiative day1Init = new VolunteerInitiative(
    Name = 'St Kilda Community Festival 2026 - Day 1',
    ParentVolunteerInitiativeId = parentInit.Id,
    StartDate = eventStartDate,
    EndDate = eventStartDate.addDays(1),
    Status = 'Upcoming',
    SJV_Opportunity__c = opp.Id,
    SJV_Operational_Contact__c = contactId,
    SJV_Timezone__c = 'Australia/Melbourne',
    SJV_Venue_Instructions__c = parentInit.SJV_Venue_Instructions__c,
    SJV_Source_Event_Key__c = 'SJV-DEMO-EVT-DAY1-001',
    SJV_Sync_State__c = 'Not Ready',
    SJV_Approved_Plan_Revision__c = 1
);
insert day1Init;

// Child Day 2
VolunteerInitiative day2Init = new VolunteerInitiative(
    Name = 'St Kilda Community Festival 2026 - Day 2',
    ParentVolunteerInitiativeId = parentInit.Id,
    StartDate = eventEndDate,
    EndDate = eventEndDate.addDays(1),
    Status = 'Upcoming',
    SJV_Opportunity__c = opp.Id,
    SJV_Operational_Contact__c = contactId,
    SJV_Timezone__c = 'Australia/Melbourne',
    SJV_Venue_Instructions__c = parentInit.SJV_Venue_Instructions__c,
    SJV_Source_Event_Key__c = 'SJV-DEMO-EVT-DAY2-001',
    SJV_Sync_State__c = 'Not Ready',
    SJV_Approved_Plan_Revision__c = 1
);
insert day2Init;
System.debug('Created VolunteerInitiative Hierarchy: Parent=' + parentInit.Id + ', Day 1=' + day1Init.Id + ', Day 2=' + day2Init.Id);

// 6. Create Approved Risk Assessment (v1) on Day 1
SJV_Risk_Assessment__c ra = new SJV_Risk_Assessment__c(
    Volunteer_Initiative__c = day1Init.Id,
    Opportunity__c = opp.Id,
    Event_Day_Key__c = day1Init.Name,
    Version_Number__c = 1,
    Unique_Version_Key__c = 'SJV-DEMO-RA-DAY1-V1',
    Status__c = 'Approved',
    Reason_For_Change__c = 'Initial enquiry assessment',
    Rule_Set_Version__c = 'v1.0-Illustrative',
    Rule_Set_Disclaimer__c = SJV_RiskAssessmentService.DISCLAIMER,
    Total_Risk_Score__c = 55,
    Risk_Band__c = 'Medium',
    Proposed_Staff_Count__c = 7,
    Proposed_Staff_Hours__c = 32,
    Estimated_Internal_Cost__c = 1200.00,
    Estimated_Selling_Price__c = 2500.00,
    Reviewer_Decision__c = 'Approved',
    Reviewer__c = UserInfo.getUserId(),
    Reviewed_Date_Time__c = System.now().addDays(-2),
    Review_Comments__c = 'Illustrative demo rules applied. Standard community festival profile approved.'
);
insert ra;

day1Init.SJV_Current_Approved_Assessment__c = ra.Id;
update day1Init;

// Risk Answers
List<SJV_Risk_Answer__c> answers = new List<SJV_Risk_Answer__c>{
    new SJV_Risk_Answer__c(
        Risk_Assessment__c = ra.Id,
        Question_Key__c = 'ATTENDANCE',
        Question_Text__c = 'Expected Attendance',
        Question_Category__c = 'Demographics',
        Answer_Value__c = '5000',
        Score_Contribution__c = 45,
        Scoring_Explanation__c = 'Large attendance (3,000 - 10,000 attendees)'
    ),
    new SJV_Risk_Answer__c(
        Risk_Assessment__c = ra.Id,
        Question_Key__c = 'VENUE_SETTING',
        Question_Text__c = 'Venue Setting',
        Question_Category__c = 'Environment',
        Answer_Value__c = 'Outdoor',
        Score_Contribution__c = 15,
        Scoring_Explanation__c = 'Outdoor parkland venue requires mobile response'
    ),
    new SJV_Risk_Answer__c(
        Risk_Assessment__c = ra.Id,
        Question_Key__c = 'ALCOHOL',
        Question_Text__c = 'Alcohol Service',
        Question_Category__c = 'Risk Factors',
        Answer_Value__c = 'Yes',
        Score_Contribution__c = 25,
        Scoring_Explanation__c = 'Licensed alcohol service increases clinical risk'
    ),
    new SJV_Risk_Answer__c(
        Risk_Assessment__c = ra.Id,
        Question_Key__c = 'HIGH_RISK_ACTIVITIES',
        Question_Text__c = 'High-Risk Activities',
        Question_Category__c = 'Clinical Hazards',
        Answer_Value__c = 'None',
        Score_Contribution__c = 0,
        Scoring_Explanation__c = 'Low-risk community profile'
    )
};
insert answers;

// Resource Requirements
List<SJV_Resource_Requirement__c> reqs = new List<SJV_Resource_Requirement__c>{
    new SJV_Resource_Requirement__c(
        Risk_Assessment__c = ra.Id,
        Requirement_Key__c = 'SJV-DEMO-REQ-001',
        Category__c = 'Staff',
        Role_or_Item_Code__c = 'FIRST_AIDER',
        Role_or_Item_Name__c = 'Event First Aider',
        Quantity__c = 6,
        Service_Date__c = eventStartDate,
        Duration_Hours__c = 4.0,
        Total_Staff_Hours__c = 24.0,
        Demand_Type__c = 'Volunteer',
        Internal_Cost_Rate__c = 35.00,
        Selling_Rate__c = 75.00,
        Internal_Cost_Total__c = 840.00,
        Selling_Price_Total__c = 1800.00,
        Billable_Units__c = 24.0,
        Unit_Basis__c = 'Hourly',
        Origin__c = 'Rule Engine'
    ),
    new SJV_Resource_Requirement__c(
        Risk_Assessment__c = ra.Id,
        Requirement_Key__c = 'SJV-DEMO-REQ-002',
        Category__c = 'Staff',
        Role_or_Item_Code__c = 'HCP_PARAMEDIC',
        Role_or_Item_Name__c = 'Health Care Professional (Registered Nurse / Paramedic)',
        Quantity__c = 1,
        Service_Date__c = eventStartDate,
        Duration_Hours__c = 4.0,
        Total_Staff_Hours__c = 4.0,
        Demand_Type__c = 'Paid Staff',
        Internal_Cost_Rate__c = 65.00,
        Selling_Rate__c = 135.00,
        Internal_Cost_Total__c = 260.00,
        Selling_Price_Total__c = 540.00,
        Billable_Units__c = 4.0,
        Unit_Basis__c = 'Hourly',
        Origin__c = 'Rule Engine'
    ),
    new SJV_Resource_Requirement__c(
        Risk_Assessment__c = ra.Id,
        Requirement_Key__c = 'SJV-DEMO-REQ-003',
        Category__c = 'Equipment',
        Role_or_Item_Code__c = 'FA_POST_KIT',
        Role_or_Item_Name__c = 'Mobile First Aid Marquee & Clinical Response Kit',
        Quantity__c = 1,
        Service_Date__c = eventStartDate,
        Duration_Hours__c = 4.0,
        Total_Staff_Hours__c = 0,
        Demand_Type__c = 'Asset',
        Internal_Cost_Rate__c = 100.00,
        Selling_Rate__c = 250.00,
        Internal_Cost_Total__c = 100.00,
        Selling_Price_Total__c = 250.00,
        Billable_Units__c = 1.0,
        Unit_Basis__c = 'Per Day',
        Origin__c = 'Rule Engine'
    )
};
insert reqs;
System.debug('Created Risk Assessment v1: ' + ra.Id);

// 7. Create Operational Demand: JobPositions and JobPositionShifts
Map<String, Id> posMap = new Map<String, Id>();
for (Position p : [SELECT Id, Code FROM Position WHERE Code IN ('FIRST_AIDER', 'HCP_PARAMEDIC')]) {
    posMap.put(p.Code, p.Id);
}

JobPosition jpFa = new JobPosition(
    Name = day1Init.Name + ' - Event First Aider',
    Title = 'Event First Aider',
    VolunteerInitiativeId = day1Init.Id,
    PositionId = posMap.get('FIRST_AIDER'),
    Status = 'Upcoming',
    StartDate = eventStartDate,
    EndDate = eventStartDate.addDays(1),
    SJV_Source_Job_Key__c = 'SJV-DEMO-JOB-FA-001',
    SJV_Role_Mapping_Key__c = 'FIRST_AIDER'
);
JobPosition jpHcp = new JobPosition(
    Name = day1Init.Name + ' - Health Care Professional',
    Title = 'Health Care Professional',
    VolunteerInitiativeId = day1Init.Id,
    PositionId = posMap.get('HCP_PARAMEDIC'),
    Status = 'Upcoming',
    StartDate = eventStartDate,
    EndDate = eventStartDate.addDays(1),
    SJV_Source_Job_Key__c = 'SJV-DEMO-JOB-HCP-001',
    SJV_Role_Mapping_Key__c = 'HCP_PARAMEDIC'
);
insert new List<JobPosition>{ jpFa, jpHcp };

List<JobPositionShift> shifts = new List<JobPositionShift>{
    new JobPositionShift(
        JobPositionId = jpFa.Id,
        StartDate = eventStartDate,
        EndDate = eventStartDate,
        StartTime = Time.newInstance(9, 0, 0, 0),
        EndTime = Time.newInstance(13, 0, 0, 0),
        MaximumAttendeesCount = 3,
        Status = 'Upcoming',
        Description = 'Morning Roving & Marquee First Responder team',
        SJV_Source_Shift_Key__c = 'SJV-DEMO-SFT-001',
        SJV_Sync_Status__c = 'Pending'
    ),
    new JobPositionShift(
        JobPositionId = jpFa.Id,
        StartDate = eventStartDate,
        EndDate = eventStartDate,
        StartTime = Time.newInstance(13, 0, 0, 0),
        EndTime = Time.newInstance(17, 0, 0, 0),
        MaximumAttendeesCount = 3,
        Status = 'Upcoming',
        Description = 'Afternoon Peak Coverage First Responder team',
        SJV_Source_Shift_Key__c = 'SJV-DEMO-SFT-002',
        SJV_Sync_Status__c = 'Pending'
    ),
    new JobPositionShift(
        JobPositionId = jpHcp.Id,
        StartDate = eventStartDate,
        EndDate = eventStartDate,
        StartTime = Time.newInstance(9, 0, 0, 0),
        EndTime = Time.newInstance(17, 0, 0, 0),
        MaximumAttendeesCount = 1,
        Status = 'Upcoming',
        Description = 'Clinical Supervision & Advanced Trauma/Triage',
        SJV_Source_Shift_Key__c = 'SJV-DEMO-SFT-003',
        SJV_Sync_Status__c = 'Pending'
    )
};
insert shifts;
System.debug('Created Job Positions and Shifts on Day 1');

// 8. Create Commercial Quote & Line Items
Map<String, Id> pbeMap = new Map<String, Id>();
for (PricebookEntry pbe : [SELECT Id, ProductCode FROM PricebookEntry WHERE Pricebook2Id = :stdPbId AND ProductCode IN ('FIRST_AIDER', 'HCP_PARAMEDIC', 'FA_POST_KIT')]) {
    pbeMap.put(pbe.ProductCode, pbe.Id);
}

Quote q = new Quote(
    OpportunityId = opp.Id,
    Pricebook2Id = stdPbId,
    Name = 'St John Quote - St Kilda Community Festival 2026 (v1)',
    SJV_Internal_Cost_Total__c = 1200.00,
    SJV_Gross_Margin_Amount__c = 1390.00,
    SJV_Gross_Margin_Percent__c = 53.67,
    SJV_Acceptance_Status__c = 'Accepted',
    Status = 'Accepted',
    SJV_Assessment_Set_Snapshot__c = ra.Unique_Version_Key__c
);
insert q;

List<QuoteLineItem> qlis = new List<QuoteLineItem>{
    new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbeMap.get('FIRST_AIDER'),
        Quantity = 24,
        UnitPrice = 75.00,
        SJV_Internal_Cost_Rate__c = 35.00,
        SJV_Internal_Cost_Total__c = 840.00,
        SJV_Source_Requirement_Key__c = 'SJV-DEMO-REQ-001'
    ),
    new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbeMap.get('HCP_PARAMEDIC'),
        Quantity = 4,
        UnitPrice = 135.00,
        SJV_Internal_Cost_Rate__c = 65.00,
        SJV_Internal_Cost_Total__c = 260.00,
        SJV_Source_Requirement_Key__c = 'SJV-DEMO-REQ-002'
    ),
    new QuoteLineItem(
        QuoteId = q.Id,
        PricebookEntryId = pbeMap.get('FA_POST_KIT'),
        Quantity = 1,
        UnitPrice = 250.00,
        SJV_Internal_Cost_Rate__c = 100.00,
        SJV_Internal_Cost_Total__c = 100.00,
        SJV_Source_Requirement_Key__c = 'SJV-DEMO-REQ-003'
    )
};
insert qlis;

// 9. Record Quote Acceptance Evidence
SJV_Quote_Acceptance__c qAcc = new SJV_Quote_Acceptance__c(
    Quote__c = q.Id,
    Opportunity__c = opp.Id,
    Customer_Contact__c = contactId,
    Received_Date_Time__c = System.now().addDays(-1),
    Acceptance_Method__c = 'Signed Document',
    Evidence_Reference__c = 'Signed quote agreement returned by Marcus Vance, Event Director',
    Accepted_Amount__c = 2590.00,
    Recorded_By__c = UserInfo.getUserId(),
    Terms_Hash__c = 'HASH-SJV-DEMO-ACCEPTANCE-001',
    Notes__c = 'Customer accepted all standard commercial terms, first aid access instructions, and payment conditions.'
);
insert qAcc;
System.debug('Created Quote Acceptance Evidence: ' + qAcc.Id);

// 10. Satisfy Closed Won Gate & Transition to Ready
List<OpportunityStage> wonStages = [SELECT ApiName FROM OpportunityStage WHERE IsActive = true AND IsWon = true LIMIT 1];
String wonStageName = wonStages.isEmpty() ? '7 - Closed Won' : wonStages[0].ApiName;

Opportunity oppWon = new Opportunity(
    Id = opp.Id,
    SJV_Accepted_Quote__c = q.Id,
    StageName = wonStageName,
    SJV_Handoff_Readiness__c = 'Ready',
    Amount = 2590.00
);
update oppWon;

// Set VolunteerInitiatives to 'Ready' (waiting for staff member to click 'Create in Rosterfy')
parentInit.SJV_Sync_State__c = 'Ready';
update parentInit;

day1Init.SJV_Sync_State__c = 'Ready';
update day1Init;

day2Init.SJV_Sync_State__c = 'Ready';
update day2Init;

// 11. Create Sarah's Workshop Tasks & Reminders
List<Task> demoTasks = new List<Task>{
    new Task(
        WhatId = opp.Id,
        WhoId = contactId,
        Subject = 'Follow up commercial quote with Marcus Vance',
        Description = 'Contact Marcus to confirm quote details, medical coverage scope, and validity date.',
        Status = 'Completed',
        Priority = 'High',
        ActivityDate = Date.today().addDays(-2)
    ),
    new Task(
        WhatId = day1Init.Id,
        Subject = 'Ask Southern Metro Division about emergency vehicle and driver coverage',
        Description = 'Coordinate with division commander regarding 4WD response vehicle availability for Catani Gardens lawn.',
        Status = 'In Progress',
        Priority = 'Normal',
        ActivityDate = Date.today().addDays(1)
    ),
    new Task(
        WhatId = day1Init.Id,
        Subject = 'Review Catani Gardens access gate 3 with Clinical Commander',
        Description = 'Confirm parking permits, induction details, and ingress route for St John command vehicle off Pier Road.',
        Status = 'Completed',
        Priority = 'Normal',
        ActivityDate = Date.today().addDays(-1)
    ),
    new Task(
        WhatId = opp.Id,
        WhoId = contactId,
        Subject = 'Schedule 2027 festival renewal & post-event debrief with committee',
        Description = 'Recurring annual booking task: debrief with Marcus Vance and present multi-year health services agreement.',
        Status = 'Not Started',
        Priority = 'Normal',
        ActivityDate = eventEndDate.addDays(14)
    )
};
insert demoTasks;
System.debug('Created ' + demoTasks.size() + ' follow-up tasks (Sarah\'s workshop examples).');

// 12. Create a fresh Inbound Lead for Live Conversion Demonstration
SJV_EnquirySubmissionService.EnquiryRequest demoLeadReq = new SJV_EnquirySubmissionService.EnquiryRequest();
demoLeadReq.firstName = 'Elena';
demoLeadReq.lastName = 'Rostova';
demoLeadReq.organisationName = 'Geelong Events Collective';
demoLeadReq.email = 'elena.rostova@geelongevents.example.com';
demoLeadReq.phone = '0433 987 654';
demoLeadReq.customerRole = 'Safety & Operations Coordinator';
demoLeadReq.eventName = 'Geelong Waterfront Fun Run 2026';
demoLeadReq.eventType = 'Sporting Event';
demoLeadReq.expectedAttendance = 3500;
demoLeadReq.venueName = 'Eastern Beach Reserve';
demoLeadReq.venueAddress = '95 Eastern Beach Rd, Geelong VIC 3220';
demoLeadReq.startDate = Date.today().addDays(60);
demoLeadReq.endDate = Date.today().addDays(60);
demoLeadReq.dailyHoursDescription = '07:30 - 14:00';
demoLeadReq.indoorOutdoor = 'Outdoor';
demoLeadReq.alcoholPresent = 'No';
demoLeadReq.highRiskActivities = 'Other';
demoLeadReq.firstAidPostAvailable = 'Yes';
demoLeadReq.requestedCoverageNotes = 'Finish line medical tent plus mobile bike first responders along waterfront track.';
demoLeadReq.setupAccessInstructions = 'Early morning vehicle drop-off before 06:30 road closures.';
demoLeadReq.submissionKey = 'SJV-DEMO-LIVE-LEAD-001';
SJV_EnquirySubmissionService.EnquiryResult freshLeadRes = SJV_EnquirySubmissionService.submitEnquiry(demoLeadReq);
System.debug('Created fresh Live Demo Lead: ' + freshLeadRes.leadId + ' with Enquiry: ' + freshLeadRes.enquiryNumber);

System.debug('--- DEMO SEED COMPLETE ---');
System.debug('Opportunity Closed Won: ' + oppWon.Id);
System.debug('Volunteer Initiative Ready for Rosterfy Transfer: ' + day1Init.Id);
