// Posts an advisory summary to Slack as a one-way notification (the POV's
// secondary, confirmation-gated breach-alert surface).
// Serves: BankingAdvisorAgent send_slack_summary action (apex://SlackNotifier).
// Transport: HTTP POST to the `Slack_Banking_Alerts` legacy Named Credential, whose
// URL is the full Slack Incoming Webhook (the webhook URL IS the secret — it lives in
// the Named Credential, never in code). No auth header: Slack webhooks are anonymous
// and reject an Authorization header.
// 2GP packaging: global + @JsonAccess required so subscribers can invoke across the namespace.
@JsonAccess(serializable='always' deserializable='always')
global with sharing class SlackNotifier {

    // Named Credential that points at the Slack Incoming Webhook URL.
    @TestVisible
    private static final String NAMED_CREDENTIAL = 'Slack_Banking_Alerts';

    @JsonAccess(serializable='always' deserializable='always')
    global class Request {
        @InvocableVariable(required=true label='Summary')
        global String summary;
        // NOTE: Slack Incoming Webhooks post to the channel the webhook was bound to
        // at creation time (here, #banking-alerts). This field is accepted for action
        // signature compatibility but is a no-op for webhook delivery.
        @InvocableVariable(label='Channel')
        global String channel;
    }

    @JsonAccess(serializable='always' deserializable='always')
    global class Response {
        @InvocableVariable(label='Posted')
        global Boolean posted;
        @InvocableVariable(label='Detail')
        global String detail;
    }

    @InvocableMethod(label='Send Slack Summary' description='Post an advisory summary to Slack')
    global static List<Response> send(List<Request> requests) {
        List<Response> results = new List<Response>();
        for (Request req : requests) {
            results.add(post(req));
        }
        return results;
    }

    private static Response post(Request req) {
        Response r = new Response();

        if (req == null || String.isBlank(req.summary)) {
            r.posted = false;
            r.detail = 'No summary provided; nothing sent.';
            return r;
        }

        try {
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint('callout:' + NAMED_CREDENTIAL);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setTimeout(20000);
            // Slack Incoming Webhook payload. JSON.serialize handles escaping of the
            // summary text so quotes/newlines can't break the body.
            httpReq.setBody(JSON.serialize(new Map<String, Object>{ 'text' => req.summary }));

            HttpResponse res = new Http().send(httpReq);
            Integer code = res.getStatusCode();
            // Slack returns 200 with the literal body "ok" on success.
            r.posted = (code == 200);
            r.detail = r.posted
                ? 'Posted to Slack.'
                : 'Slack returned HTTP ' + code + ': ' + res.getBody();
        } catch (Exception e) {
            // Surface failure via the output rather than propagating, so the agent
            // can tell the banker the alert did not send instead of erroring out.
            r.posted = false;
            r.detail = 'Slack callout failed: ' + e.getMessage();
        }
        return r;
    }
}
