public class CommandResult {
    public Boolean success;
    public ApplicationSnapshot snapshot;
    public List<String> errors = new List<String>();

    public CommandResult() {
        this.success = true;
    }

    public static CommandResult ok(ApplicationSnapshot snapshot) {
        CommandResult result = new CommandResult();
        result.snapshot = snapshot;
        return result;
    }

    public static CommandResult fail(String message) {
        CommandResult result = new CommandResult();
        result.success = false;
        result.errors.add(message);
        return result;
    }
}
