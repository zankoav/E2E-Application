public class GetReferenceDataCommand {
    public String applicationId;
    public String consumerKey;
    public String stepKey;
    public List<String> referenceKeys = new List<String>();

    public GetReferenceDataCommand() {
    }

    public Set<String> getReferenceKeys() {
        return referenceKeys == null ? new Set<String>() : new Set<String>(referenceKeys);
    }

    public static GetReferenceDataCommand fromJson(String requestBody) {
        return (GetReferenceDataCommand) JSON.deserialize(requestBody, GetReferenceDataCommand.class);
    }
}
