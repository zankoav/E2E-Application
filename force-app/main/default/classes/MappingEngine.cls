public virtual class MappingEngine {
    public virtual List<MappingRecord> buildRecords(
        List<Application__c> applications,
        ProcessDefinition definition,
        Map<Id, List<Application_Data__c>> dataByApplicationId
    ) {
        List<MappingRecord> records = new List<MappingRecord>();
        Map<String, Object> mappings = getObjectMap(definition.raw, 'mappings');
        if (applications == null || applications.isEmpty() || mappings.isEmpty()) {
            return records;
        }

        for (Application__c application : applications) {
            Map<String, Object> applicationData = buildApplicationData(dataByApplicationId.get(application.Id));
            for (String mappingKey : getMappingKeysInDependencyOrder(mappings)) {
                Map<String, Object> mappingDefinition = getObjectMap(mappings.get(mappingKey));
                if (!appliesToScenario(mappingDefinition, application.Scenario_Key__c)) {
                    continue;
                }
                records.add(buildRecord(application, mappingKey, mappingDefinition, applicationData));
            }
        }
        return records;
    }

    private MappingRecord buildRecord(
        Application__c application,
        String mappingKey,
        Map<String, Object> mappingDefinition,
        Map<String, Object> applicationData
    ) {
        String operation = getStringOrDefault(mappingDefinition, 'operation', 'insert');
        if (operation != 'insert' && operation != 'upsert') {
            throw new FrameworkException('Mapping operation is not supported yet. Mapping: ' + mappingKey + ', operation: ' + operation);
        }

        String targetObject = getString(mappingDefinition, 'targetObject');
        if (String.isBlank(targetObject)) {
            throw new FrameworkException('Mapping targetObject is required. Mapping: ' + mappingKey);
        }

        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(targetObject);
        if (targetType == null) {
            throw new FrameworkException('Mapping targetObject was not found. Mapping: ' + mappingKey + ', targetObject: ' + targetObject);
        }

        SObject targetRecord = targetType.newSObject();
        String matchField = null;
        if (operation == 'upsert') {
            matchField = assignMatchField(mappingKey, mappingDefinition, targetRecord, applicationData);
        }

        for (Object rawFieldMapping : getObjectList(mappingDefinition, 'fields')) {
            Map<String, Object> fieldMapping = getObjectMap(rawFieldMapping);
            String targetField = getString(fieldMapping, 'target');
            String sourceKey = getString(fieldMapping, 'source');
            String fromRecord = getString(fieldMapping, 'fromRecord');
            if (String.isBlank(targetField)) {
                continue;
            }
            if (!String.isBlank(fromRecord)) {
                continue;
            }
            if (String.isBlank(sourceKey)) {
                continue;
            }
            targetRecord.put(targetField, transformValue(
                application,
                mappingKey,
                mappingDefinition,
                targetObject,
                fieldMapping,
                applicationData
            ));
        }

        MappingRecord record = new MappingRecord();
        record.applicationId = application.Id;
        record.mappingKey = mappingKey;
        record.role = getStringOrDefault(mappingDefinition, 'role', mappingKey);
        record.targetObject = targetObject;
        record.operation = operation;
        record.matchField = matchField;
        record.dependsOn = getStringList(mappingDefinition, 'dependsOn');
        record.recordReferenceFields = getRecordReferenceFields(mappingDefinition);
        record.record = targetRecord;
        return record;
    }

    private Map<String, String> getRecordReferenceFields(Map<String, Object> mappingDefinition) {
        Map<String, String> referenceFields = new Map<String, String>();
        for (Object rawFieldMapping : getObjectList(mappingDefinition, 'fields')) {
            Map<String, Object> fieldMapping = getObjectMap(rawFieldMapping);
            String targetField = getString(fieldMapping, 'target');
            String fromRecord = getString(fieldMapping, 'fromRecord');
            if (!String.isBlank(targetField) && !String.isBlank(fromRecord)) {
                referenceFields.put(targetField, fromRecord);
            }
        }
        return referenceFields;
    }

    private List<String> getMappingKeysInDependencyOrder(Map<String, Object> mappings) {
        List<String> orderedKeys = new List<String>();
        Set<String> orderedKeySet = new Set<String>();

        while (orderedKeys.size() < mappings.size()) {
            Boolean madeProgress = false;
            for (String mappingKey : mappings.keySet()) {
                if (orderedKeySet.contains(mappingKey)) {
                    continue;
                }

                List<String> dependencies = getStringList(getObjectMap(mappings.get(mappingKey)), 'dependsOn');
                if (containsAll(orderedKeySet, dependencies)) {
                    orderedKeys.add(mappingKey);
                    orderedKeySet.add(mappingKey);
                    madeProgress = true;
                }
            }

            if (!madeProgress) {
                throw new FrameworkException('Mapping dependencies contain a cycle or missing dependency.');
            }
        }

        return orderedKeys;
    }

    private Boolean containsAll(Set<String> source, List<String> values) {
        for (String value : values) {
            if (!source.contains(value)) {
                return false;
            }
        }
        return true;
    }

    private String assignMatchField(
        String mappingKey,
        Map<String, Object> mappingDefinition,
        SObject targetRecord,
        Map<String, Object> applicationData
    ) {
        Map<String, Object> matchDefinition = getObjectMap(mappingDefinition, 'match');
        String matchField = getString(matchDefinition, 'field');
        String sourceKey = getString(matchDefinition, 'source');
        if (String.isBlank(matchField) || String.isBlank(sourceKey)) {
            throw new FrameworkException('Upsert Mapping must define match field and source. Mapping: ' + mappingKey);
        }

        targetRecord.put(matchField, applicationData.get(sourceKey));
        return matchField;
    }

    private Object transformValue(
        Application__c application,
        String mappingKey,
        Map<String, Object> mappingDefinition,
        String targetObject,
        Map<String, Object> fieldMapping,
        Map<String, Object> applicationData
    ) {
        String sourceKey = getString(fieldMapping, 'source');
        MappingTransformContext context = new MappingTransformContext();
        context.application = application;
        context.mappingKey = mappingKey;
        context.targetObject = targetObject;
        context.targetField = getString(fieldMapping, 'target');
        context.sourceKey = sourceKey;
        context.sourceValue = applicationData.get(sourceKey);
        context.applicationData = applicationData;
        context.fieldMapping = fieldMapping;
        context.mappingDefinition = mappingDefinition;
        return createTransform(fieldMapping).transform(context);
    }

    private MappingTransform createTransform(Map<String, Object> fieldMapping) {
        String className = getString(fieldMapping, 'transformClass');
        if (String.isBlank(className)) {
            return new DefaultMappingTransform();
        }

        Type transformType = Type.forName(className);
        if (transformType == null) {
            throw new FrameworkException('Mapping Transform class was not found. Class: ' + className);
        }

        Object transformInstance = transformType.newInstance();
        if (!(transformInstance instanceof MappingTransform)) {
            throw new FrameworkException('Mapping Transform class must implement MappingTransform. Class: ' + className);
        }
        return (MappingTransform) transformInstance;
    }

    private Map<String, Object> buildApplicationData(List<Application_Data__c> dataRecords) {
        Map<String, Object> data = new Map<String, Object>();
        if (dataRecords == null) {
            return data;
        }

        for (Application_Data__c dataRecord : dataRecords) {
            data.put(dataRecord.Key__c, parseDataValue(dataRecord));
        }
        return data;
    }

    private Object parseDataValue(Application_Data__c dataRecord) {
        if (!String.isBlank(dataRecord.Value_JSON__c)) {
            return JSON.deserializeUntyped(dataRecord.Value_JSON__c);
        }
        if (dataRecord.Type__c == 'Boolean') {
            return dataRecord.Value__c == 'true';
        }
        if (dataRecord.Type__c == 'Number' && !String.isBlank(dataRecord.Value__c)) {
            return Decimal.valueOf(dataRecord.Value__c);
        }
        return dataRecord.Value__c;
    }

    private Boolean appliesToScenario(Map<String, Object> mappingDefinition, String scenarioKey) {
        List<String> scenarioKeys = getStringList(mappingDefinition, 'scenarioKeys');
        return scenarioKeys.isEmpty() || scenarioKeys.contains(scenarioKey);
    }

    private Map<String, Object> getObjectMap(Map<String, Object> source, String key) {
        Object value = source == null ? null : source.get(key);
        return getObjectMap(value);
    }

    private Map<String, Object> getObjectMap(Object value) {
        return value instanceof Map<String, Object>
            ? (Map<String, Object>) value
            : new Map<String, Object>();
    }

    private List<Object> getObjectList(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value instanceof List<Object>
            ? (List<Object>) value
            : new List<Object>();
    }

    private List<String> getStringList(Map<String, Object> source, String key) {
        List<String> values = new List<String>();
        Object rawValues = source.get(key);
        if (!(rawValues instanceof List<Object>)) {
            return values;
        }

        for (Object rawValue : (List<Object>) rawValues) {
            values.add(String.valueOf(rawValue));
        }
        return values;
    }

    private String getString(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value == null ? null : String.valueOf(value);
    }

    private String getStringOrDefault(Map<String, Object> source, String key, String defaultValue) {
        String value = getString(source, key);
        return String.isBlank(value) ? defaultValue : value;
    }
}
