// v3.1 — flat scalar params, getter/setter recordId, cache-bust 2026-11-11
import { LightningElement, api, track } from 'lwc';
import getInitiativeData from '@salesforce/apex/SJV_UIController.getInitiativeData';
import calculateAssessment from '@salesforce/apex/SJV_UIController.calculateAssessment';
import approveAssessment from '@salesforce/apex/SJV_UIController.approveAssessment';
import generateOperationalDemand from '@salesforce/apex/SJV_UIController.generateOperationalDemand';
import generateQuote from '@salesforce/apex/SJV_UIController.generateQuote';

export default class SjvRiskAssessmentWidget extends LightningElement {
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
    @track isLoading = false;
    @track errorMessage = '';
    @track successMessage = '';

    @track disclaimer = 'Illustrative demo rules, not approved for operational use';
    @track currentAssessment;
    @track assessments = [];
    @track answers = [];
    @track requirements = [];
    @track initiative;
    @track opportunity;

    // Modal state
    @track isModalOpen = false;
    @track modalTitle = 'New Risk Assessment (v1)';
    @track modalInput = {
        expectedAttendance: 2500,
        durationHours: 4.0,
        indoorOutdoor: 'Outdoor',
        alcoholPresent: 'No',
        highRiskActivities: 'None',
        firstAidPostNeeded: 'Yes',
        reasonForChange: 'Initial assessment calculation',
        submitForReview: true
    };

    settingOptions = [
        { label: 'Outdoor', value: 'Outdoor' },
        { label: 'Indoor', value: 'Indoor' },
        { label: 'Both Indoor and Outdoor', value: 'Both Indoor and Outdoor' }
    ];

    alcoholOptions = [
        { label: 'No Alcohol', value: 'No' },
        { label: 'Yes (Alcohol Service)', value: 'Yes' },
        { label: 'Unsure', value: 'Unsure' }
    ];

    hazardOptions = [
        { label: 'None / Low Risk Community', value: 'None' },
        { label: 'Watersports / Swimming', value: 'Watersports / Swimming' },
        { label: 'Motorsports / Vehicles', value: 'Motorsports / Vehicles' },
        { label: 'Combat Sports', value: 'Combat Sports' },
        { label: 'Extreme Heat', value: 'Extreme Heat' }
    ];

    postOptions = [
        { label: 'Yes (Mobile Marquee Kit)', value: 'Yes' },
        { label: 'No (Existing Room)', value: 'No' }
    ];

    connectedCallback() {
        // loadData is triggered reactively by the recordId setter.
        // If recordId is already set by the time connectedCallback fires, load now.
        if (this._recordId) {
            this.loadData();
        }
    }

