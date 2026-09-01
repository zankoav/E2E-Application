public class JobExecutionResult {
    public Boolean success;
    public String errorCode;
    public String errorMessage;

    public JobExecutionResult() {
        this.success = true;
    }

    public static JobExecutionResult ok() {
        return new JobExecutionResult();
    }

    public static JobExecutionResult fail(String errorCode, String errorMessage) {
        JobExecutionResult result = new JobExecutionResult();
        result.success = false;
        result.errorCode = errorCode;
        result.errorMessage = errorMessage;
        return result;
    }
}
