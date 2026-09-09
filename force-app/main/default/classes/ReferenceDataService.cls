public inherited sharing class ReferenceDataService {
    private IntegrationService integrationService;

    public ReferenceDataService() {
        this(new IntegrationService());
    }

    @TestVisible
    private ReferenceDataService(IntegrationService integrationService) {
        this.integrationService = integrationService == null ? new IntegrationService() : integrationService;
    }

    public Map<String, Object> loadReferences(
        Application__c application,
        ProcessDefinition definition,
        String stepKey,
        Set<String> requestedReferenceKeys
    ) {
        if (application == null) {
            throw new FrameworkException('Application is required.');
        }
        if (definition == null) {
            throw new FrameworkException('Process definition is required.');
        }
        if (String.isBlank(stepKey)) {
            throw new FrameworkException('Step key is required.');
        }

        Map<String, Object> stepDefinition = getObjectMap(definition.steps.get(stepKey));
        if (stepDefinition.isEmpty()) {
            throw new FrameworkException('Step definition was not found. Step: ' + stepKey);
        }

        Map<String, Object> referenceDefinitions = getObjectMap(stepDefinition.get('referenceData'));
        Map<String, Object> references = new Map<String, Object>();
        for (String referenceKey : referenceDefinitions.keySet()) {
            if (requestedReferenceKeys != null && !requestedReferenceKeys.isEmpty() && !requestedReferenceKeys.contains(referenceKey)) {
                continue;
            }

            Map<String, Object> referenceDefinition = getObjectMap(referenceDefinitions.get(referenceKey));
            String integrationKey = getString(referenceDefinition, 'integrationKey');
            IntegrationResult result = integrationService.execute(
                integrationKey,
                application,
                definition,
                buildInput(referenceKey, stepKey, referenceDefinition)
            );
            if (!result.success) {
                throw new FrameworkException(
                    'Reference Data integration failed. Reference: ' + referenceKey + ', Integration: ' + integrationKey
                );
            }
            references.put(referenceKey, result.data);
        }
        return references;
    }

    private Map<String, Object> buildInput(String referenceKey, String stepKey, Map<String, Object> referenceDefinition) {
        Map<String, Object> input = new Map<String, Object>();
        input.put('referenceKey', referenceKey);
        input.put('stepKey', stepKey);
        input.putAll(getObjectMap(referenceDefinition.get('input')));
        return input;
    }

    private Map<String, Object> getObjectMap(Object value) {
        return value instanceof Map<String, Object>
            ? (Map<String, Object>) value
            : new Map<String, Object>();
    }

    private String getString(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value == null ? null : String.valueOf(value);
    }
}
