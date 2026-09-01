public inherited sharing class IntegrationService {
    private IntegrationDefinitionResolver resolver;

    public IntegrationService() {
        this(new IntegrationDefinitionResolver());
    }

    @TestVisible
    private IntegrationService(IntegrationDefinitionResolver resolver) {
        this.resolver = resolver == null ? new IntegrationDefinitionResolver() : resolver;
    }

    public IntegrationResult execute(
        String integrationKey,
        Application__c application,
        ProcessDefinition processDefinition,
        Map<String, Object> input
    ) {
        IntegrationDefinition definition = resolver.resolve(processDefinition, integrationKey);
        IntegrationRequest request = new IntegrationRequest();
        request.integrationKey = integrationKey;
        request.application = application;
        request.processDefinition = processDefinition;
        request.integrationDefinition = definition;
        request.input = input == null ? new Map<String, Object>() : input;

        try {
            return createAdapter(definition).execute(request);
        } catch (Exception ex) {
            return IntegrationResult.fail('UNEXPECTED_INTEGRATION_ERROR', ex.getMessage());
        }
    }

    private IntegrationAdapter createAdapter(IntegrationDefinition definition) {
        String className = definition == null ? null : definition.adapterClass;
        if (String.isBlank(className)) {
            return new DefaultIntegrationAdapter();
        }

        Type adapterType = Type.forName(className);
        if (adapterType == null) {
            throw new FrameworkException('Integration Adapter class was not found. Class: ' + className);
        }

        Object adapterInstance = adapterType.newInstance();
        if (!(adapterInstance instanceof IntegrationAdapter)) {
            throw new FrameworkException('Integration Adapter class must implement IntegrationAdapter. Class: ' + className);
        }
        return (IntegrationAdapter) adapterInstance;
    }
}
