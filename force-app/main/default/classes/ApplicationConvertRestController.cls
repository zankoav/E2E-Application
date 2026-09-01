@RestResource(urlMapping='/e2e/applications/convert')
global with sharing class ApplicationConvertRestController {
    @HttpPost
    global static void post() {
        try {
            String requestBody = RestContext.request.requestBody == null
                ? null
                : RestContext.request.requestBody.toString();
            ConvertApplicationsCommand command = ConvertApplicationsCommand.fromJson(requestBody);
            writeResponse(200, new ConvertApplicationsHandler().execute(command));
        } catch (Exception ex) {
            writeResponse(400, CommandResult.fail(ex.getMessage()));
        }
    }

    private static void writeResponse(Integer statusCode, CommandResult result) {
        if (RestContext.response == null) {
            RestContext.response = new RestResponse();
        }
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(result));
    }
}
