public inherited sharing class ConsumerDefinitionResolver {
    public ConsumerDefinition resolveActive(String consumerKey) {
        if (String.isBlank(consumerKey)) {
            throw new FrameworkException('Consumer key is required.');
        }

        List<Consumer_Definition__mdt> records = [
            SELECT Consumer_Key__c, Active__c, Allowed_Process_Keys__c, Allowed_Scenario_Keys__c
            FROM Consumer_Definition__mdt
            WHERE Consumer_Key__c = :consumerKey
            AND Active__c = true
            LIMIT 1
        ];

        if (records.isEmpty()) {
            throw new FrameworkException('Active Consumer Definition was not found. Consumer: ' + consumerKey);
        }

        Consumer_Definition__mdt record = records[0];
        ConsumerDefinition definition = new ConsumerDefinition();
        definition.key = record.Consumer_Key__c;
        definition.active = record.Active__c;
        definition.allowedProcessKeys = parseAllowedValues(record.Allowed_Process_Keys__c);
        definition.allowedScenarioKeys = parseAllowedValues(record.Allowed_Scenario_Keys__c);
        return definition;
    }

    private Set<String> parseAllowedValues(String rawValue) {
        Set<String> values = new Set<String>();
        if (String.isBlank(rawValue)) {
            return values;
        }

        for (String value : rawValue.split('[,\\n;]+')) {
            String normalizedValue = value.trim();
            if (!String.isBlank(normalizedValue)) {
                values.add(normalizedValue);
            }
        }
        return values;
    }
}
