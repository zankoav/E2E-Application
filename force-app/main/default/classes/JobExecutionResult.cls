global class JobExecutionResult {
    global Boolean success;
    global String errorCode;
    global String errorMessage;

    global JobExecutionResult() {
        this.success = true;
    }

    global static JobExecutionResult ok() {
        return new JobExecutionResult();
    }

    global static JobExecutionResult fail(String errorCode, String errorMessage) {
        JobExecutionResult result = new JobExecutionResult();
        result.success = false;
        result.errorCode = errorCode;
        result.errorMessage = errorMessage;
        return result;
    }
}
