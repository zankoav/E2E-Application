public class RestartJobCommand {
    public String applicationId;
    public String consumerKey;
    public String jobKey;

    public RestartJobCommand() {
    }

    public static RestartJobCommand fromJson(String requestBody) {
        return (RestartJobCommand) JSON.deserialize(requestBody, RestartJobCommand.class);
    }
}
