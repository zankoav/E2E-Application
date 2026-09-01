public class ConsumerDefinition {
    public String key;
    public Boolean active;
    public Set<String> allowedProcessKeys = new Set<String>();
    public Set<String> allowedScenarioKeys = new Set<String>();

    public Boolean canAccessProcess(String processKey) {
        return active == true && isAllowed(allowedProcessKeys, processKey);
    }

    public Boolean canAccessScenario(String processKey, String scenarioKey) {
        return active == true && isAllowed(allowedScenarioKeys, processKey + ':' + scenarioKey);
    }

    private Boolean isAllowed(Set<String> allowedValues, String value) {
        return allowedValues.contains('*') || allowedValues.contains(value);
    }
}
