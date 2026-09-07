public class ErrorInfo {
    public String code;
    public String message;
    public Map<String, Object> details;

    public ErrorInfo() {
        this.details = new Map<String, Object>();
    }

    public ErrorInfo(String code, String message) {
        this();
        this.code = String.isBlank(code) ? FrameworkErrorCodes.UNKNOWN_ERROR : code;
        this.message = String.isBlank(message) ? this.code : message;
    }
}
