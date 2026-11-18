import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLeadEnquiryData from '@salesforce/apex/SJV_UIController.getLeadEnquiryData';
import convertLead from '@salesforce/apex/SJV_LeadConversionService.convertLead';

export default class SjvLeadConversionAction extends NavigationMixin(LightningElement) {
    _recordId;
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadData();
        }
    }

    @track isLoading = true;
    @track errorMessage = '';
    @track successMessage = '';
    @track qualificationNotes = 'Enquiry qualified by BDM. Ready for clinical risk assessment and operational shift demand generation.';

    @track leadRecord = {};
    @track enquiryRecord = {};
    @track opportunityId;
    @track initiativeId;

    connectedCallback() {
        if (this._recordId) {
            this.loadData();
        }
    }

    async loadData() {
        const targetId = this._recordId || this.recordId;
        if (!targetId) {
            this.isLoading = false;
            return;
        }
        this.isLoading = true;
        try {
            const data = await getLeadEnquiryData({ leadId: targetId });
            if (data && data.lead) {
                this.leadRecord = data.lead;
                this.opportunityId = data.lead.ConvertedOpportunityId;
            }
        } catch (e) {
            console.error('Error loading lead enquiry data', e);
        } finally {
            this.isLoading = false;
        }
    }

    get isConverted() {
        return !!this.opportunityId || !!this.leadRecord.IsConverted;
    }

    get enquiryName() {
        return this.leadRecord.Name || 'New Intake';
    }

    get eventName() {
        return this.leadRecord.SJV_Event_Name__c || (this.leadRecord.Name ? this.leadRecord.Name + ' Event' : 'St John Service Booking');
    }

    get eventType() {
        return this.leadRecord.SJV_Event_Type__c || 'Community Festival';
    }

    get organisationName() {
        return this.leadRecord.Company || 'Individual / Not specified';
    }

    get venue() {
        return this.leadRecord.SJV_Venue_Name__c || 'Venue TBD';
    }

    get venueAddress() {
        return this.leadRecord.Street || 'Address not specified';
    }

    get dates() {
        if (this.leadRecord.SJV_Start_Date__c) {
            return this.leadRecord.SJV_Start_Date__c + (this.leadRecord.SJV_End_Date__c && this.leadRecord.SJV_End_Date__c !== this.leadRecord.SJV_Start_Date__c ? ' to ' + this.leadRecord.SJV_End_Date__c : '');
        }
        return 'Dates TBD';
    }

    get dailyHours() {
        return this.leadRecord.SJV_Daily_Hours_Description__c || '09:00 - 17:00 (Standard)';
    }

    get attendance() {
        return this.leadRecord.SJV_Expected_Attendance__c ? this.leadRecord.SJV_Expected_Attendance__c.toLocaleString() : 'N/A';
    }

    get indoorOutdoor() {
        return this.leadRecord.SJV_Indoor_Outdoor__c || 'Outdoor';
    }

    get publicOrPrivate() {
        return 'Public Event';
    }

    get alcohol() {
        return this.leadRecord.SJV_Alcohol_Present__c || 'No';
    }

    get highRisk() {
        return this.leadRecord.SJV_High_Risk_Activities__c || 'None';
    }

    get firstAidRoom() {
        return this.leadRecord.SJV_First_Aid_Post_Available__c === 'Yes' 
            ? 'Yes — Dedicated first aid facility available' 
            : 'No — St John to supply mobile first aid marquee';
    }

    get setupInstructions() {
        return this.leadRecord.SJV_Setup_Access_Instructions__c || 'Standard access';
    }

    get coverageNotes() {
        return this.leadRecord.SJV_Requested_Coverage_Notes__c || 'No special requirements noted';
    }

    get contactName() {
        return this.leadRecord.Name || 'N/A';
    }

    get customerRole() {
        return this.leadRecord.SJV_Customer_Role__c || this.leadRecord.Title || 'Event Organiser';
    }

    get contactEmail() {
        return this.leadRecord.Email || 'N/A';
    }

    get contactPhone() {
        return this.leadRecord.Phone || 'N/A';
    }

    get emailMailto() {
        return this.contactEmail !== 'N/A' ? `mailto:${this.contactEmail}` : '#';
    }

    get phoneTel() {
        return this.contactPhone !== 'N/A' ? `tel:${this.contactPhone}` : '#';
    }

    get previousCustomer() {
        return this.leadRecord.SJV_Previous_Customer__c || 'No / Unsure';
    }

    get eventDayContactName() {
        return this.leadRecord.SJV_Event_Day_Contact_Name__c || this.contactName;
    }

    get eventDayContactPhone() {
        return this.leadRecord.SJV_Event_Day_Contact_Phone__c || this.contactPhone;
    }

    get leadSourceBadge() {
        return 'Source: ' + (this.leadRecord.LeadSource || 'Website');
    }

    handleNotesChange(event) {
        this.qualificationNotes = event.target.value;
    }

    async handleConvert() {
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        const targetLeadId = this._recordId || this.recordId || (this.leadRecord ? this.leadRecord.Id : null);
        if (!targetLeadId) {
            this.errorMessage = 'Lead ID is required for conversion.';
            this.isLoading = false;
            return;
        }

        try {
            const result = await convertLead({
                leadId: targetLeadId,
                qualificationNotes: this.qualificationNotes,
                req: {
                    leadId: targetLeadId,
                    qualificationNotes: this.qualificationNotes
                }
            });

            if (result && result.success) {
                this.opportunityId = result.opportunityId;
                this.initiativeId = result.initiativeId;
                this.successMessage = 'Lead converted successfully! Event Opportunity and Volunteer Initiative created.';
                await this.loadData();
            } else {
                this.errorMessage = result ? result.message : 'Conversion failed.';
            }
        } catch (e) {
            this.errorMessage = e.body ? e.body.message : e.message;
        } finally {
            this.isLoading = false;
        }
    }

    navigateToOpportunity() {
        if (!this.opportunityId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.opportunityId,
                actionName: 'view'
            }
        });
    }

    navigateToInitiative() {
        if (!this.initiativeId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.initiativeId,
                actionName: 'view'
            }
        });
    }
}
