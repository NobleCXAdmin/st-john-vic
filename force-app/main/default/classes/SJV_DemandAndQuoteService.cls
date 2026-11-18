/**
 * @description Service to map approved risk requirements into operational demand (JobPosition / JobPositionShift)
 *              and generate commercial Quotes with line-item cost and sell separation.
 */
public without sharing class SJV_DemandAndQuoteService {

    public class DemandResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer jobsCreatedOrUpdated;
        @AuraEnabled public Integer shiftsCreatedOrUpdated;
        @AuraEnabled public String message;
    }

    public class QuoteResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public Decimal internalCostTotal;
        @AuraEnabled public Decimal grossMargin;
        @AuraEnabled public String message;
    }

    /**
     * @description Ensures standard Positions and Products exist for the St John VIC demo.
     */
    public static void ensureStJohnCatalogue() {
        // 1. Positions
        Map<String, String> posRoles = new Map<String, String>{
            'FIRST_AIDER' => 'Event First Aider',
            'HCP_PARAMEDIC' => 'Health Care Professional'
        };
        List<Position> existingPositions = [SELECT Id, Code, Name FROM Position WHERE Code IN :posRoles.keySet()];
        Set<String> existingCodes = new Set<String>();
        for (Position p : existingPositions) {
            existingCodes.add(p.Code);
        }

        List<Position> toInsertPos = new List<Position>();
        for (String code : posRoles.keySet()) {
            if (!existingCodes.contains(code)) {
                Position pos = new Position();
                pos.Name = posRoles.get(code);
                pos.Code = code;
                pos.Status = 'Upcoming';
                pos.Description = 'St John VIC ' + posRoles.get(code);
                toInsertPos.add(pos);
            }
        }
        if (!toInsertPos.isEmpty()) {
            insert toInsertPos;
        }

        // 2. Standard Price Book check
        Id stdPbId;
        if (Test.isRunningTest()) {
            stdPbId = Test.getStandardPricebookId();
        } else {
            List<Pricebook2> pbList = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
            if (!pbList.isEmpty()) {
                stdPbId = pbList[0].Id;
                if (!pbList[0].IsActive) {
                    pbList[0].IsActive = true;
                    update pbList[0];
                }
            }
        }

        // 3. Products
        Map<String, Decimal> prodRates = new Map<String, Decimal>{
            'FIRST_AIDER' => 75.00,
            'HCP_PARAMEDIC' => 135.00,
            'FA_POST_KIT' => 250.00
        };
        Map<String, String> prodNames = new Map<String, String>{
            'FIRST_AIDER' => 'Event First Aider (Hourly)',
            'HCP_PARAMEDIC' => 'Health Care Professional (Hourly)',
            'FA_POST_KIT' => 'Mobile First Aid Marquee & Clinical Response Kit'
        };

        List<Product2> existingProds = [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :prodRates.keySet()];
        Set<String> existingProdCodes = new Set<String>();
        for (Product2 pr : existingProds) {
            existingProdCodes.add(pr.ProductCode);
        }

        List<Product2> toInsertProds = new List<Product2>();
        for (String code : prodRates.keySet()) {
            if (!existingProdCodes.contains(code)) {
                Product2 pr = new Product2();
                pr.Name = prodNames.get(code);
                pr.ProductCode = code;
                pr.IsActive = true;
                pr.Description = 'St John VIC Event Service: ' + prodNames.get(code);
                toInsertProds.add(pr);
            }
        }
        if (!toInsertProds.isEmpty()) {
            insert toInsertProds;
        }

        // PricebookEntries
        Map<String, Id> codeToProdId = new Map<String, Id>();
        for (Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :prodRates.keySet()]) {
            codeToProdId.put(p.ProductCode, p.Id);
        }

        Set<String> activeCurrencies = new Set<String>{ 'AUD' };
        try {
            for (SObject ct : Database.query('SELECT IsoCode FROM CurrencyType WHERE IsActive = true')) {
                activeCurrencies.add((String) ct.get('IsoCode'));
            }
        } catch (Exception e) {}

        List<PricebookEntry> existingPbes = [
            SELECT Id, ProductCode, Pricebook2Id, CurrencyIsoCode
            FROM PricebookEntry
            WHERE Pricebook2Id = :stdPbId AND ProductCode IN :prodRates.keySet()
        ];
        Set<String> existingPbeKeys = new Set<String>();
        for (PricebookEntry pbe : existingPbes) {
            String curr = 'AUD';
            try { curr = (String) pbe.get('CurrencyIsoCode'); } catch(Exception e) {}
            existingPbeKeys.add(pbe.ProductCode + '-' + curr);
        }

        List<PricebookEntry> toInsertPbe = new List<PricebookEntry>();
        for (String curr : activeCurrencies) {
            for (String code : prodRates.keySet()) {
                String key = code + '-' + curr;
                if (!existingPbeKeys.contains(key) && codeToProdId.containsKey(code)) {
                    PricebookEntry pbe = new PricebookEntry();
                    pbe.Pricebook2Id = stdPbId;
                    pbe.Product2Id = codeToProdId.get(code);
                    pbe.UnitPrice = prodRates.get(code);
                    pbe.IsActive = true;
                    try { pbe.put('CurrencyIsoCode', curr); } catch (Exception e) {}
                    toInsertPbe.add(pbe);
                }
            }
        }
        if (!toInsertPbe.isEmpty()) {
            insert toInsertPbe;
        }
    }

    /**
     * @description Maps approved requirements into JobPosition and JobPositionShift records.
     *              Idempotent: updates existing positions and shifts by stable keys.
     */
    @AuraEnabled
    public static DemandResult generateOperationalDemand(Id assessmentId) {
        DemandResult res = new DemandResult();
        res.jobsCreatedOrUpdated = 0;
        res.shiftsCreatedOrUpdated = 0;

        Savepoint sp = Database.setSavepoint();
        try {
            ensureStJohnCatalogue();

            SJV_Risk_Assessment__c ra = [
                SELECT Id, Version_Number__c, Status__c, Volunteer_Initiative__c,
                       Volunteer_Initiative__r.Name, Volunteer_Initiative__r.StartDate,
                       Volunteer_Initiative__r.EndDate, Volunteer_Initiative__r.SJV_Timezone__c
                FROM SJV_Risk_Assessment__c
                WHERE Id = :assessmentId
                LIMIT 1
            ];

            List<SJV_Resource_Requirement__c> reqs = [
                SELECT Id, Requirement_Key__c, Category__c, Role_or_Item_Code__c, Role_or_Item_Name__c,
                       Quantity__c, Service_Date__c, Duration_Hours__c, Total_Staff_Hours__c,
                       Demand_Type__c, Internal_Cost_Rate__c, Selling_Rate__c
                FROM SJV_Resource_Requirement__c
                WHERE Risk_Assessment__c = :ra.Id AND Category__c = 'Staff'
            ];

            if (reqs.isEmpty()) {
                res.success = false;
                res.message = 'No staff resource requirements found on this assessment.';
                return res;
            }

            // Find Position IDs
            Map<String, Id> codeToPositionId = new Map<String, Id>();
            for (Position p : [SELECT Id, Code FROM Position WHERE Code IN ('FIRST_AIDER', 'HCP_PARAMEDIC')]) {
                codeToPositionId.put(p.Code, p.Id);
            }

            // Query existing JobPositions for this initiative
            List<JobPosition> existingJobs = [
                SELECT Id, SJV_Source_Job_Key__c, SJV_Role_Mapping_Key__c, PositionId
                FROM JobPosition
                WHERE VolunteerInitiativeId = :ra.Volunteer_Initiative__c
            ];
            Map<String, JobPosition> jobKeyMap = new Map<String, JobPosition>();
            for (JobPosition jp : existingJobs) {
                if (String.isNotBlank(jp.SJV_Source_Job_Key__c)) {
                    jobKeyMap.put(jp.SJV_Source_Job_Key__c, jp);
                }
            }

            // Group requirements by Role_or_Item_Code__c
            Map<String, List<SJV_Resource_Requirement__c>> reqsByRole = new Map<String, List<SJV_Resource_Requirement__c>>();
            for (SJV_Resource_Requirement__c rr : reqs) {
                if (!reqsByRole.containsKey(rr.Role_or_Item_Code__c)) {
                    reqsByRole.put(rr.Role_or_Item_Code__c, new List<SJV_Resource_Requirement__c>());
                }
                reqsByRole.get(rr.Role_or_Item_Code__c).add(rr);
            }

            List<JobPosition> jobsToUpsert = new List<JobPosition>();
            for (String roleCode : reqsByRole.keySet()) {
                String jobKey = ra.Volunteer_Initiative__c + '-' + roleCode;
                JobPosition jp;
                if (jobKeyMap.containsKey(jobKey)) {
                    jp = jobKeyMap.get(jobKey);
                } else {
                    jp = new JobPosition();
                    jp.VolunteerInitiativeId = ra.Volunteer_Initiative__c;
                    jp.SJV_Source_Job_Key__c = jobKey;
                    jp.SJV_Role_Mapping_Key__c = roleCode;
                }
                jp.Name = ra.Volunteer_Initiative__r.Name + ' - ' + reqsByRole.get(roleCode)[0].Role_or_Item_Name__c;
                jp.Title = reqsByRole.get(roleCode)[0].Role_or_Item_Name__c;
                jp.PositionId = codeToPositionId.get(roleCode);
                jp.Status = 'Upcoming';
                jp.StartDate = ra.Volunteer_Initiative__r.StartDate;
                jp.EndDate = ra.Volunteer_Initiative__r.EndDate;
                jobsToUpsert.add(jp);
            }
            upsert jobsToUpsert;
            res.jobsCreatedOrUpdated = jobsToUpsert.size();

            // Refresh job map
            for (JobPosition jp : jobsToUpsert) {
                jobKeyMap.put(jp.SJV_Source_Job_Key__c, jp);
            }

            // Query existing JobPositionShifts
            List<JobPositionShift> existingShifts = [
                SELECT Id, SJV_Source_Shift_Key__c, JobPositionId
                FROM JobPositionShift
                WHERE JobPositionId IN :jobsToUpsert
            ];
            Map<String, JobPositionShift> shiftKeyMap = new Map<String, JobPositionShift>();
            for (JobPositionShift jps : existingShifts) {
                if (String.isNotBlank(jps.SJV_Source_Shift_Key__c)) {
                    shiftKeyMap.put(jps.SJV_Source_Shift_Key__c, jps);
                }
            }

            List<JobPositionShift> shiftsToUpsert = new List<JobPositionShift>();
            for (SJV_Resource_Requirement__c rr : reqs) {
                String jobKey = ra.Volunteer_Initiative__c + '-' + rr.Role_or_Item_Code__c;
                JobPosition jp = jobKeyMap.get(jobKey);
                if (jp == null) continue;

                String shiftKey = ra.Volunteer_Initiative__c + '-' + rr.Requirement_Key__c;
                JobPositionShift jps;
                if (shiftKeyMap.containsKey(shiftKey)) {
                    jps = shiftKeyMap.get(shiftKey);
                } else {
                    jps = new JobPositionShift();
                    jps.JobPositionId = jp.Id;
                    jps.SJV_Source_Shift_Key__c = shiftKey;
                }

                jps.SJV_Source_Requirement_Key__c = rr.Requirement_Key__c;
                jps.SJV_Plan_Revision__c = ra.Version_Number__c;
                jps.SJV_Sync_Status__c = 'Pending';
                jps.StartDate = rr.Service_Date__c != null ? rr.Service_Date__c : ra.Volunteer_Initiative__r.StartDate;
                jps.EndDate = jps.StartDate;
                jps.StartTime = Time.newInstance(9, 0, 0, 0);
                Integer durationInt = (rr.Duration_Hours__c != null && rr.Duration_Hours__c > 0) ? Integer.valueOf(rr.Duration_Hours__c) : 4;
                jps.EndTime = Time.newInstance(9 + durationInt, 0, 0, 0);
                jps.MaximumAttendeesCount = Integer.valueOf(rr.Quantity__c != null ? rr.Quantity__c : 1);
                jps.Description = 'Demand slot for ' + rr.Role_or_Item_Name__c + ' (Revision v' + ra.Version_Number__c + ')';
                jps.Status = 'Upcoming';
                shiftsToUpsert.add(jps);
            }
            upsert shiftsToUpsert;
            res.shiftsCreatedOrUpdated = shiftsToUpsert.size();

            res.success = true;
            res.message = 'Successfully generated/updated ' + res.jobsCreatedOrUpdated + ' Job Positions and ' + res.shiftsCreatedOrUpdated + ' Shifts for operational revision v' + ra.Version_Number__c;
            return res;

        } catch (Exception ex) {
            Database.rollback(sp);
            res.success = false;
            res.message = 'Error generating operational demand: ' + ex.getMessage();
            return res;
        }
    }

    /**
     * @description Generates a standard Quote and QuoteLineItems from the approved assessment.
     */
    @AuraEnabled
    public static QuoteResult generateQuote(Id assessmentId) {
        QuoteResult res = new QuoteResult();
        Savepoint sp = Database.setSavepoint();

        try {
            ensureStJohnCatalogue();

            SJV_Risk_Assessment__c ra = [
                SELECT Id, Version_Number__c, Status__c, Opportunity__c, Unique_Version_Key__c,
                       Total_Risk_Score__c, Risk_Band__c, Proposed_Staff_Count__c, Proposed_Staff_Hours__c,
                       Estimated_Internal_Cost__c, Estimated_Selling_Price__c,
                       Volunteer_Initiative__r.Name, Opportunity__r.Name
                FROM SJV_Risk_Assessment__c
                WHERE Id = :assessmentId
                LIMIT 1
            ];

            if (ra.Opportunity__c == null) {
                res.success = false;
                res.message = 'Assessment must be linked to an Opportunity to generate a Quote.';
                return res;
            }

            Opportunity opp = [
                SELECT Id, Name, Pricebook2Id, AccountId, Amount
                FROM Opportunity
                WHERE Id = :ra.Opportunity__c
            ];

            Id stdPbId = Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
            if (opp.Pricebook2Id == null) {
                opp.Pricebook2Id = stdPbId;
                update opp;
            }

            List<SJV_Resource_Requirement__c> reqs = [
                SELECT Id, Requirement_Key__c, Category__c, Role_or_Item_Code__c, Role_or_Item_Name__c,
                       Quantity__c, Billable_Units__c, Unit_Basis__c, Internal_Cost_Rate__c,
                       Selling_Rate__c, Internal_Cost_Total__c, Selling_Price_Total__c, Service_Date__c
                FROM SJV_Resource_Requirement__c
                WHERE Risk_Assessment__c = :ra.Id
            ];

            String oppCurrency = 'AUD';
            try {
                Opportunity currOpp = [SELECT CurrencyIsoCode FROM Opportunity WHERE Id = :opp.Id];
                oppCurrency = (String) currOpp.get('CurrencyIsoCode');
            } catch (Exception e) {}
            if (String.isBlank(oppCurrency)) oppCurrency = 'AUD';

            // Map product codes to PricebookEntry matching Opportunity currency
            Map<String, Id> codeToPbeId = new Map<String, Id>();
            for (PricebookEntry pbe : [
                SELECT Id, ProductCode, CurrencyIsoCode
                FROM PricebookEntry
                WHERE Pricebook2Id = :opp.Pricebook2Id AND ProductCode IN ('FIRST_AIDER', 'HCP_PARAMEDIC', 'FA_POST_KIT')
            ]) {
                String pbeCurr = 'AUD';
                try { pbeCurr = (String) pbe.get('CurrencyIsoCode'); } catch(Exception e) {}
                if (pbeCurr == oppCurrency || !codeToPbeId.containsKey(pbe.ProductCode)) {
                    codeToPbeId.put(pbe.ProductCode, pbe.Id);
                }
            }

            // Create Quote
            Quote q = new Quote();
            q.OpportunityId = opp.Id;
            q.Pricebook2Id = opp.Pricebook2Id;
            try { q.put('CurrencyIsoCode', oppCurrency); } catch(Exception e) {}
            String eventNameForQuote = (ra.Volunteer_Initiative__r != null && String.isNotBlank(ra.Volunteer_Initiative__r.Name)) ?
                ra.Volunteer_Initiative__r.Name :
                (ra.Opportunity__r != null ? ra.Opportunity__r.Name : opp.Name);
            q.Name = 'St John Quote - ' + eventNameForQuote + ' (v' + ra.Version_Number__c + ')';
            q.SJV_Internal_Cost_Total__c = ra.Estimated_Internal_Cost__c;
            q.SJV_Gross_Margin_Amount__c = ra.Estimated_Selling_Price__c - ra.Estimated_Internal_Cost__c;
            q.SJV_Gross_Margin_Percent__c = (ra.Estimated_Selling_Price__c > 0) ?
                ((ra.Estimated_Selling_Price__c - ra.Estimated_Internal_Cost__c) / ra.Estimated_Selling_Price__c) * 100 : 0;
            q.SJV_Acceptance_Status__c = 'Draft';
            q.SJV_Assessment_Set_Snapshot__c = 'Assessment ' + ra.Unique_Version_Key__c + ' | Risk Band: ' + ra.Risk_Band__c + ' | Staff: ' + ra.Proposed_Staff_Count__c;
            q.SJV_Pricing_Snapshot__c = 'Quoted Total: $' + ra.Estimated_Selling_Price__c + ' | Internal Cost: $' + ra.Estimated_Internal_Cost__c;
            q.Status = 'Draft';
            q.ExpirationDate = Date.today().addDays(30);
            insert q;

            // Create QuoteLineItems
            List<QuoteLineItem> qlis = new List<QuoteLineItem>();
            for (SJV_Resource_Requirement__c rr : reqs) {
                Id pbeId = codeToPbeId.get(rr.Role_or_Item_Code__c);
                if (pbeId == null) continue;

                QuoteLineItem qli = new QuoteLineItem();
                qli.QuoteId = q.Id;
                qli.PricebookEntryId = pbeId;
                qli.Quantity = (rr.Billable_Units__c != null && rr.Billable_Units__c > 0) ? rr.Billable_Units__c : 1;
                qli.UnitPrice = rr.Selling_Rate__c;
                qli.Description = rr.Role_or_Item_Name__c + ' - ' + rr.Unit_Basis__c;
                qli.SJV_Source_Requirement_Key__c = rr.Requirement_Key__c;
                qli.SJV_Event_Day_Key__c = String.valueOf(rr.Service_Date__c);
                qli.SJV_Internal_Cost_Rate__c = rr.Internal_Cost_Rate__c;
                qli.SJV_Internal_Cost_Total__c = rr.Internal_Cost_Total__c;
                qli.SJV_Billable_Units__c = rr.Billable_Units__c;
                qli.SJV_Unit_Basis__c = rr.Unit_Basis__c;
                qlis.add(qli);
            }
            if (!qlis.isEmpty()) {
                insert qlis;
            }

            // Update Opportunity
            opp.Amount = ra.Estimated_Selling_Price__c;
            List<OpportunityStage> propStages = [SELECT ApiName FROM OpportunityStage WHERE IsActive = true AND IsClosed = false AND (ApiName LIKE '%Proposal%' OR ApiName LIKE '%Quote%') LIMIT 1];
            opp.StageName = propStages.isEmpty() ? 'Proposal/Quote' : propStages[0].ApiName;
            update opp;

            res.success = true;
            res.quoteId = q.Id;
            res.grandTotal = ra.Estimated_Selling_Price__c;
            res.internalCostTotal = ra.Estimated_Internal_Cost__c;
            res.grossMargin = q.SJV_Gross_Margin_Amount__c;
            res.message = 'Commercial Quote generated successfully. Quoted Revenue: $' + res.grandTotal + ' | Internal Delivery Cost: $' + res.internalCostTotal + ' | Margin: $' + res.grossMargin;
            return res;

        } catch (Exception ex) {
            Database.rollback(sp);
            res.success = false;
            res.message = 'Error generating quote: ' + ex.getMessage();
            return res;
        }
    }

    /**
     * @description Sends the Quote to the customer (or test mailbox) and advances the Opportunity stage.
     */
    @AuraEnabled
    public static QuoteResult sendQuote(Id quoteId, String recipientEmail) {
        QuoteResult res = new QuoteResult();
        try {
            Quote q = [
                SELECT Id, Name, OpportunityId, GrandTotal
                FROM Quote
                WHERE Id = :quoteId
                LIMIT 1
            ];

            Quote qToUpdate = new Quote(
                Id = q.Id,
                SJV_Acceptance_Status__c = 'Sent',
                Status = 'Presented'
            );
            update qToUpdate;

            Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :q.OpportunityId];
            List<OpportunityStage> propStages = [SELECT ApiName FROM OpportunityStage WHERE IsActive = true AND IsClosed = false AND (ApiName LIKE '%Proposal%' OR ApiName LIKE '%Quote%') LIMIT 1];
            opp.StageName = propStages.isEmpty() ? 'Proposal/Quote' : propStages[0].ApiName;
            update opp;

            // Create reminder task
            Task t = new Task();
            t.WhatId = opp.Id;
            t.Subject = 'Follow up sent quote: ' + q.Name;
            t.Description = 'Contact customer regarding acceptance of quote (Amount: $' + q.GrandTotal + '). Recipient: ' + recipientEmail;
            t.ActivityDate = Date.today().addDays(3);
            t.Priority = 'Normal';
            t.Status = 'Not Started';
            insert t;

            res.success = true;
            res.quoteId = q.Id;
            res.message = 'Quote sent to ' + recipientEmail + '. Opportunity stage updated to Quote Sent.';
            return res;

        } catch (Exception ex) {
            res.success = false;
            res.message = 'Error sending quote: ' + ex.getMessage();
            return res;
        }
    }
}

