@RestResource(urlMapping='/e2e/applications/job-status')
global with sharing class ApplicationJobStatusRestController {
    @HttpPost
    global static void post() {
        try {
            String requestBody = RestContext.request.requestBody == null
                ? null
                : RestContext.request.requestBody.toString();
            GetJobStatusCommand command = GetJobStatusCommand.fromJson(requestBody);
            E2ERestResponseWriter.writeResponse(200, new GetJobStatusHandler().execute(command));
        } catch (Exception ex) {
            E2ERestResponseWriter.writeResponse(400, CommandResult.fail(ex));
        }
    }
}
