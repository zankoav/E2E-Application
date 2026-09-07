public class CommandResult {
    public Boolean success;
    public ApplicationSnapshot snapshot;
    public ApplicationSnapshot.JobInfo job;
    public ConversionResult conversion;
    public List<String> errors = new List<String>();
    public List<ErrorInfo> errorDetails = new List<ErrorInfo>();

    public CommandResult() {
        this.success = true;
    }

    public static CommandResult ok(ApplicationSnapshot snapshot) {
        CommandResult result = new CommandResult();
        result.snapshot = snapshot;
        return result;
    }

    public static CommandResult ok(ApplicationSnapshot.JobInfo job) {
        CommandResult result = new CommandResult();
        result.job = job;
        return result;
    }

    public static CommandResult ok(ConversionResult conversion) {
        CommandResult result = new CommandResult();
        result.conversion = conversion;
        return result;
    }

    public static CommandResult fail(String message) {
        return fail(ErrorInfoMapper.fromMessage(message));
    }

    public static CommandResult fail(Exception ex) {
        return fail(ErrorInfoMapper.fromException(ex));
    }

    public static CommandResult fail(String code, String message) {
        return fail(new ErrorInfo(code, message));
    }

    private static CommandResult fail(ErrorInfo errorInfo) {
        CommandResult result = new CommandResult();
        result.success = false;
        result.addError(errorInfo);
        return result;
    }

    public static CommandResult blocked(ApplicationSnapshot snapshot, RuleResult ruleResult) {
        CommandResult result = new CommandResult();
        result.success = false;
        result.snapshot = snapshot;
        result.addError(ErrorInfoMapper.fromRuleResult(ruleResult));
        return result;
    }

    private void addError(ErrorInfo errorInfo) {
        if (errorInfo == null) {
            errorInfo = new ErrorInfo(FrameworkErrorCodes.UNKNOWN_ERROR, null);
        }
        this.errors.add(errorInfo.message);
        this.errorDetails.add(errorInfo);
    }
}
