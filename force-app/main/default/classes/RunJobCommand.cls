public class RunJobCommand {
    public String applicationId;
    public String consumerKey;
    public String jobKey;
    public String resumeToken;

    public RunJobCommand() {
    }

    public static RunJobCommand fromJson(String requestBody) {
        return (RunJobCommand) JSON.deserialize(requestBody, RunJobCommand.class);
    }
}
