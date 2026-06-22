// STUB — scaffolding from pie-poc-forge; flesh out in build. NO business logic.
// LWC: covenantBreachAlert — serves UC1. Renders the breach alert + interrogate action.
import { LightningElement, api } from 'lwc';

export default class CovenantBreachAlert extends LightningElement {
    @api recordId; // Covenant_Monitor__c record id

    handleInterrogate() {
        // TODO (build): open the Agentforce agent to interrogate this breach.
    }
}
