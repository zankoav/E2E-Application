public class SubmitStepCommand {
    public String applicationId;
    public String consumerKey;
    public String stepKey;
    public Map<String, Object> data = new Map<String, Object>();

    public SubmitStepCommand() {
    }

    public static SubmitStepCommand fromJson(String requestBody) {
        SubmitStepCommand command = new SubmitStepCommand();
        if (String.isBlank(requestBody)) {
            return command;
        }

        Map<String, Object> rawCommand = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
        command.applicationId = getString(rawCommand, 'applicationId');
        command.consumerKey = getString(rawCommand, 'consumerKey');
        command.stepKey = getString(rawCommand, 'stepKey');

        Object rawData = rawCommand.get('data');
        if (rawData instanceof Map<String, Object>) {
            command.data = (Map<String, Object>) rawData;
        }
        return command;
    }

    private static String getString(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value == null ? null : String.valueOf(value);
    }
}
