global class InitApplicationCommand {
    global String consumerKey;
    global String processKey;
    global String scenarioKey;
    global String externalReference;

    global InitApplicationCommand() {
    }

    global static InitApplicationCommand fromJson(String requestBody) {
        return (InitApplicationCommand) JSON.deserialize(requestBody, InitApplicationCommand.class);
    }
}
