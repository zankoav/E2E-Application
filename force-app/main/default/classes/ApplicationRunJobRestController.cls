@RestResource(urlMapping='/e2e/applications/run-job')
global with sharing class ApplicationRunJobRestController {
    @HttpPost
    global static void post() {
        try {
            String requestBody = RestContext.request.requestBody == null
                ? null
                : RestContext.request.requestBody.toString();
            RunJobCommand command = RunJobCommand.fromJson(requestBody);
            E2ERestResponseWriter.writeResponse(200, new RunJobHandler().execute(command));
        } catch (Exception ex) {
            E2ERestResponseWriter.writeResponse(400, CommandResult.fail(ex));
        }
    }
}
