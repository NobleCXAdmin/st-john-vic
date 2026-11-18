// v3.1 — flat scalar params for recordQuoteAcceptance, cache-bust 2026-11-11
import { LightningElement, api, track } from 'lwc';
import getOpportunityData from '@salesforce/apex/SJV_UIController.getOpportunityData';
import recordQuoteAcceptance from '@salesforce/apex/SJV_UIController.recordQuoteAcceptance';
import closeOpportunityWon from '@salesforce/apex/SJV_UIController.closeOpportunityWon';

export default class SjvOpportunityCommercialWidget extends LightningElement {
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

    @track opportunity;
    @track quotes = [];
    @track acceptedQuote;
    @track acceptanceHistory = [];
    @track initiative;

    @track gateAcceptedQuote = false;
    @track gateClinicalReview = false;
    @track gateOperationsReview = false;
    @track gateCreditClearance = false;
    @track allGatesPassed = false;

    // Acceptance modal
    @track isAcceptanceModalOpen = false;
    @track targetQuoteId;
    @track acceptanceInput = {
        acceptanceMethod: 'Email Confirmation',
        evidenceReference: 'Email confirmation received in test inbox',
        notes: 'Commercial terms accepted without amendments.'
    };

    acceptanceMethodOptions = [
        { label: 'Email Confirmation', value: 'Email Confirmation' },
        { label: 'Signed Document / PDF', value: 'Signed Document' },
        { label: 'Portal Confirmation', value: 'Portal Confirmation' }
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
            const data = await getOpportunityData({ oppId: this._recordId });
            this.opportunity = data.opportunity;
            this.quotes = (data.quotes || []).map(q => ({
                ...q,
                isAccepted: q.SJV_Acceptance_Status__c === 'Accepted'
            }));
            this.acceptedQuote = data.acceptedQuote;
            this.acceptanceHistory = data.acceptanceHistory || [];
            this.initiative = data.initiative;

            this.gateAcceptedQuote = data.gateAcceptedQuote;
            this.gateClinicalReview = data.gateClinicalReview;
            this.gateOperationsReview = data.gateOperationsReview;
            this.gateCreditClearance = data.gateCreditClearance;
            this.allGatesPassed = data.allGatesPassed;
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error loading commercial opportunity data.';
        } finally {
            this.isLoading = false;
        }
    }

    get isWon() {
        return this.opportunity?.IsWon || false;
    }

    get opportunityAmount() {
        return (this.opportunity?.Amount || 0).toFixed(2);
    }

    get internalCost() {
        return (this.opportunity?.SJV_Internal_Cost__c || 0).toFixed(2);
    }

    get estimatedMargin() {
        return (this.opportunity?.SJV_Estimated_Margin__c || 0).toFixed(2);
    }

    get marginPercent() {
        const amt = this.opportunity?.Amount || 0;
        const margin = this.opportunity?.SJV_Estimated_Margin__c || 0;
        if (amt === 0) return '0';
        return ((margin / amt) * 100).toFixed(0);
    }

    get hasAcceptedQuote() {
        return this.gateAcceptedQuote;
    }

    get acceptedQuoteNumber() {
        return this.acceptedQuote?.QuoteNumber || this.acceptedQuote?.Name || 'Accepted';
    }

    get clinicalReviewStatus() {
        return this.opportunity?.SJV_Clinical_Review_Status__c || 'Pending';
    }

    get operationsReviewStatus() {
        return this.opportunity?.SJV_Operations_Review_Status__c || 'Pending';
    }

    get creditReviewStatus() {
        return this.opportunity?.SJV_Credit_Review_Status__c || 'Cleared';
    }

    get hasQuotes() {
        return this.quotes && this.quotes.length > 0;
    }

    get isCloseWonDisabled() {
        return !this.allGatesPassed || this.isLoading;
    }

    get gateAcceptedQuoteIcon() {
        return this.gateAcceptedQuote ? 'action:approval' : 'action:close';
    }

    get gateClinicalReviewIcon() {
        return this.gateClinicalReview ? 'action:approval' : 'action:close';
    }

    get gateOperationsReviewIcon() {
        return this.gateOperationsReview ? 'action:approval' : 'action:close';
    }

    get gateCreditClearanceIcon() {
        return this.gateCreditClearance ? 'action:approval' : 'action:close';
    }

    handleSelectQuoteToAccept(e) {
        this.targetQuoteId = e.target.dataset.id;
        this.isAcceptanceModalOpen = true;
    }

    openAcceptanceModal() {
        if (this.quotes.length > 0) {
            this.targetQuoteId = this.quotes[0].Id;
        }
        this.isAcceptanceModalOpen = true;
    }

    closeAcceptanceModal() {
        this.isAcceptanceModalOpen = false;
    }

    handleMethodChange(e) { this.acceptanceInput.acceptanceMethod = e.target.value; }
    handleEvidenceChange(e) { this.acceptanceInput.evidenceReference = e.target.value; }
    handleNotesChange(e) { this.acceptanceInput.notes = e.target.value; }

    async handleSaveAcceptance() {
        const resolvedQuoteId = this.targetQuoteId || (this.quotes && this.quotes.length > 0 ? this.quotes[0].Id : null);
        if (!resolvedQuoteId) {
            this.errorMessage = 'No quote available to record acceptance. Please ensure a quote exists for this opportunity.';
            return;
        }
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const res = await recordQuoteAcceptance({
                quoteId:           resolvedQuoteId,
                contactId:         null,
                acceptanceMethod:  this.acceptanceInput.acceptanceMethod,
                evidenceReference: this.acceptanceInput.evidenceReference,
                notes:             this.acceptanceInput.notes
            });
            if (res.success) {
                this.successMessage = res.message;
                this.isAcceptanceModalOpen = false;
                await this.loadData();
            } else {
                this.errorMessage = res.message || 'Error recording acceptance.';
            }
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error recording acceptance.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleCloseWon() {
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const res = await closeOpportunityWon({ oppId: this._recordId });
            if (res.success) {
                this.successMessage = res.message + ' Linked Volunteer Initiative is now marked Ready for staff Rosterfy transfer.';
                await this.loadData();
            } else {
                this.errorMessage = res.message || 'Server gate failed.';
            }
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error closing opportunity won.';
        } finally {
            this.isLoading = false;
        }
    }
}