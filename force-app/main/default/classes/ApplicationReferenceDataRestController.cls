@RestResource(urlMapping='/e2e/applications/reference-data')
global with sharing class ApplicationReferenceDataRestController {
    @HttpPost
    global static void post() {
        try {
            String requestBody = RestContext.request.requestBody == null
                ? null
                : RestContext.request.requestBody.toString();
            GetReferenceDataCommand command = GetReferenceDataCommand.fromJson(requestBody);
            E2ERestResponseWriter.writeResponse(200, new GetReferenceDataHandler().execute(command));
        } catch (Exception ex) {
            E2ERestResponseWriter.writeResponse(400, CommandResult.fail(ex));
        }
    }
}
