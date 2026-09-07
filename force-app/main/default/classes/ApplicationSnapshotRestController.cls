@RestResource(urlMapping='/e2e/applications/snapshot')
global with sharing class ApplicationSnapshotRestController {
    @HttpPost
    global static void post() {
        try {
            String requestBody = RestContext.request.requestBody == null
                ? null
                : RestContext.request.requestBody.toString();
            GetSnapshotCommand command = GetSnapshotCommand.fromJson(requestBody);
            E2ERestResponseWriter.writeResponse(200, new GetSnapshotHandler().execute(command));
        } catch (Exception ex) {
            E2ERestResponseWriter.writeResponse(400, CommandResult.fail(ex.getMessage()));
        }
    }
}
