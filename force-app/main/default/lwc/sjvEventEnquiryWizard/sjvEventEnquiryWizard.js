import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import submitEnquiry from '@salesforce/apex/SJV_EnquirySubmissionService.submitEnquiry';
import submitEnquiryJson from '@salesforce/apex/SJV_EnquirySubmissionService.submitEnquiryJson';

export default class SjvEventEnquiryWizard extends NavigationMixin(LightningElement) {
    @track currentStep = '1';
    @track isLoading = false;
    @track errorMessage = '';
    @track acknowledgementChecked = false;
    @track submissionResult = {};

    @track formData = {
        firstName: '',
        lastName: '',
        organisationName: '',
        email: '',
        phone: '',
        customerRole: '',
        previousCustomer: 'Unsure',
        eventName: '',
        eventType: 'Community Festival',
        eventDescription: '',
        expectedAttendance: 2500,
        publicOrPrivate: 'Public Event',
        isProvisional: false,
        venueName: '',
        venueAddress: '',
        startDate: '',
        endDate: '',
        timezone: 'Australia/Melbourne',
        dailyHoursDescription: '09:00 - 17:00',
        isMultiDay: false,
        indoorOutdoor: 'Outdoor',
        alcoholPresent: 'No',
        highRiskActivities: 'None',
        firstAidPostAvailable: 'No',
        requestedCoverageNotes: '',
        setupAccessInstructions: '',
        eventDayContactName: '',
        eventDayContactPhone: '',
        marketingConsent: false,
        leadSource: 'Website',
        submissionKey: ''
    };

    connectedCallback() {
        // Pre-fill realistic dates for quick demo experience (30 days from today)
        const d = new Date();
        d.setDate(d.getDate() + 30);
        this.formData.startDate = d.toISOString().split('T')[0];
        const d2 = new Date(d);
        d2.setDate(d2.getDate() + 1);
        this.formData.endDate = d2.toISOString().split('T')[0];
        this.formData.submissionKey = 'SUB-' + Date.now();
    }

    // Picklist options
    previousCustomerOptions = [
        { label: 'Yes, we have booked St John VIC before', value: 'Yes' },
        { label: 'No, this is our first time', value: 'No' },
        { label: 'Not sure', value: 'Unsure' }
    ];

    eventTypeOptions = [
        { label: 'Community Festival / Street Fair', value: 'Community Festival' },
        { label: 'Sporting Event / Marathon', value: 'Sporting Event' },
        { label: 'Music Concert / Festival', value: 'Music Concert' },
        { label: 'Corporate / Exhibition', value: 'Corporate Event' },
        { label: 'School / Youth Gathering', value: 'School Event' },
        { label: 'Other', value: 'Other' }
    ];

    publicPrivateOptions = [
        { label: 'Public Event (Open to all)', value: 'Public Event' },
        { label: 'Private / Ticketed / Gated Event', value: 'Private Event' }
    ];

    timezoneOptions = [
        { label: 'Australia/Melbourne (AEDT/AEST)', value: 'Australia/Melbourne' },
        { label: 'Australia/Sydney (AEDT/AEST)', value: 'Australia/Sydney' }
    ];

    indoorOutdoorOptions = [
        { label: 'Outdoor (Parks, Streets, Open Air)', value: 'Outdoor' },
        { label: 'Indoor (Halls, Stadiums, Centers)', value: 'Indoor' },
        { label: 'Both Indoor and Outdoor', value: 'Both Indoor and Outdoor' }
    ];

    alcoholOptions = [
        { label: 'No alcohol present', value: 'No' },
        { label: 'Yes, licensed alcohol service', value: 'Yes' },
        { label: 'Unsure / Pending Permit', value: 'Unsure' }
    ];

    highRiskOptions = [
        { label: 'None / Low Risk Community Activities', value: 'None' },
        { label: 'Watersports / Swimming', value: 'Watersports / Swimming' },
        { label: 'Motorsports / High Speed Vehicles', value: 'Motorsports / Vehicles' },
        { label: 'Combat / Contact Sports', value: 'Combat Sports' },
        { label: 'Extreme Heat / Summer Exposure', value: 'Extreme Heat' },
        { label: 'Other Active Hazards', value: 'Other' }
    ];

    firstAidPostOptions = [
        { label: 'No (St John to provide marquee/first aid post)', value: 'No' },
        { label: 'Yes (Permanent first aid room with power/water)', value: 'Yes' }
    ];

    // Getters for steps
    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    get isStep4() { return this.currentStep === '4'; }
    get isStep5() { return this.currentStep === '5'; }
    get isStep6() { return this.currentStep === '6'; }
    get isStep7() { return this.currentStep === '7'; }

    get hasPreviousStep() {
        const step = parseInt(this.currentStep, 10);
        return step > 1 && step < 7;
    }

    get hasNextStep() {
        const step = parseInt(this.currentStep, 10);
        return step < 6;
    }

    get isSubmitDisabled() {
        return !this.acknowledgementChecked || this.isLoading;
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const val = event.detail?.value !== undefined ? event.detail.value : event.target.value;
        if (field === 'expectedAttendance') {
            this.formData[field] = val ? parseInt(val, 10) : 0;
        } else {
            this.formData[field] = val;
        }
    }

    handleCheckboxChange(event) {
        const field = event.target.dataset.field;
        this.formData[field] = event.target.checked;
    }

    handleAckChange(event) {
        this.acknowledgementChecked = event.target.checked;
    }

    handlePrevious() {
        this.errorMessage = '';
        const prev = parseInt(this.currentStep, 10) - 1;
        this.currentStep = String(prev);
    }

    handleNext() {
        this.errorMessage = '';
        if (this.currentStep === '1') {
            if (!this.formData.lastName || !this.formData.email || !this.formData.organisationName) {
                this.errorMessage = 'Please complete Last Name, Organisation Name, and Email Address.';
                return;
            }
        } else if (this.currentStep === '2') {
            if (!this.formData.eventName) {
                this.errorMessage = 'Please provide an Event Name.';
                return;
            }
        } else if (this.currentStep === '3') {
            if (!this.formData.startDate || !this.formData.endDate) {
                this.errorMessage = 'Please select Start and End dates.';
                return;
            }
        }
        const next = parseInt(this.currentStep, 10) + 1;
        this.currentStep = String(next);
    }

    async handleSubmit() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const raw = JSON.parse(JSON.stringify(this.formData));
            if (!raw.submissionKey) {
                raw.submissionKey = 'SUB-' + Date.now();
            }
            if (raw.expectedAttendance) {
                raw.expectedAttendance = parseInt(raw.expectedAttendance, 10);
            }

            // Primary: invoke with typed parameter; fallback to JSON string if needed
            let result = await submitEnquiry({ req: raw });
            if (!result || (!result.success && result.message && result.message.includes('required'))) {
                const jsonRes = await submitEnquiryJson({ requestJson: JSON.stringify(raw) });
                if (jsonRes && jsonRes.success) {
                    result = jsonRes;
                }
            }

            if (result && result.success) {
                this.submissionResult = result;
                this.currentStep = '7';
            } else {
                this.errorMessage = result?.message || 'Error lodging enquiry. Please try again.';
            }
        } catch (error) {
            this.errorMessage = error?.body?.message || error?.message || 'Unexpected submission error.';
        } finally {
            this.isLoading = false;
        }
    }

    navigateToLead() {
        if (this.submissionResult && this.submissionResult.leadId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.submissionResult.leadId,
                    objectApiName: 'Lead',
                    actionName: 'view'
                }
            });
        }
    }
}

