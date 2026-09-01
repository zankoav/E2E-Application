public class IntegrationResult {
    public Boolean success;
    public String errorCode;
    public String errorMessage;
    public Map<String, Object> data = new Map<String, Object>();

    public IntegrationResult() {
        this.success = true;
    }

    public static IntegrationResult ok(Map<String, Object> data) {
        IntegrationResult result = new IntegrationResult();
        result.data = data == null ? new Map<String, Object>() : data;
        return result;
    }

    public static IntegrationResult fail(String errorCode, String errorMessage) {
        IntegrationResult result = new IntegrationResult();
        result.success = false;
        result.errorCode = errorCode;
        result.errorMessage = errorMessage;
        return result;
    }
}
