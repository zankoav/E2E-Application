@RestResource(urlMapping='/e2e/applications/submit-step')
global with sharing class ApplicationSubmitStepRestController {
    @HttpPost
    global static void post() {
        try {
            String requestBody = RestContext.request.requestBody == null
                ? null
                : RestContext.request.requestBody.toString();
            SubmitStepCommand command = SubmitStepCommand.fromJson(requestBody);
            E2ERestResponseWriter.writeResponse(200, new SubmitStepHandler().execute(command));
        } catch (Exception ex) {
            E2ERestResponseWriter.writeResponse(400, CommandResult.fail(ex.getMessage()));
        }
    }
}
