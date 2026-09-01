public class CommandResult {
    public Boolean success;
    public ApplicationSnapshot snapshot;
    public ApplicationSnapshot.JobInfo job;
    public List<String> errors = new List<String>();

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

    public static CommandResult fail(String message) {
        CommandResult result = new CommandResult();
        result.success = false;
        result.errors.add(message);
        return result;
    }

    public static CommandResult blocked(ApplicationSnapshot snapshot, RuleResult ruleResult) {
        CommandResult result = new CommandResult();
        result.success = false;
        result.snapshot = snapshot;
        result.errors.add(ruleResult.message);
        return result;
    }
}
