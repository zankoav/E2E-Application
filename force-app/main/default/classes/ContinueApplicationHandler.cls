public inherited sharing class ContinueApplicationHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ApplicationEventStore eventStore;
    private SnapshotBuilder snapshotBuilder;
    private RuleEngine ruleEngine;
    private StepNavigator stepNavigator;
    private ConsumerAccessService consumerAccessService;

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
        this.stepNavigator = new StepNavigator(ruleEngine);
        this.consumerAccessService = new ConsumerAccessService();
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
        List<Application_Stop_Process__c> activeStopProcesses = stateStore.getActiveStopProcesses(application.Id);
        List<Application_Job__c> jobs = stateStore.getApplicationJobs(application.Id);
        String nextStepKey = stepNavigator.getNextTransitionCandidate(
            application,
            definition,
            scenario,
            currentStepKey,
            activeStopProcesses,
            jobs
        );
        StepRuntimeContext context = buildRuntimeContext(
            command,
            application,
            definition,
            scenario,
            currentStepKey,
            nextStepKey,
            activeStopProcesses,
            jobs
        );

        RuleResult targetAvailabilityResult = evaluateTargetAvailability(
            application,
            definition,
            scenario,
            nextStepKey,
            activeStopProcesses,
            jobs
        );
        if (!targetAvailabilityResult.allowed) {
            eventStore.createEvent(
                application.Id,
                FrameworkConstants.EVENT_TRANSITION_BLOCKED,
                'Step transition is still blocked.',
                targetAvailabilityResult
            );
            return CommandResult.blocked(buildSnapshot(application, definition), targetAvailabilityResult);
        }

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
        String nextStepKey,
        List<Application_Stop_Process__c> activeStopProcesses,
        List<Application_Job__c> jobs
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
            activeStopProcesses
        );
        context.setJobs(jobs);
        return context;
    }

    private RuleResult evaluateTargetAvailability(
        Application__c application,
        ProcessDefinition definition,
        ProcessDefinition.ScenarioDefinition scenario,
        String nextStepKey,
        List<Application_Stop_Process__c> activeStopProcesses,
        List<Application_Job__c> jobs
    ) {
        if (String.isBlank(nextStepKey)) {
            return RuleResult.allow();
        }
        return stepNavigator.evaluateAvailability(
            application,
            definition,
            scenario,
            nextStepKey,
            activeStopProcesses,
            jobs
        );
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
        consumerAccessService.validateApplicationAccess(command.consumerKey, application);
        if (application.Status__c == FrameworkConstants.APPLICATION_STATUS_COMPLETED) {
            throw new FrameworkException('Completed Application cannot continue.');
        }
        if (!String.isBlank(command.stepKey) && application.Current_Step_Key__c != command.stepKey) {
            throw new FrameworkException('Continue step is not current. Current: ' + application.Current_Step_Key__c + ', Submitted: ' + command.stepKey);
        }
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
