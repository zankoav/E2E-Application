global class IntegrationResult {
    global Boolean success;
    global String errorCode;
    global String errorMessage;
    global Map<String, Object> data = new Map<String, Object>();

    global IntegrationResult() {
        this.success = true;
    }

    global static IntegrationResult ok(Map<String, Object> data) {
        IntegrationResult result = new IntegrationResult();
        result.data = data == null ? new Map<String, Object>() : data;
        return result;
    }

    global static IntegrationResult fail(String errorCode, String errorMessage) {
        IntegrationResult result = new IntegrationResult();
        result.success = false;
        result.errorCode = errorCode;
        result.errorMessage = errorMessage;
        return result;
    }
}
