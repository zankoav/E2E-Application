public class MappingTransformContext {
    public Application__c application;
    public String mappingKey;
    public String targetObject;
    public String targetField;
    public String sourceKey;
    public Object sourceValue;
    public Map<String, Object> applicationData = new Map<String, Object>();
    public Map<String, Object> fieldMapping = new Map<String, Object>();
    public Map<String, Object> mappingDefinition = new Map<String, Object>();
}
