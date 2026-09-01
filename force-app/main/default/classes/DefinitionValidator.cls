public class DefinitionValidator {
    public void validate(ProcessDefinition definition) {
        if (definition == null) {
            throw new FrameworkException('Process definition is required.');
        }
        if (String.isBlank(definition.key)) {
            throw new FrameworkException('Process definition key is required.');
        }
        if (String.isBlank(definition.version)) {
            throw new FrameworkException('Process definition version is required.');
        }
        if (definition.scenarios == null || definition.scenarios.isEmpty()) {
            throw new FrameworkException('At least one scenario is required.');
        }
        for (ProcessDefinition.ScenarioDefinition scenario : definition.scenarios.values()) {
            validateScenario(definition, scenario);
        }
        validateSteps(definition);
        validateJobs(definition);
        validateMappings(definition);
    }

    private void validateScenario(ProcessDefinition definition, ProcessDefinition.ScenarioDefinition scenario) {
        if (String.isBlank(scenario.initialStep)) {
            throw new FrameworkException('Scenario initial step is required. Scenario: ' + scenario.key);
        }
        if (scenario.steps == null || scenario.steps.isEmpty()) {
            throw new FrameworkException('Scenario steps are required. Scenario: ' + scenario.key);
        }
        for (String stepKey : scenario.steps) {
            if (!definition.steps.containsKey(stepKey)) {
                throw new FrameworkException('Scenario references missing step. Scenario: ' + scenario.key + ', Step: ' + stepKey);
            }
        }
        if (!definition.steps.containsKey(scenario.initialStep)) {
            throw new FrameworkException('Scenario initial step does not exist. Scenario: ' + scenario.key + ', Step: ' + scenario.initialStep);
        }
    }

    private void validateSteps(ProcessDefinition definition) {
        for (String stepKey : definition.steps.keySet()) {
            Map<String, Object> stepDefinition = getObjectMap(definition.steps.get(stepKey));
            validateRuleReferences(definition, stepKey, stepDefinition, 'availabilityRules');
            validateRuleReferences(definition, stepKey, stepDefinition, 'validationRules');
            validateRuleReferences(definition, stepKey, stepDefinition, 'transitionRules');
            validateJobTriggerRules(definition, stepKey, stepDefinition);
        }
    }

    private void validateRuleReferences(ProcessDefinition definition, String stepKey, Map<String, Object> stepDefinition, String ruleListKey) {
        for (String ruleKey : getStringList(stepDefinition, ruleListKey)) {
            if (!getRules(definition).containsKey(ruleKey)) {
                throw new FrameworkException('Step references missing Rule. Step: ' + stepKey + ', Rule: ' + ruleKey);
            }
        }
    }

    private void validateJobTriggerRules(ProcessDefinition definition, String stepKey, Map<String, Object> stepDefinition) {
        for (String ruleKey : getStringList(stepDefinition, 'jobTriggerRules')) {
            Map<String, Object> ruleDefinition = getRule(definition, ruleKey);
            if (ruleDefinition == null) {
                throw new FrameworkException('Step references missing Job Trigger Rule. Step: ' + stepKey + ', Rule: ' + ruleKey);
            }

            String jobName = getString(ruleDefinition, 'jobKey');
            if (String.isBlank(jobName)) {
                throw new FrameworkException('Job Trigger Rule must define jobKey. Rule: ' + ruleKey);
            }
            if (!getJobs(definition).containsKey(jobName)) {
                throw new FrameworkException('Job Trigger Rule references missing Job. Rule: ' + ruleKey + ', Job: ' + jobName);
            }
        }
    }

    private void validateJobs(ProcessDefinition definition) {
        for (String jobName : getJobs(definition).keySet()) {
            Map<String, Object> jobDefinition = getObjectMap(getJobs(definition).get(jobName));
            String executionMode = getString(jobDefinition, 'executionMode');
            if (String.isBlank(executionMode)) {
                continue;
            }
            if (
                executionMode != FrameworkConstants.JOB_EXECUTION_MODE_SYNC &&
                executionMode != FrameworkConstants.JOB_EXECUTION_MODE_SYNC_CALLOUT &&
                executionMode != FrameworkConstants.JOB_EXECUTION_MODE_ASYNC
            ) {
                throw new FrameworkException('Job has unsupported executionMode. Job: ' + jobName + ', executionMode: ' + executionMode);
            }
        }
    }

    private void validateMappings(ProcessDefinition definition) {
        Map<String, Object> mappings = getMappings(definition);
        for (String mappingKey : getMappings(definition).keySet()) {
            Map<String, Object> mappingDefinition = getObjectMap(mappings.get(mappingKey));
            String targetObject = getString(mappingDefinition, 'targetObject');
            if (String.isBlank(targetObject)) {
                throw new FrameworkException('Mapping targetObject is required. Mapping: ' + mappingKey);
            }
            if (!Schema.getGlobalDescribe().containsKey(targetObject)) {
                throw new FrameworkException('Mapping targetObject was not found. Mapping: ' + mappingKey + ', targetObject: ' + targetObject);
            }

            String operation = getString(mappingDefinition, 'operation');
            if (!String.isBlank(operation) && operation != 'insert' && operation != 'upsert') {
                throw new FrameworkException('Mapping operation is not supported yet. Mapping: ' + mappingKey + ', operation: ' + operation);
            }
            if (operation == 'upsert') {
                validateUpsertMatch(mappingKey, targetObject, mappingDefinition);
            }
            validateMappingDependencies(mappingKey, mappings, mappingDefinition);

            for (Object rawFieldMapping : getObjectList(mappingDefinition, 'fields')) {
                Map<String, Object> fieldMapping = getObjectMap(rawFieldMapping);
                String targetField = getString(fieldMapping, 'target');
                String sourceKey = getString(fieldMapping, 'source');
                String fromRecord = getString(fieldMapping, 'fromRecord');
                if (String.isBlank(targetField) || (String.isBlank(sourceKey) && String.isBlank(fromRecord))) {
                    throw new FrameworkException('Mapping field must define target and source or fromRecord. Mapping: ' + mappingKey);
                }
                if (!String.isBlank(fromRecord) && !mappings.containsKey(fromRecord)) {
                    throw new FrameworkException('Mapping field references missing record. Mapping: ' + mappingKey + ', fromRecord: ' + fromRecord);
                }
                if (!String.isBlank(fromRecord) && !getStringList(mappingDefinition, 'dependsOn').contains(fromRecord)) {
                    throw new FrameworkException('Mapping field fromRecord must be listed in dependsOn. Mapping: ' + mappingKey + ', fromRecord: ' + fromRecord);
                }
                validateMappingTransform(mappingKey, fieldMapping);
            }
        }
        validateMappingDependencyCycles(mappings);
    }

    private void validateMappingDependencies(String mappingKey, Map<String, Object> mappings, Map<String, Object> mappingDefinition) {
        for (String dependencyKey : getStringList(mappingDefinition, 'dependsOn')) {
            if (dependencyKey == mappingKey) {
                throw new FrameworkException('Mapping cannot depend on itself. Mapping: ' + mappingKey);
            }
            if (!mappings.containsKey(dependencyKey)) {
                throw new FrameworkException('Mapping references missing dependency. Mapping: ' + mappingKey + ', Dependency: ' + dependencyKey);
            }
        }
    }

    private void validateMappingDependencyCycles(Map<String, Object> mappings) {
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
                throw new FrameworkException('Mapping dependencies contain a cycle.');
            }
        }
    }

    private Boolean containsAll(Set<String> source, List<String> values) {
        for (String value : values) {
            if (!source.contains(value)) {
                return false;
            }
        }
        return true;
    }

    private void validateMappingTransform(String mappingKey, Map<String, Object> fieldMapping) {
        String transformClass = getString(fieldMapping, 'transformClass');
        if (String.isBlank(transformClass)) {
            return;
        }

        Type transformType = Type.forName(transformClass);
        if (transformType == null) {
            throw new FrameworkException('Mapping Transform class was not found. Mapping: ' + mappingKey + ', Class: ' + transformClass);
        }

        Object transformInstance = transformType.newInstance();
        if (!(transformInstance instanceof MappingTransform)) {
            throw new FrameworkException('Mapping Transform class must implement MappingTransform. Mapping: ' + mappingKey + ', Class: ' + transformClass);
        }
    }

    private void validateUpsertMatch(String mappingKey, String targetObject, Map<String, Object> mappingDefinition) {
        Map<String, Object> matchDefinition = getObjectMap(mappingDefinition.get('match'));
        String matchField = getString(matchDefinition, 'field');
        if (String.isBlank(matchField) || String.isBlank(getString(matchDefinition, 'source'))) {
            throw new FrameworkException('Upsert Mapping must define match field and source. Mapping: ' + mappingKey);
        }
        if (!Schema.getGlobalDescribe().get(targetObject).getDescribe().fields.getMap().containsKey(matchField)) {
            throw new FrameworkException('Mapping match field was not found. Mapping: ' + mappingKey + ', Field: ' + matchField);
        }
    }

    private Map<String, Object> getRule(ProcessDefinition definition, String ruleKey) {
        Map<String, Object> rules = getRules(definition);
        return rules.containsKey(ruleKey) ? getObjectMap(rules.get(ruleKey)) : null;
    }

    private Map<String, Object> getRules(ProcessDefinition definition) {
        return getNamedMap(definition, 'rules');
    }

    private Map<String, Object> getJobs(ProcessDefinition definition) {
        return getNamedMap(definition, 'jobs');
    }

    private Map<String, Object> getMappings(ProcessDefinition definition) {
        return getNamedMap(definition, 'mappings');
    }

    private Map<String, Object> getNamedMap(ProcessDefinition definition, String key) {
        Object value = definition.raw.get(key);
        return value instanceof Map<String, Object>
            ? (Map<String, Object>) value
            : new Map<String, Object>();
    }

    private Map<String, Object> getObjectMap(Object value) {
        return value instanceof Map<String, Object>
            ? (Map<String, Object>) value
            : new Map<String, Object>();
    }

    private String getString(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value == null ? null : String.valueOf(value);
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

    private List<Object> getObjectList(Map<String, Object> source, String key) {
        Object rawValues = source.get(key);
        return rawValues instanceof List<Object>
            ? (List<Object>) rawValues
            : new List<Object>();
    }
}
