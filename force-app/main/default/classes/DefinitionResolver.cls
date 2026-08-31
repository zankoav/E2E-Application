global inherited sharing class DefinitionResolver {
    private DefinitionValidator validator;

    global DefinitionResolver() {
        this.validator = new DefinitionValidator();
    }

    global ProcessDefinition resolveActive(String processKey) {
        if (String.isBlank(processKey)) {
            throw new FrameworkException('Process key is required.');
        }

        List<Process_Definition__mdt> records = [
            SELECT Process_Key__c, Version__c, Active__c, Definition_JSON__c
            FROM Process_Definition__mdt
            WHERE Process_Key__c = :processKey
            AND Active__c = true
            LIMIT 1
        ];

        if (records.isEmpty()) {
            throw new FrameworkException('Active process definition was not found. Process: ' + processKey);
        }

        ProcessDefinition definition = ProcessDefinition.parse(records[0].Definition_JSON__c);
        validator.validate(definition);
        return definition;
    }
}
