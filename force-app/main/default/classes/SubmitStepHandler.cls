public inherited sharing class SubmitStepHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ApplicationEventStore eventStore;
    private SnapshotBuilder snapshotBuilder;

    public SubmitStepHandler() {
        this.definitionResolver = new DefinitionResolver();
        this.stateStore = new ApplicationStateStore();
        this.eventStore = new ApplicationEventStore();
        this.snapshotBuilder = new SnapshotBuilder();
    }

    public CommandResult execute(SubmitStepCommand command) {
        validateCommand(command);

        Application__c application = stateStore.getApplication((Id) command.applicationId);
        validateApplication(command, application);

        ProcessDefinition definition = definitionResolver.resolveActive(application.Process_Key__c);
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario(application.Scenario_Key__c);
        if (scenario == null) {
            throw new FrameworkException('Scenario was not found. Scenario: ' + application.Scenario_Key__c);
        }

        stateStore.submitStepData(application.Id, command.stepKey, command.data);

        String nextStepKey = getNextStepKey(scenario, command.stepKey);
        Boolean completed = isFinishStep(definition, nextStepKey) || String.isBlank(nextStepKey);
        stateStore.updateApplicationStep(application, nextStepKey, completed);

        eventStore.createEvent(
            application.Id,
            FrameworkConstants.EVENT_STEP_SUBMITTED,
            'Step submitted.',
            command
        );
        if (completed) {
            eventStore.createEvent(
                application.Id,
                FrameworkConstants.EVENT_APPLICATION_FINISHED,
                'Application finished.',
                null
            );
        }

        ApplicationSnapshot snapshot = snapshotBuilder.build(application, definition, stateStore.getApplicationData(application.Id));
        eventStore.createEvent(
            application.Id,
            FrameworkConstants.EVENT_SNAPSHOT_RETURNED,
            'Submit Step Snapshot returned.',
            null
        );

        return CommandResult.ok(snapshot);
    }

    private void validateCommand(SubmitStepCommand command) {
        if (command == null) {
            throw new FrameworkException('SubmitStep command is required.');
        }
        if (String.isBlank(command.applicationId)) {
            throw new FrameworkException('Application id is required.');
        }
        if (String.isBlank(command.consumerKey)) {
            throw new FrameworkException('Consumer key is required.');
        }
        if (String.isBlank(command.stepKey)) {
            throw new FrameworkException('Step key is required.');
        }
    }

    private void validateApplication(SubmitStepCommand command, Application__c application) {
        if (application.Consumer_Key__c != command.consumerKey) {
            throw new FrameworkException('Consumer is not allowed for Application.');
        }
        if (application.Status__c == FrameworkConstants.APPLICATION_STATUS_COMPLETED) {
            throw new FrameworkException('Completed Application cannot be changed.');
        }
        if (application.Current_Step_Key__c != command.stepKey) {
            throw new FrameworkException('Submitted step is not current. Current: ' + application.Current_Step_Key__c + ', Submitted: ' + command.stepKey);
        }
    }

    private String getNextStepKey(ProcessDefinition.ScenarioDefinition scenario, String currentStepKey) {
        Integer currentIndex = scenario.steps.indexOf(currentStepKey);
        if (currentIndex < 0) {
            throw new FrameworkException('Current step is not part of Scenario. Step: ' + currentStepKey);
        }
        Integer nextIndex = currentIndex + 1;
        return nextIndex < scenario.steps.size() ? scenario.steps[nextIndex] : null;
    }

    private Boolean isFinishStep(ProcessDefinition definition, String stepKey) {
        if (String.isBlank(stepKey)) {
            return false;
        }

        Object rawStep = definition.steps.get(stepKey);
        if (rawStep instanceof Map<String, Object>) {
            Object typeValue = ((Map<String, Object>) rawStep).get('type');
            return typeValue != null && String.valueOf(typeValue) == 'finish';
        }
        return false;
    }
}
