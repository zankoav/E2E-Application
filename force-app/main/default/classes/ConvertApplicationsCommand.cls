public class ConvertApplicationsCommand {
    public String consumerKey;
    public String processKey;
    public List<String> applicationIds = new List<String>();
    public Integer maxBatchSize;
    public Boolean retryFailed;

    public static ConvertApplicationsCommand fromJson(String requestBody) {
        return (ConvertApplicationsCommand) JSON.deserialize(requestBody, ConvertApplicationsCommand.class);
    }

    public Set<Id> getApplicationIds() {
        Set<Id> ids = new Set<Id>();
        if (applicationIds == null) {
            return ids;
        }
        for (String applicationId : applicationIds) {
            if (!String.isBlank(applicationId)) {
                ids.add((Id) applicationId);
            }
        }
        return ids;
    }

    public Integer getMaxBatchSize() {
        if (maxBatchSize == null || maxBatchSize <= 0) {
            return 50;
        }
        return Math.min(maxBatchSize, 200);
    }

    public Boolean shouldRetryFailed() {
        return retryFailed == true;
    }
}