    async loadData() {
        if (!this._recordId) return;
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const data = await getInitiativeData({ recordId: this._recordId, initiativeId: this._recordId });
            this.initiative = data.initiative;
            this.opportunity = data.opportunity;
            this.assessments = data.assessments || [];
            this.currentAssessment = data.currentAssessment;
            this.answers = data.answers || [];
            this.requirements = (data.requirements || []).map(r => ({
                ...r,
                sellingCostDiff: ((r.Selling_Price_Total__c || 0) - (r.Internal_Cost_Total__c || 0)).toFixed(2)
            }));
            if (data.disclaimer) {
                this.disclaimer = data.disclaimer;
            }
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error loading assessment data.';
        } finally {
            this.isLoading = false;
        }
    }

    get hasActiveAssessment() {
        return !!this.currentAssessment;
    }

    get isDraft() {
        return this.currentAssessment && (this.currentAssessment.Status__c === 'Draft' || this.currentAssessment.Status__c === 'Submitted for Review');
    }

    get isApproved() {
        return this.currentAssessment && this.currentAssessment.Status__c === 'Approved';
    }

    get projectedMargin() {
        if (!this.currentAssessment) return '0.00';
        const margin = (this.currentAssessment.Estimated_Selling_Price__c || 0) - (this.currentAssessment.Estimated_Internal_Cost__c || 0);
        return margin.toFixed(2);
    }

    get marginPercent() {
        if (!this.currentAssessment || !this.currentAssessment.Estimated_Selling_Price__c) return '0';
        const margin = (this.currentAssessment.Estimated_Selling_Price__c || 0) - (this.currentAssessment.Estimated_Internal_Cost__c || 0);
        return ((margin / this.currentAssessment.Estimated_Selling_Price__c) * 100).toFixed(0);
    }

    get statusBadgeClass() {
        if (!this.currentAssessment) return 'slds-badge';
        if (this.currentAssessment.Status__c === 'Approved') return 'slds-badge slds-theme_success slds-m-left_x-small';
        if (this.currentAssessment.Status__c === 'Draft') return 'slds-badge slds-theme_warning slds-m-left_x-small';
        return 'slds-badge slds-m-left_x-small';
    }

    get bandBadgeClass() {
        if (!this.currentAssessment) return 'slds-badge';
        if (this.currentAssessment.Risk_Band__c.includes('High')) return 'slds-badge slds-theme_error slds-m-left_x-small';
        if (this.currentAssessment.Risk_Band__c === 'Medium') return 'slds-badge slds-theme_warning slds-m-left_x-small';
        return 'slds-badge slds-theme_success slds-m-left_x-small';
    }

    openNewAssessmentModal() {
        this.modalTitle = 'Run Initial Risk Assessment (v1)';
        this.modalInput.reasonForChange = 'Initial event risk scoring and staffing calculation';
        this.isModalOpen = true;
    }

    openRevisionModal() {
        this.modalTitle = 'Revise Risk Assessment (v2)';
        this.modalInput.expectedAttendance = 5000;
        this.modalInput.reasonForChange = 'Weather forecast update / crowd attendance increase to 5,000 (absorbed cost revision)';
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleModalAttendanceChange(e) { this.modalInput.expectedAttendance = parseInt(e.target.value, 10); }
    handleModalDurationChange(e) { this.modalInput.durationHours = parseFloat(e.target.value); }
    handleModalSettingChange(e) { this.modalInput.indoorOutdoor = e.target.value; }
    handleModalAlcoholChange(e) { this.modalInput.alcoholPresent = e.target.value; }
    handleModalHazardChange(e) { this.modalInput.highRiskActivities = e.target.value; }
    handleModalPostChange(e) { this.modalInput.firstAidPostNeeded = e.target.value; }
    handleModalReasonChange(e) { this.modalInput.reasonForChange = e.target.value; }

    async handleCalculateSubmit() {
        if (!this._recordId) {
            this.errorMessage = 'Record ID is not available. Please refresh the page and try again.';
            return;
        }
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const res = await calculateAssessment({
                initiativeId:       this._recordId,
                expectedAttendance: this.modalInput.expectedAttendance,
                indoorOutdoor:      this.modalInput.indoorOutdoor,
                alcoholPresent:     this.modalInput.alcoholPresent,
                highRiskActivities: this.modalInput.highRiskActivities,
                firstAidPostNeeded: this.modalInput.firstAidPostNeeded,
                durationHours:      this.modalInput.durationHours,
                reasonForChange:    this.modalInput.reasonForChange,
                submitForReview:    true
            });
            if (res.success) {
                this.successMessage = res.message;
                this.isModalOpen = false;
                await this.loadData();
            } else {
                this.errorMessage = res.message || 'Error running assessment calculation.';
            }
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error calculating assessment.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleApprove() {
        if (!this.currentAssessment) return;
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const res = await approveAssessment({
                assessmentId: this.currentAssessment.Id,
                comments: 'Approved by Clinical Operations Lead. Requirements stamped for operational planning.'
            });

            if (res.success) {
                this.successMessage = res.message;
                await this.loadData();
            } else {
                this.errorMessage = res.message || 'Approval error.';
            }
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error approving assessment.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleGenerateDemand() {
        if (!this.currentAssessment) return;
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const res = await generateOperationalDemand({ assessmentId: this.currentAssessment.Id });
            if (res.success) {
                this.successMessage = res.message;
                await this.loadData();
            } else {
                this.errorMessage = res.message || 'Demand generation error.';
            }
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error creating shifts and jobs.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleGenerateQuote() {
        if (!this.currentAssessment) return;
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const res = await generateQuote({ assessmentId: this.currentAssessment.Id });
            if (res.success) {
                this.successMessage = res.message;
                await this.loadData();
            } else {
                this.errorMessage = res.message || 'Quote generation error.';
            }
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error creating commercial quote.';
        } finally {
            this.isLoading = false;
        }
    }
}