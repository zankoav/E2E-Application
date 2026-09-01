public class ContinueApplicationCommand {
    public String applicationId;
    public String consumerKey;
    public String stepKey;

    public ContinueApplicationCommand() {
    }

    public static ContinueApplicationCommand fromJson(String requestBody) {
        return (ContinueApplicationCommand) JSON.deserialize(requestBody, ContinueApplicationCommand.class);
    }
}
