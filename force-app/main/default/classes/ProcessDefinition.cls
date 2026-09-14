global class ProcessDefinition {
    global String key;
    global String label;
    global String version;
    global Map<String, ScenarioDefinition> scenarios = new Map<String, ScenarioDefinition>();
    global Map<String, Object> steps = new Map<String, Object>();
    global Map<String, Object> raw = new Map<String, Object>();

    global class ScenarioDefinition {
        global String key;
        global String label;
        global String initialStep;
        global List<String> steps = new List<String>();
        global List<String> consumerKeys = new List<String>();
        global PublicAccessDefinition publicAccess = new PublicAccessDefinition();
    }

    global class PublicAccessDefinition {
        global Boolean enabled = false;
        global Integer idleTimeoutMinutes;
        global Integer maxLifetimeMinutes;
    }

    global ScenarioDefinition getScenario(String scenarioKey) {
        return scenarios.get(scenarioKey);
    }

    global static ProcessDefinition parse(String definitionJson) {
        if (String.isBlank(definitionJson)) {
            throw new FrameworkException('Process definition JSON is empty.');
        }

        Map<String, Object> definitionMap = (Map<String, Object>) JSON.deserializeUntyped(definitionJson);
        ProcessDefinition definition = new ProcessDefinition();
        definition.raw = definitionMap;

        Map<String, Object> processMap = (Map<String, Object>) definitionMap.get('process');
        if (processMap != null) {
            definition.key = getString(processMap, 'key');
            definition.label = getString(processMap, 'label');
            definition.version = getString(processMap, 'version');
        }

        definition.steps = getObjectMap(definitionMap, 'steps');

        Map<String, Object> scenarioMap = getObjectMap(definitionMap, 'scenarios');
        for (String scenarioKey : scenarioMap.keySet()) {
            Map<String, Object> scenarioValue = (Map<String, Object>) scenarioMap.get(scenarioKey);
            ScenarioDefinition scenario = new ScenarioDefinition();
            scenario.key = scenarioKey;
            scenario.label = getString(scenarioValue, 'label');
            scenario.initialStep = getString(scenarioValue, 'initialStep');
            scenario.steps = getStringList(scenarioValue, 'steps');
            scenario.consumerKeys = getStringList(scenarioValue, 'consumerKeys');
            scenario.publicAccess = getPublicAccessDefinition(scenarioValue);
            definition.scenarios.put(scenarioKey, scenario);
        }

        return definition;
    }

    private static String getString(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value == null ? null : String.valueOf(value);
    }

    private static Map<String, Object> getObjectMap(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value instanceof Map<String, Object>
            ? (Map<String, Object>) value
            : new Map<String, Object>();
    }

    private static List<String> getStringList(Map<String, Object> source, String key) {
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

    private static PublicAccessDefinition getPublicAccessDefinition(Map<String, Object> scenarioValue) {
        PublicAccessDefinition publicAccess = new PublicAccessDefinition();
        Map<String, Object> rawPublicAccess = getObjectMap(scenarioValue, 'publicAccess');
        if (rawPublicAccess.isEmpty()) {
            return publicAccess;
        }

        publicAccess.enabled = getBoolean(rawPublicAccess, 'enabled');
        publicAccess.idleTimeoutMinutes = getInteger(rawPublicAccess, 'idleTimeoutMinutes');
        publicAccess.maxLifetimeMinutes = getInteger(rawPublicAccess, 'maxLifetimeMinutes');
        return publicAccess;
    }

    private static Boolean getBoolean(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value == null ? false : Boolean.valueOf(String.valueOf(value));
    }

    private static Integer getInteger(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value == null ? null : Integer.valueOf(String.valueOf(value));
    }
}
