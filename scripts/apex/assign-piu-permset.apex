// Module 2: grant NCinoBankingAdvisor_Perm_Set to the Platform Integration User.
// The AGENT's runtime MCP callout runs as this user; without the grant the admin
// callout test passes but the wired agent returns "no data" (the MCP-5 trap).
String permSetName = 'NCinoBankingAdvisor_Perm_Set';
try {
    List<User> matches = [SELECT Id, Name, Username FROM User WHERE Name LIKE 'Platform%'];
    if (matches.isEmpty()) {
        System.debug('PIU_RESULT=❌ No user matching Name LIKE \'Platform%\' found.');
    } else {
        if (matches.size() > 1) {
            System.debug('PIU_WARN=Multiple Platform% users found; using ' + matches[0].Username);
        }
        User piu = matches[0];
        PermissionSet ps = [SELECT Id, Label FROM PermissionSet WHERE Name = :permSetName LIMIT 1];
        List<PermissionSetAssignment> existing = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :piu.Id AND PermissionSetId = :ps.Id
        ];
        if (existing.isEmpty()) {
            insert new PermissionSetAssignment(AssigneeId = piu.Id, PermissionSetId = ps.Id);
            System.debug('PIU_RESULT=✔ Assigned "' + ps.Label + '" to ' + piu.Name);
        } else {
            System.debug('PIU_RESULT=ℹ Already assigned to ' + piu.Name);
        }
    }
} catch (QueryException qe) {
    System.debug('PIU_RESULT=❌ User or PermissionSet not found: ' + qe.getMessage());
} catch (DmlException de) {
    System.debug('PIU_RESULT=❌ Assignment failed: ' + de.getMessage());
}
