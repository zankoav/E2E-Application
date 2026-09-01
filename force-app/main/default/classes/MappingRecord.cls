public class MappingRecord {
    public Id applicationId;
    public String mappingKey;
    public String role;
    public String targetObject;
    public String operation;
    public String matchField;
    public List<String> dependsOn = new List<String>();
    public Map<String, String> recordReferenceFields = new Map<String, String>();
    public SObject record;
}
