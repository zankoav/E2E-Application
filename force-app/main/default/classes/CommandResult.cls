global class CommandResult {
    global Boolean success;
    global ApplicationSnapshot snapshot;
    global List<String> errors = new List<String>();

    global CommandResult() {
        this.success = true;
    }

    global static CommandResult ok(ApplicationSnapshot snapshot) {
        CommandResult result = new CommandResult();
        result.snapshot = snapshot;
        return result;
    }

    global static CommandResult fail(String message) {
        CommandResult result = new CommandResult();
        result.success = false;
        result.errors.add(message);
        return result;
    }
}
