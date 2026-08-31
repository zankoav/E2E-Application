public class ProcessDefinition {
    public String key;
    public String label;
    public String version;
    public Map<String, ScenarioDefinition> scenarios = new Map<String, ScenarioDefinition>();
    public Map<String, Object> steps = new Map<String, Object>();
    public Map<String, Object> raw = new Map<String, Object>();

    public class ScenarioDefinition {
        public String key;
        public String label;
        public String initialStep;
        public List<String> steps = new List<String>();
        public List<String> consumerKeys = new List<String>();
    }

    public ScenarioDefinition getScenario(String scenarioKey) {
        return scenarios.get(scenarioKey);
    }

    public static ProcessDefinition parse(String definitionJson) {
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
}
