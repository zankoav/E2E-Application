public inherited sharing class E2ERestResponseWriter {
    private static final String CONTENT_TYPE_JSON = 'application/json';

    public static void writeResponse(Integer statusCode, CommandResult result) {
        if (RestContext.response == null) {
            RestContext.response = new RestResponse();
        }
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', CONTENT_TYPE_JSON);
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(result));
    }
}
