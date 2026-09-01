public inherited sharing class IntegrationDefinitionResolver {
    public IntegrationDefinition resolve(ProcessDefinition processDefinition, String integrationKey) {
        if (String.isBlank(integrationKey)) {
            throw new FrameworkException('Integration key is required.');
        }

        Map<String, Object> processIntegrationDefinition = getProcessIntegrationDefinition(processDefinition, integrationKey);
        IntegrationDefinition metadataDefinition = resolveMetadataDefinition(getString(processIntegrationDefinition, 'definitionKey'));
        if (metadataDefinition == null && processIntegrationDefinition.isEmpty()) {
            metadataDefinition = resolveMetadataDefinition(integrationKey);
        }

        IntegrationDefinition definition = metadataDefinition == null ? new IntegrationDefinition() : metadataDefinition;
        definition.key = integrationKey;
        applyProcessOverrides(definition, processIntegrationDefinition);
        if (String.isBlank(definition.adapterClass)) {
            definition.adapterClass = 'DefaultIntegrationAdapter';
        }
        return definition;
    }

    private IntegrationDefinition resolveMetadataDefinition(String integrationKey) {
        if (String.isBlank(integrationKey)) {
            return null;
        }

        List<Integration_Definition__mdt> records = [
            SELECT Integration_Key__c, Active__c, Adapter_Class__c, Named_Credential__c, Settings_JSON__c
            FROM Integration_Definition__mdt
            WHERE Integration_Key__c = :integrationKey
            AND Active__c = true
            LIMIT 1
        ];

        if (records.isEmpty()) {
            throw new FrameworkException('Active Integration Definition was not found. Integration: ' + integrationKey);
        }

        Integration_Definition__mdt record = records[0];
        IntegrationDefinition definition = new IntegrationDefinition();
        definition.key = record.Integration_Key__c;
        definition.adapterClass = record.Adapter_Class__c;
        definition.namedCredential = record.Named_Credential__c;
        definition.settings = parseSettings(record.Settings_JSON__c);
        return definition;
    }

    private void applyProcessOverrides(IntegrationDefinition definition, Map<String, Object> processIntegrationDefinition) {
        if (processIntegrationDefinition.isEmpty()) {
            return;
        }
        definition.raw.putAll(processIntegrationDefinition);

        String adapterClass = getString(processIntegrationDefinition, 'adapterClass');
        if (!String.isBlank(adapterClass)) {
            definition.adapterClass = adapterClass;
        }

        String namedCredential = getString(processIntegrationDefinition, 'namedCredential');
        if (!String.isBlank(namedCredential)) {
            definition.namedCredential = namedCredential;
        }

        Map<String, Object> settings = getObjectMap(processIntegrationDefinition, 'settings');
        if (!settings.isEmpty()) {
            definition.settings.putAll(settings);
        }
    }

    private Map<String, Object> getProcessIntegrationDefinition(ProcessDefinition processDefinition, String integrationKey) {
        if (processDefinition == null || processDefinition.raw == null) {
            return new Map<String, Object>();
        }

        Map<String, Object> integrations = getObjectMap(processDefinition.raw, 'integrations');
        Object rawIntegration = integrations.get(integrationKey);
        return rawIntegration instanceof Map<String, Object>
            ? (Map<String, Object>) rawIntegration
            : new Map<String, Object>();
    }

    private Map<String, Object> parseSettings(String settingsJson) {
        if (String.isBlank(settingsJson)) {
            return new Map<String, Object>();
        }

        Object rawSettings = JSON.deserializeUntyped(settingsJson);
        return rawSettings instanceof Map<String, Object>
            ? (Map<String, Object>) rawSettings
            : new Map<String, Object>();
    }

    private Map<String, Object> getObjectMap(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value instanceof Map<String, Object>
            ? (Map<String, Object>) value
            : new Map<String, Object>();
    }

    private String getString(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value == null ? null : String.valueOf(value);
    }
}
