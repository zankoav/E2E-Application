@RestResource(urlMapping='/e2e/applications/continue')
global with sharing class ApplicationContinueRestController {
    @HttpPost
    global static void post() {
        try {
            String requestBody = RestContext.request.requestBody == null
                ? null
                : RestContext.request.requestBody.toString();
            ContinueApplicationCommand command = ContinueApplicationCommand.fromJson(requestBody);
            E2ERestResponseWriter.writeResponse(200, new ContinueApplicationHandler().execute(command));
        } catch (Exception ex) {
            E2ERestResponseWriter.writeResponse(400, CommandResult.fail(ex.getMessage()));
        }
    }
}
