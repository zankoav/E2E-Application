@RestResource(urlMapping='/e2e/applications/init')
global with sharing class ApplicationInitRestController {
    @HttpPost
    global static void post() {
        try {
            String requestBody = RestContext.request.requestBody == null
                ? null
                : RestContext.request.requestBody.toString();
            InitApplicationCommand command = InitApplicationCommand.fromJson(requestBody);
            E2ERestResponseWriter.writeResponse(200, new InitApplicationHandler().execute(command));
        } catch (Exception ex) {
            E2ERestResponseWriter.writeResponse(400, CommandResult.fail(ex));
        }
    }
}
