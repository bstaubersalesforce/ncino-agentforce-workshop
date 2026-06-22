// Seed the Covenant Monitor hero record (Lakeside) linked to the existing Account by name.
// The Monitor object tracks Debt-to-Equity (DE_Ratio__c): breaches when ABOVE the threshold.
// Idempotent: skips if a Lakeside monitor already exists.
List<Account> accts = [SELECT Id FROM Account WHERE Name = 'Lakeside Manufacturing Co.' LIMIT 1];
if (accts.isEmpty()) {
    System.debug('SEED_RESULT=❌ Account "Lakeside Manufacturing Co." not found — confirm org seed data.');
} else {
    Id rm = UserInfo.getUserId();
    List<Covenant_Monitor__c> existing = [
        SELECT Id FROM Covenant_Monitor__c WHERE Account__c = :accts[0].Id LIMIT 1
    ];
    if (!existing.isEmpty()) {
        System.debug('SEED_RESULT=ℹ Lakeside Covenant Monitor already exists — no insert.');
    } else {
        insert new Covenant_Monitor__c(
            Account__c       = accts[0].Id,
            Loan__c          = 'Plant Expansion Term Loan — LN-2024-0631',
            DE_Ratio__c      = 3.40,
            Threshold__c     = 3.00,
            Breach_Status__c = 'Breached',
            Assigned_RM__c   = rm
        );
        System.debug('SEED_RESULT=✔ Inserted Lakeside Covenant Monitor (D/E 3.40 vs 3.00 max = Breached).');
    }
}
