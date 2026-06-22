// STUB — scaffolding from pie-poc-forge; flesh out in build. NO business logic.
// Serves: UC1/UC2 — writes PII-minimized Agent_Decision_Audit__c records.
public with sharing class AgentDecisionAuditService {

    public void recordDecision(String regulatedContext, String minimizedPayload) {
        // TODO (build): insert Agent_Decision_Audit__c with CRUD/FLS enforcement (stripInaccessible).
    }
}
