global class DefinitionValidator {
    global void validate(ProcessDefinition definition) {
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
}
