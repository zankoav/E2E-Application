global class IntegrationRequest {
    global String integrationKey;
    global Application__c application;
    global ProcessDefinition processDefinition;
    global IntegrationDefinition integrationDefinition;
    global Map<String, Object> input = new Map<String, Object>();
}
