// Seed the Covenant Monitor hero record (Lakeside) for the workshop.
// SELF-CONTAINED: the MCP mock-server personas do NOT correspond to Accounts in the workshop org,
// so this does not assume "Lakeside Manufacturing Co." already exists — it upserts the Account by
// name and then attaches the Monitor. The Monitor tracks Debt-to-Equity (DE_Ratio__c): breaches
// when ABOVE the threshold. Idempotent: re-running creates no duplicates.
final String ACCT_NAME = 'Lakeside Manufacturing Co.';

List<Account> accts = [SELECT Id FROM Account WHERE Name = :ACCT_NAME LIMIT 1];
Account acct;
if (accts.isEmpty()) {
    acct = new Account(Name = ACCT_NAME);
    insert acct;
    System.debug('SEED_RESULT=✔ Created Account "' + ACCT_NAME + '".');
} else {
    acct = accts[0];
    System.debug('SEED_RESULT=ℹ Account "' + ACCT_NAME + '" already present — reusing.');
}

Id rm = UserInfo.getUserId();
List<Covenant_Monitor__c> existing = [
    SELECT Id FROM Covenant_Monitor__c WHERE Account__c = :acct.Id LIMIT 1
];
if (!existing.isEmpty()) {
    System.debug('SEED_RESULT=ℹ Lakeside Covenant Monitor already exists — no insert.');
} else {
    insert new Covenant_Monitor__c(
        Account__c       = acct.Id,
        Loan__c          = 'Plant Expansion Term Loan — LN-2024-0631',
        DE_Ratio__c      = 3.40,
        Threshold__c     = 3.00,
        Breach_Status__c = 'Breached',
        Assigned_RM__c   = rm
    );
    System.debug('SEED_RESULT=✔ Inserted Lakeside Covenant Monitor (D/E 3.40 vs 3.00 max = Breached).');
}
