import { LightningElement, api, track } from 'lwc';
import getInitiativeData from '@salesforce/apex/SJV_UIController.getInitiativeData';
import isRosterfyIntegrationActive from '@salesforce/apex/SJV_UIController.isRosterfyIntegrationActive';
import getRosterfyPreview from '@salesforce/apex/SJV_UIController.getRosterfyPreview';
import executeRosterfyTransfer from '@salesforce/apex/SJV_UIController.executeRosterfyTransfer';

export default class SjvRosterfyHandoffWidget extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track errorMessage = '';
    @track successMessage = '';

    @track initiative;
    @track opportunity;
    @track shifts = [];

    @track isPreviewModalOpen = false;
    @track previewPayload = {};
    @track integrationActive = false;
    @track remoteEventUrl = null;

    connectedCallback() {
        this.loadData();
    }

    // v2 — integrationActive loaded from Apex on connectedCallback
    async loadData() {
        if (!this.recordId) return;
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const [data, active] = await Promise.all([
                getInitiativeData({ recordId: this.recordId, initiativeId: this.recordId }),
                isRosterfyIntegrationActive()
            ]);
            this.integrationActive = active === true;
            this.initiative = data.initiative;
            this.opportunity = data.opportunity;
            this.remoteEventUrl = this.initiative?.SJV_Remote_Event_Url__c || null;
            this.shifts = (data.shifts || []).map(s => {
                let times = '09:00 - 13:00';
                if (s.StartTime && s.EndTime) {
                    times = `${s.StartTime} - ${s.EndTime}`;
                }
                return {
                    ...s,
                    formattedTimes: times
                };
            });
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error loading initiative handoff data.';
        } finally {
            this.isLoading = false;
        }
    }

    get syncState() {
        return this.initiative?.SJV_Sync_State__c || 'Not Ready';
    }

    get isReady() {
        return this.syncState === 'Ready';
    }

    get isSynced() {
        return this.syncState === 'Synced';
    }

    get isPartial() {
        return this.syncState === 'Partial';
    }

    get remoteEventId() {
        return this.initiative?.SJV_Remote_Event_Id__c;
    }

    get sourceEventKey() {
        return this.initiative?.SJV_Source_Event_Key__c || 'N/A';
    }

    get approvedRevision() {
        return this.initiative?.SJV_Approved_Plan_Revision__c || 1;
    }

    get isWon() {
        return this.opportunity?.IsWon || false;
    }

    get isTransferBlocked() {
        return this.previewPayload?.validationError && !this.previewPayload.isReadyForTransfer;
    }

    get syncBadgeClass() {
        const state = this.syncState;
        if (state === 'Synced') return 'slds-badge slds-theme_success';
        if (state === 'Ready') return 'slds-badge slds-theme_alt-inverse';
        if (state === 'Partial') return 'slds-badge slds-theme_warning';
        if (state === 'Failed') return 'slds-badge slds-theme_error';
        return 'slds-badge';
    }

    async handleOpenPreview() {
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const preview = await getRosterfyPreview({ initiativeId: this.recordId });
            this.previewPayload = preview;
            this.integrationActive = preview.integrationActive === true;
            this.isPreviewModalOpen = true;
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error generating transfer preview.';
        } finally {
            this.isLoading = false;
        }
    }

    closePreviewModal() {
        this.isPreviewModalOpen = false;
    }

    async handleConfirmTransfer() {
        this.isPreviewModalOpen = false;
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const res = await executeRosterfyTransfer({
                initiativeId: this.recordId,
                simulatePartialFailure: false
            });

            if (res.success) {
                this.successMessage = res.message;
                if (res.remoteEventUrl) this.remoteEventUrl = res.remoteEventUrl;
                await this.loadData();
            } else {
                this.errorMessage = res.message || 'Transfer failed.';
                await this.loadData();
            }
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error calling Rosterfy transfer service.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleSimulatePartial() {
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const res = await executeRosterfyTransfer({
                initiativeId: this.recordId,
                simulatePartialFailure: true
            });

            this.errorMessage = 'Simulated Partial Failure: Event created, but Shift 2 encountered API timeout. State is Partial (AT16).';
            await this.loadData();
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error simulating partial failure.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleRetry() {
        this.isLoading = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const res = await executeRosterfyTransfer({
                initiativeId: this.recordId,
                simulatePartialFailure: false
            });

            if (res.success) {
                this.successMessage = 'Retry Successful! Remaining shifts transferred and verified. State is now Synced.';
                await this.loadData();
            } else {
                this.errorMessage = res.message;
            }
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Error retrying transfer.';
        } finally {
            this.isLoading = false;
        }
    }

    handleOpenRemote() {
        const url = this.remoteEventUrl || this.initiative?.SJV_Remote_Event_Url__c
            || 'https://app.rosterfy.com/events/' + this.remoteEventId;
        window.open(url, '_blank');
    }
}

