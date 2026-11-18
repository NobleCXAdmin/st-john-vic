/**
 * @description Risk Assessment Engine and Version Control Service for St John VIC event services.
 *              Evaluates risk factors deterministically, creates versioned assessments and requirements snapshots,
 *              maintains version audit trails, and separates internal delivery cost from customer selling price.
 */
public without sharing class SJV_RiskAssessmentService {

    public static final String DISCLAIMER = 'Illustrative demo rules, not approved for operational use';
    public static final String RULE_VERSION = 'v1.0-Illustrative';

    // Standard rates for demo
    public static final Decimal FIRST_AIDER_COST_RATE = 35.00;
    public static final Decimal FIRST_AIDER_SELL_RATE = 75.00;
    public static final Decimal HCP_COST_RATE = 65.00;
    public static final Decimal HCP_SELL_RATE = 135.00;
    public static final Decimal POST_COST_FLAT = 100.00;
    public static final Decimal POST_SELL_FLAT = 250.00;

    public class AssessmentInput {
        @AuraEnabled public Id initiativeId;
        @AuraEnabled public Integer expectedAttendance;
        @AuraEnabled public String indoorOutdoor; // Indoor, Outdoor, Both Indoor and Outdoor
        @AuraEnabled public String alcoholPresent; // Yes, No, Unsure
        @AuraEnabled public String highRiskActivities; // None, Watersports / Swimming, High Speed / Vehicles, Combat Sports, Extreme Weather / Heat, Other
        @AuraEnabled public String firstAidPostNeeded; // Yes, No
        @AuraEnabled public Decimal durationHours;
        @AuraEnabled public Date serviceDate;
        @AuraEnabled public String reasonForChange;
        @AuraEnabled public Boolean submitForReview;
    }

    public class AssessmentResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id assessmentId;
        @AuraEnabled public Integer versionNumber;
        @AuraEnabled public String uniqueVersionKey;
        @AuraEnabled public Decimal totalScore;
        @AuraEnabled public String riskBand;
        @AuraEnabled public Integer proposedStaffCount;
        @AuraEnabled public Decimal proposedStaffHours;
        @AuraEnabled public Decimal internalCostTotal;
        @AuraEnabled public Decimal sellingPriceTotal;
        @AuraEnabled public Decimal estimatedMargin;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
        @AuraEnabled public List<SJV_Resource_Requirement__c> requirements;
    }

    public class VersionComparison {
        @AuraEnabled public Integer versionA;
        @AuraEnabled public Integer versionB;
        @AuraEnabled public Decimal scoreDiff;
        @AuraEnabled public Integer staffCountDiff;
        @AuraEnabled public Decimal staffHoursDiff;
        @AuraEnabled public Decimal internalCostDiff;
        @AuraEnabled public Decimal sellingPriceDiff;
        @AuraEnabled public String summaryNotes;
    }

    /**
     * @description Calculates and creates a new or revised version of a Risk Assessment.
     */
    @AuraEnabled
    public static AssessmentResult calculateAndSaveAssessment(AssessmentInput input) {
        AssessmentResult res = new AssessmentResult();
        Savepoint sp = Database.setSavepoint();

        try {
            if (input == null || input.initiativeId == null) {
                res.success = false;
                res.message = 'Initiative or Opportunity ID is required.';
                return res;
            }

            Id targetInitId = null;
            Id targetOppId = null;

            String sObjType = input.initiativeId.getSobjectType().getDescribe().getName();
            if (sObjType == 'Opportunity') {
                targetOppId = input.initiativeId;
                List<Opportunity> oppList = [
                    SELECT Id, SJV_Volunteer_Initiative__c FROM Opportunity WHERE Id = :targetOppId LIMIT 1
                ];
                if (!oppList.isEmpty() && oppList[0].SJV_Volunteer_Initiative__c != null) {
                    targetInitId = oppList[0].SJV_Volunteer_Initiative__c;
                } else {
                    List<VolunteerInitiative> existingInits = [
                        SELECT Id FROM VolunteerInitiative WHERE SJV_Opportunity__c = :targetOppId LIMIT 1
                    ];
                    if (!existingInits.isEmpty()) {
                        targetInitId = existingInits[0].Id;
                    }
                }
            } else {
                targetInitId = input.initiativeId;
            }

            VolunteerInitiative init = null;
            if (targetInitId != null) {
                init = [
                    SELECT Id, Name, SJV_Opportunity__c, StartDate, EndDate, SJV_Timezone__c,
                           SJV_Current_Approved_Assessment__c, SJV_Approved_Plan_Revision__c
                    FROM VolunteerInitiative
                    WHERE Id = :targetInitId
                    LIMIT 1
                ];
                if (targetOppId == null) {
                    targetOppId = init.SJV_Opportunity__c;
                }
            }

            // Determine version number
            List<SJV_Risk_Assessment__c> priorList = (targetInitId != null) ? [
                SELECT Id, Version_Number__c, Status__c, Total_Risk_Score__c, Estimated_Internal_Cost__c, Estimated_Selling_Price__c
                FROM SJV_Risk_Assessment__c
                WHERE Volunteer_Initiative__c = :targetInitId
                ORDER BY Version_Number__c DESC
                LIMIT 1
            ] : [
                SELECT Id, Version_Number__c, Status__c, Total_Risk_Score__c, Estimated_Internal_Cost__c, Estimated_Selling_Price__c
                FROM SJV_Risk_Assessment__c
                WHERE Opportunity__c = :targetOppId
                ORDER BY Version_Number__c DESC
                LIMIT 1
            ];

            Integer nextVersion = 1;
            Id priorId = null;
            if (!priorList.isEmpty()) {
                nextVersion = Integer.valueOf(priorList[0].Version_Number__c) + 1;
                priorId = priorList[0].Id;
            }

            // Defaults
            Integer attendance = input.expectedAttendance != null ? input.expectedAttendance : 500;
            String setting = String.isNotBlank(input.indoorOutdoor) ? input.indoorOutdoor : 'Outdoor';
            String alcohol = String.isNotBlank(input.alcoholPresent) ? input.alcoholPresent : 'No';
            String highRisk = String.isNotBlank(input.highRiskActivities) ? input.highRiskActivities : 'None';
            String postNeeded = String.isNotBlank(input.firstAidPostNeeded) ? input.firstAidPostNeeded : 'Yes';
            Decimal hours = (input.durationHours != null && input.durationHours > 0) ? input.durationHours : 4.0;
            Date sDate = input.serviceDate != null ? input.serviceDate : ((init != null && init.StartDate != null) ? init.StartDate : Date.today().addDays(30));

            // Scoring calculation
            Decimal score = 0;
            List<SJV_Risk_Answer__c> answers = new List<SJV_Risk_Answer__c>();

            // 1. Attendance scoring
            Decimal attScore = 10;
            String attExpl = 'Standard community attendance (<1,000)';
            if (attendance >= 10000) {
                attScore = 65;
                attExpl = 'Major crowd (>10,000 attendees)';
            } else if (attendance >= 3000) {
                attScore = 45;
                attExpl = 'Large attendance (3,000-10,000)';
            } else if (attendance >= 1000) {
                attScore = 25;
                attExpl = 'Medium attendance (1,000-3,000)';
            }
            score += attScore;
            answers.add(createAnswerRecord('ATTENDANCE', 'Expected Attendance', 'Demographics', String.valueOf(attendance), attScore, attExpl));

            // 2. Setting scoring
            Decimal setScore = 15;
            String setExpl = 'Outdoor venue requires portable response coverage';
            if (setting == 'Indoor') {
                setScore = 5;
                setExpl = 'Indoor facility with defined entry and shelter';
            } else if (setting == 'Both Indoor and Outdoor') {
                setScore = 10;
                setExpl = 'Mixed indoor/outdoor operational perimeter';
            }
            score += setScore;
            answers.add(createAnswerRecord('VENUE_SETTING', 'Venue Setting', 'Environment', setting, setScore, setExpl));

            // 3. Alcohol scoring
            Decimal alcScore = 0;
            String alcExpl = 'No alcohol service reported';
            if (alcohol == 'Yes') {
                alcScore = 25;
                alcExpl = 'Licensed alcohol service increases intoxication and trauma probability';
            } else if (alcohol == 'Unsure') {
                alcScore = 10;
                alcExpl = 'Alcohol status unconfirmed - precautionary weighting applied';
            }
            score += alcScore;
            answers.add(createAnswerRecord('ALCOHOL', 'Alcohol Service', 'Risk Factors', alcohol, alcScore, alcExpl));

            // 4. High risk activities
            Decimal actScore = 0;
            String actExpl = 'Low-risk community profile';
            if (highRisk != 'None' && String.isNotBlank(highRisk)) {
                actScore = 30;
                actExpl = 'High-risk activity identified (' + highRisk + ') - triggers clinical escalation';
            }
            score += actScore;
            answers.add(createAnswerRecord('HIGH_RISK_ACTIVITIES', 'High-Risk Activities', 'Clinical Hazards', highRisk, actScore, actExpl));

            // Determine Risk Band
            String band = 'Low';
            if (score >= 71 || actScore >= 30) {
                band = 'High / Clinical Review Required';
            } else if (score >= 41) {
                band = 'Medium';
            }

            // Calculate Staffing & Resource Requirements
            List<SJV_Resource_Requirement__c> reqList = new List<SJV_Resource_Requirement__c>();

            // First Aiders quantity
            Integer faQty = 2;
            if (attendance >= 10000) {
                faQty = 8;
            } else if (attendance >= 5000) {
                faQty = 6;
            } else if (attendance >= 2500) {
                faQty = 4;
            } else if (attendance >= 1000) {
                faQty = 3;
            }

            Decimal faTotalHours = faQty * hours;
            Decimal faInternalCost = faTotalHours * FIRST_AIDER_COST_RATE;
            Decimal faSellingPrice = faTotalHours * FIRST_AIDER_SELL_RATE;

            reqList.add(new SJV_Resource_Requirement__c(
                Requirement_Key__c = 'REQ-FA-' + nextVersion + '-01',
                Category__c = 'Staff',
                Role_or_Item_Code__c = 'FIRST_AIDER',
                Role_or_Item_Name__c = 'Event First Aider',
                Quantity__c = faQty,
                Service_Date__c = sDate,
                Duration_Hours__c = hours,
                Total_Staff_Hours__c = faTotalHours,
                Demand_Type__c = 'Volunteer',
                Internal_Cost_Rate__c = FIRST_AIDER_COST_RATE,
                Selling_Rate__c = FIRST_AIDER_SELL_RATE,
                Internal_Cost_Total__c = faInternalCost,
                Selling_Price_Total__c = faSellingPrice,
                Billable_Units__c = faTotalHours,
                Unit_Basis__c = 'Hourly',
                Origin__c = 'Rule Engine'
            ));

            // Health Care Professional (Registered Nurse / Paramedic) if high risk or alcohol
            Integer hcpQty = 0;
            Decimal hcpTotalHours = 0;
            Decimal hcpInternalCost = 0;
            Decimal hcpSellingPrice = 0;

            if (band == 'High / Clinical Review Required' || alcohol == 'Yes' || attendance >= 5000) {
                hcpQty = (attendance >= 10000) ? 2 : 1;
                hcpTotalHours = hcpQty * hours;
                hcpInternalCost = hcpTotalHours * HCP_COST_RATE;
                hcpSellingPrice = hcpTotalHours * HCP_SELL_RATE;

                reqList.add(new SJV_Resource_Requirement__c(
                    Requirement_Key__c = 'REQ-HCP-' + nextVersion + '-02',
                    Category__c = 'Staff',
                    Role_or_Item_Code__c = 'HCP_PARAMEDIC',
                    Role_or_Item_Name__c = 'Health Care Professional (Registered Nurse / Paramedic)',
                    Quantity__c = hcpQty,
                    Service_Date__c = sDate,
                    Duration_Hours__c = hours,
                    Total_Staff_Hours__c = hcpTotalHours,
                    Demand_Type__c = 'Paid Staff',
                    Internal_Cost_Rate__c = HCP_COST_RATE,
                    Selling_Rate__c = HCP_SELL_RATE,
                    Internal_Cost_Total__c = hcpInternalCost,
                    Selling_Price_Total__c = hcpSellingPrice,
                    Billable_Units__c = hcpTotalHours,
                    Unit_Basis__c = 'Hourly',
                    Origin__c = 'Rule Engine'
                ));
            }

            // Equipment: First Aid Post / Tent
            Decimal eqInternalCost = 0;
            Decimal eqSellingPrice = 0;
            if (postNeeded == 'Yes' || setting != 'Indoor') {
                eqInternalCost = POST_COST_FLAT;
                eqSellingPrice = POST_SELL_FLAT;

                reqList.add(new SJV_Resource_Requirement__c(
                    Requirement_Key__c = 'REQ-EQ-' + nextVersion + '-03',
                    Category__c = 'Equipment',
                    Role_or_Item_Code__c = 'FA_POST_KIT',
                    Role_or_Item_Name__c = 'Mobile First Aid Marquee & Clinical Response Kit',
                    Quantity__c = 1,
                    Service_Date__c = sDate,
                    Duration_Hours__c = hours,
                    Total_Staff_Hours__c = 0,
                    Demand_Type__c = 'Asset',
                    Internal_Cost_Rate__c = POST_COST_FLAT,
                    Selling_Rate__c = POST_SELL_FLAT,
                    Internal_Cost_Total__c = POST_COST_FLAT,
                    Selling_Price_Total__c = POST_SELL_FLAT,
                    Billable_Units__c = 1,
                    Unit_Basis__c = 'Per Day',
                    Origin__c = 'Rule Engine'
                ));
            }

            // Totals
            Integer totalStaffCount = faQty + hcpQty;
            Decimal totalStaffHours = faTotalHours + hcpTotalHours;
            Decimal totalInternalCost = faInternalCost + hcpInternalCost + eqInternalCost;
            Decimal totalSellingPrice = faSellingPrice + hcpSellingPrice + eqSellingPrice;

            // 1. Create SJV_Risk_Assessment__c record
            SJV_Risk_Assessment__c ra = new SJV_Risk_Assessment__c();
            ra.Volunteer_Initiative__c = targetInitId;
            ra.Opportunity__c = targetOppId;
            ra.Event_Day_Key__c = (init != null) ? init.Name : 'Event Assessment';
            ra.Version_Number__c = nextVersion;
            ra.Unique_Version_Key__c = (targetInitId != null ? String.valueOf(targetInitId) : String.valueOf(targetOppId)) + '-V' + nextVersion;
            ra.Previous_Assessment__c = priorId;
            ra.Status__c = (input.submitForReview == true) ? 'Submitted for Review' : 'Draft';
            ra.Reason_For_Change__c = String.isNotBlank(input.reasonForChange) ? input.reasonForChange : (nextVersion == 1 ? 'Initial enquiry assessment' : 'Revised conditions');
            ra.Rule_Set_Version__c = RULE_VERSION;
            ra.Rule_Set_Disclaimer__c = DISCLAIMER;
            ra.Total_Risk_Score__c = score;
            ra.Risk_Band__c = band;
            ra.Proposed_Staff_Count__c = totalStaffCount;
            ra.Proposed_Staff_Hours__c = totalStaffHours;
            ra.Estimated_Internal_Cost__c = totalInternalCost;
            ra.Estimated_Selling_Price__c = totalSellingPrice;
            ra.Reviewer_Decision__c = (band == 'High / Clinical Review Required') ? 'Pending' : 'Approved';
            insert ra;

            // 2. Insert Answers
            for (SJV_Risk_Answer__c a : answers) {
                a.Risk_Assessment__c = ra.Id;
            }
            insert answers;

            // 3. Insert Requirements
            for (SJV_Resource_Requirement__c rr : reqList) {
                rr.Risk_Assessment__c = ra.Id;
            }
            insert reqList;

            // Update Opportunity review status & cost forecast
            if (targetOppId != null) {
                Opportunity opp = [
                    SELECT Id, SJV_Clinical_Review_Status__c, SJV_Internal_Cost__c, SJV_Estimated_Margin__c, Amount
                    FROM Opportunity
                    WHERE Id = :targetOppId
                ];
                if (band == 'High / Clinical Review Required') {
                    opp.SJV_Clinical_Review_Status__c = 'Pending Review';
                } else {
                    opp.SJV_Clinical_Review_Status__c = 'Approved';
                }
                opp.SJV_Internal_Cost__c = totalInternalCost;
                opp.SJV_Estimated_Margin__c = (opp.Amount != null ? opp.Amount : totalSellingPrice) - totalInternalCost;
                update opp;
            }

            res.success = true;
            res.assessmentId = ra.Id;
            res.versionNumber = nextVersion;
            res.uniqueVersionKey = ra.Unique_Version_Key__c;
            res.totalScore = score;
            res.riskBand = band;
            res.proposedStaffCount = totalStaffCount;
            res.proposedStaffHours = totalStaffHours;
            res.internalCostTotal = totalInternalCost;
            res.sellingPriceTotal = totalSellingPrice;
            res.estimatedMargin = totalSellingPrice - totalInternalCost;
            res.status = ra.Status__c;
            res.requirements = reqList;
            res.message = 'Assessment v' + nextVersion + ' created successfully. Risk score: ' + score + ' (' + band + '). Staff required: ' + totalStaffCount + '.';
            return res;

        } catch (Exception ex) {
            Database.rollback(sp);
            res.success = false;
            res.message = 'Error calculating assessment: ' + ex.getMessage();
            return res;
        }
    }

    /**
     * @description Approves an assessment version. Sets previous approved version to Superseded.
     */
    @AuraEnabled
    public static AssessmentResult approveAssessment(Id assessmentId, String comments) {
        AssessmentResult res = new AssessmentResult();
        Savepoint sp = Database.setSavepoint();

        try {
            SJV_Risk_Assessment__c ra = [
                SELECT Id, Version_Number__c, Status__c, Volunteer_Initiative__c, Opportunity__c,
                       Total_Risk_Score__c, Risk_Band__c, Proposed_Staff_Count__c, Proposed_Staff_Hours__c,
                       Estimated_Internal_Cost__c, Estimated_Selling_Price__c
                FROM SJV_Risk_Assessment__c
                WHERE Id = :assessmentId
                LIMIT 1
            ];

            // Supersede any older approved versions for this initiative or opportunity
            List<SJV_Risk_Assessment__c> priorApproved = (ra.Volunteer_Initiative__c != null) ? [
                SELECT Id, Status__c
                FROM SJV_Risk_Assessment__c
                WHERE Volunteer_Initiative__c = :ra.Volunteer_Initiative__c
                  AND Status__c = 'Approved'
                  AND Id != :ra.Id
            ] : (ra.Opportunity__c != null ? [
                SELECT Id, Status__c
                FROM SJV_Risk_Assessment__c
                WHERE Opportunity__c = :ra.Opportunity__c
                  AND Status__c = 'Approved'
                  AND Id != :ra.Id
            ] : new List<SJV_Risk_Assessment__c>());
            for (SJV_Risk_Assessment__c p : priorApproved) {
                p.Status__c = 'Superseded';
            }
            if (!priorApproved.isEmpty()) {
                update priorApproved;
            }

            ra.Status__c = 'Approved';
            ra.Reviewer_Decision__c = 'Approved';
            ra.Reviewer__c = UserInfo.getUserId();
            ra.Reviewed_Date_Time__c = System.now();
            ra.Review_Comments__c = comments;
            ra.Approval_Set_Reference__c = 'APP-' + ra.Id + '-' + System.currentTimeMillis();
            update ra;

            // Stamp initiative with current approved assessment
            if (ra.Volunteer_Initiative__c != null) {
                VolunteerInitiative vi = [
                    SELECT Id, SJV_Current_Approved_Assessment__c, SJV_Approved_Plan_Revision__c
                    FROM VolunteerInitiative
                    WHERE Id = :ra.Volunteer_Initiative__c
                ];
                vi.SJV_Current_Approved_Assessment__c = ra.Id;
                vi.SJV_Approved_Plan_Revision__c = ra.Version_Number__c;
                update vi;
            }

            // Update Opportunity clinical and operations review status
            if (ra.Opportunity__c != null) {
                Opportunity opp = [SELECT Id FROM Opportunity WHERE Id = :ra.Opportunity__c];
                opp.SJV_Clinical_Review_Status__c = 'Approved';
                opp.SJV_Operations_Review_Status__c = 'Approved';
                update opp;
            }

            res.success = true;
            res.assessmentId = ra.Id;
            res.versionNumber = Integer.valueOf(ra.Version_Number__c);
            res.status = 'Approved';
            res.message = 'Assessment v' + ra.Version_Number__c + ' approved successfully. Operational plan revision updated.';
            return res;

        } catch (Exception ex) {
            Database.rollback(sp);
            res.success = false;
            res.message = 'Error approving assessment: ' + ex.getMessage();
            return res;
        }
    }

    /**
     * @description Compares two versions of assessments for an event.
     */
    @AuraEnabled
    public static VersionComparison compareVersions(Id assessmentIdA, Id assessmentIdB) {
        VersionComparison comp = new VersionComparison();
        Map<Id, SJV_Risk_Assessment__c> raMap = new Map<Id, SJV_Risk_Assessment__c>([
            SELECT Id, Version_Number__c, Total_Risk_Score__c, Proposed_Staff_Count__c,
                   Proposed_Staff_Hours__c, Estimated_Internal_Cost__c, Estimated_Selling_Price__c
            FROM SJV_Risk_Assessment__c
            WHERE Id IN (:assessmentIdA, :assessmentIdB)
        ]);

        if (raMap.containsKey(assessmentIdA) && raMap.containsKey(assessmentIdB)) {
            SJV_Risk_Assessment__c a = raMap.get(assessmentIdA);
            SJV_Risk_Assessment__c b = raMap.get(assessmentIdB);

            comp.versionA = Integer.valueOf(a.Version_Number__c);
            comp.versionB = Integer.valueOf(b.Version_Number__c);
            comp.scoreDiff = (b.Total_Risk_Score__c != null ? b.Total_Risk_Score__c : 0) - (a.Total_Risk_Score__c != null ? a.Total_Risk_Score__c : 0);
            comp.staffCountDiff = Integer.valueOf((b.Proposed_Staff_Count__c != null ? b.Proposed_Staff_Count__c : 0) - (a.Proposed_Staff_Count__c != null ? a.Proposed_Staff_Count__c : 0));
            comp.staffHoursDiff = (b.Proposed_Staff_Hours__c != null ? b.Proposed_Staff_Hours__c : 0) - (a.Proposed_Staff_Hours__c != null ? a.Proposed_Staff_Hours__c : 0);
            comp.internalCostDiff = (b.Estimated_Internal_Cost__c != null ? b.Estimated_Internal_Cost__c : 0) - (a.Estimated_Internal_Cost__c != null ? a.Estimated_Internal_Cost__c : 0);
            comp.sellingPriceDiff = (b.Estimated_Selling_Price__c != null ? b.Estimated_Selling_Price__c : 0) - (a.Estimated_Selling_Price__c != null ? a.Estimated_Selling_Price__c : 0);
            comp.summaryNotes = 'Comparison v' + comp.versionA + ' -> v' + comp.versionB + ': Staff Delta: ' + comp.staffCountDiff + ' headcount (' + comp.staffHoursDiff + ' hrs). Internal Cost Delta: $' + comp.internalCostDiff;
        }
        return comp;
    }

    private static SJV_Risk_Answer__c createAnswerRecord(String key, String text, String cat, String val, Decimal contrib, String expl) {
        SJV_Risk_Answer__c ans = new SJV_Risk_Answer__c();
        ans.Question_Key__c = key;
        ans.Question_Text__c = text;
        ans.Question_Category__c = cat;
        ans.Answer_Value__c = val;
        ans.Score_Contribution__c = contrib;
        ans.Scoring_Explanation__c = expl;
        return ans;
    }
}

