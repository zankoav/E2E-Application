public class GetSnapshotCommand {
    public String applicationId;
    public String consumerKey;

    public GetSnapshotCommand() {
    }

    public static GetSnapshotCommand fromJson(String requestBody) {
        return (GetSnapshotCommand) JSON.deserialize(requestBody, GetSnapshotCommand.class);
    }
}
