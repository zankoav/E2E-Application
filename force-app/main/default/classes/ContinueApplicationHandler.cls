public inherited sharing class ContinueApplicationHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ApplicationEventStore eventStore;
    private SnapshotBuilder snapshotBuilder;
    private RuleEngine ruleEngine;

    public ContinueApplicationHandler() {
        this(
            new DefinitionResolver(),
            new ApplicationStateStore(),
            new ApplicationEventStore(),
            new SnapshotBuilder(),
            new RuleEngine()
        );
    }

    @TestVisible
    private ContinueApplicationHandler(
        DefinitionResolver definitionResolver,
        ApplicationStateStore stateStore,
        ApplicationEventStore eventStore,
        SnapshotBuilder snapshotBuilder,
        RuleEngine ruleEngine
    ) {
        this.definitionResolver = definitionResolver;
        this.stateStore = stateStore;
        this.eventStore = eventStore;
        this.snapshotBuilder = snapshotBuilder;
        this.ruleEngine = ruleEngine;
    }

    public CommandResult execute(ContinueApplicationCommand command) {
        validateCommand(command);

        Application__c application = stateStore.getApplication((Id) command.applicationId);
        validateApplication(command, application);

        ProcessDefinition definition = definitionResolver.resolveActive(application.Process_Key__c);
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario(application.Scenario_Key__c);
        if (scenario == null) {
            throw new FrameworkException('Scenario was not found. Scenario: ' + application.Scenario_Key__c);
        }

        String currentStepKey = String.isBlank(command.stepKey)
            ? application.Current_Step_Key__c
            : command.stepKey;
        String nextStepKey = getNextStepKey(scenario, currentStepKey);
        StepRuntimeContext context = buildRuntimeContext(command, application, definition, scenario, currentStepKey, nextStepKey);

        RuleResult transitionResult = ruleEngine.evaluateStepTransitionRules(context);
        if (!transitionResult.allowed) {
            eventStore.createEvent(
                application.Id,
                FrameworkConstants.EVENT_TRANSITION_BLOCKED,
                'Step transition is still blocked.',
                transitionResult
            );
            return CommandResult.blocked(buildSnapshot(application, definition), transitionResult);
        }

        Boolean completed = isFinishStep(definition, nextStepKey) || String.isBlank(nextStepKey);
        stateStore.updateApplicationStep(application, nextStepKey, completed);

        eventStore.createEvent(
            application.Id,
            FrameworkConstants.EVENT_TRANSITION_COMPLETED,
            'Step transition completed.',
            context
        );
        if (completed) {
            eventStore.createEvent(
                application.Id,
                FrameworkConstants.EVENT_APPLICATION_FINISHED,
                'Application finished.',
                null
            );
        }

        return CommandResult.ok(buildSnapshot(application, definition));
    }

    private StepRuntimeContext buildRuntimeContext(
        ContinueApplicationCommand command,
        Application__c application,
        ProcessDefinition definition,
        ProcessDefinition.ScenarioDefinition scenario,
        String currentStepKey,
        String nextStepKey
    ) {
        SubmitStepCommand stepCommand = new SubmitStepCommand();
        stepCommand.applicationId = command.applicationId;
        stepCommand.consumerKey = command.consumerKey;
        stepCommand.stepKey = currentStepKey;
        stepCommand.data = new Map<String, Object>();

        StepRuntimeContext context = new StepRuntimeContext(
            application,
            definition,
            scenario,
            stepCommand,
            nextStepKey,
            stateStore.getActiveStopProcesses(application.Id)
        );
        context.setJobs(stateStore.getApplicationJobs(application.Id));
        return context;
    }

    private ApplicationSnapshot buildSnapshot(Application__c application, ProcessDefinition definition) {
        return snapshotBuilder.build(
            application,
            definition,
            stateStore.getApplicationData(application.Id),
            stateStore.getActiveStopProcesses(application.Id),
            stateStore.getApplicationJobs(application.Id)
        );
    }

    private void validateCommand(ContinueApplicationCommand command) {
        if (command == null) {
            throw new FrameworkException('ContinueApplication command is required.');
        }
        if (String.isBlank(command.applicationId)) {
            throw new FrameworkException('Application id is required.');
        }
        if (String.isBlank(command.consumerKey)) {
            throw new FrameworkException('Consumer key is required.');
        }
    }

    private void validateApplication(ContinueApplicationCommand command, Application__c application) {
        if (application.Consumer_Key__c != command.consumerKey) {
            throw new FrameworkException('Consumer is not allowed for Application.');
        }
        if (application.Status__c == FrameworkConstants.APPLICATION_STATUS_COMPLETED) {
            throw new FrameworkException('Completed Application cannot continue.');
        }
        if (!String.isBlank(command.stepKey) && application.Current_Step_Key__c != command.stepKey) {
            throw new FrameworkException('Continue step is not current. Current: ' + application.Current_Step_Key__c + ', Submitted: ' + command.stepKey);
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
