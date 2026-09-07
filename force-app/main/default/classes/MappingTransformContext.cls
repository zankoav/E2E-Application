global class MappingTransformContext {
    global Application__c application;
    global String mappingKey;
    global String targetObject;
    global String targetField;
    global String sourceKey;
    global Object sourceValue;
    global Map<String, Object> applicationData = new Map<String, Object>();
    global Map<String, Object> fieldMapping = new Map<String, Object>();
    global Map<String, Object> mappingDefinition = new Map<String, Object>();
}
