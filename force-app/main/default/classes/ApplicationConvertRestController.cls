@RestResource(urlMapping='/e2e/applications/convert')
global with sharing class ApplicationConvertRestController {
    @HttpPost
    global static void post() {
        try {
            String requestBody = RestContext.request.requestBody == null
                ? null
                : RestContext.request.requestBody.toString();
            ConvertApplicationsCommand command = ConvertApplicationsCommand.fromJson(requestBody);
            E2ERestResponseWriter.writeResponse(200, new ConvertApplicationsHandler().execute(command));
        } catch (Exception ex) {
            E2ERestResponseWriter.writeResponse(400, CommandResult.fail(ex));
        }
    }
}
