@RestResource(urlMapping='/e2e/applications/restart-job')
global with sharing class ApplicationRestartJobRestController {
    @HttpPost
    global static void post() {
        try {
            String requestBody = RestContext.request.requestBody == null
                ? null
                : RestContext.request.requestBody.toString();
            RestartJobCommand command = RestartJobCommand.fromJson(requestBody);
            E2ERestResponseWriter.writeResponse(200, new RestartJobHandler().execute(command));
        } catch (Exception ex) {
            E2ERestResponseWriter.writeResponse(400, CommandResult.fail(ex.getMessage()));
        }
    }
}
