// Module 2 smoke test: POST a JSON-RPC tools/list to the MCP server via the Named Credential.
// Success = HTTP 200 + a JSON body listing 4 tools. Debug lines surface in `sf apex run` output.
HttpRequest req = new HttpRequest();
req.setEndpoint('callout:NCinoBankingAdvisor');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setBody('{"jsonrpc":"2.0","id":1,"method":"tools/list"}');
try {
    HttpResponse res = new Http().send(req);
    System.debug('MCP_STATUS=' + res.getStatusCode());
    System.debug('MCP_BODY=' + res.getBody());
} catch (Exception e) {
    System.debug('MCP_ERROR=' + e.getMessage());
}
