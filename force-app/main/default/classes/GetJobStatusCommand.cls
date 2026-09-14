public class GetJobStatusCommand {
    public String applicationId;
    public String consumerKey;
    public String jobKey;
    public String resumeToken;

    public GetJobStatusCommand() {
    }

    public static GetJobStatusCommand fromJson(String requestBody) {
        return (GetJobStatusCommand) JSON.deserialize(requestBody, GetJobStatusCommand.class);
    }
}
