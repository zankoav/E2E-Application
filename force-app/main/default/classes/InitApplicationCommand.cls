public class InitApplicationCommand {
    public String consumerKey;
    public String processKey;
    public String scenarioKey;
    public String externalReference;

    public InitApplicationCommand() {
    }

    public static InitApplicationCommand fromJson(String requestBody) {
        return (InitApplicationCommand) JSON.deserialize(requestBody, InitApplicationCommand.class);
    }
}
