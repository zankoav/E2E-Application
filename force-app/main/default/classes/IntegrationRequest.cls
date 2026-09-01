public class IntegrationRequest {
    public String integrationKey;
    public Application__c application;
    public ProcessDefinition processDefinition;
    public IntegrationDefinition integrationDefinition;
    public Map<String, Object> input = new Map<String, Object>();
}
