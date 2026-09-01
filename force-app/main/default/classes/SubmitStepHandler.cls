public inherited sharing class SubmitStepHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ApplicationEventStore eventStore;
    private SnapshotBuilder snapshotBuilder;
    private RuleEngine ruleEngine;
    private JobEngine jobEngine;
    private StepNavigator stepNavigator;
    private ConsumerAccessService consumerAccessService;

    public SubmitStepHandler() {
        this(
            new DefinitionResolver(),
            new ApplicationStateStore(),
            new ApplicationEventStore(),
            new SnapshotBuilder(),
            new RuleEngine(),
            new JobEngine()
        );
    }

    @TestVisible
    private SubmitStepHandler(
        DefinitionResolver definitionResolver,
        ApplicationStateStore stateStore,
        ApplicationEventStore eventStore,
        SnapshotBuilder snapshotBuilder,
        RuleEngine ruleEngine,
        JobEngine jobEngine
    ) {
        this.definitionResolver = definitionResolver;
        this.stateStore = stateStore;
        this.eventStore = eventStore;
        this.snapshotBuilder = snapshotBuilder;
        this.ruleEngine = ruleEngine;
        this.jobEngine = jobEngine;
        this.stepNavigator = new StepNavigator(ruleEngine);
        this.consumerAccessService = new ConsumerAccessService();
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

        List<Application_Stop_Process__c> activeStopProcesses = stateStore.getActiveStopProcesses(application.Id);
        List<Application_Job__c> currentJobs = stateStore.getApplicationJobs(application.Id);
        String nextStepKey = stepNavigator.getNextTransitionCandidate(
            application,
            definition,
            scenario,
            command.stepKey,
            activeStopProcesses,
            currentJobs
        );
        StepRuntimeContext context = new StepRuntimeContext(application, definition, scenario, command, nextStepKey, activeStopProcesses);

        RuleResult validationResult = ruleEngine.evaluateValidationRules(context);
        if (!validationResult.allowed) {
            return CommandResult.blocked(buildSnapshot(application, definition), validationResult);
        }

        stateStore.submitStepData(application.Id, command.stepKey, command.data);
        List<Application_Job__c> queuedJobs = jobEngine.createJobsForStepSubmit(context);
        stateStore.saveJobs(queuedJobs);
        context.setJobs(stateStore.getApplicationJobs(application.Id));
        for (Application_Job__c queuedJob : queuedJobs) {
            eventStore.createEvent(
                application.Id,
                FrameworkConstants.EVENT_JOB_QUEUED,
                'Job queued.',
                queuedJob
            );
        }

        RuleResult targetAvailabilityResult = evaluateTargetAvailability(
            application,
            definition,
            scenario,
            nextStepKey,
            activeStopProcesses,
            context.jobs
        );
        if (!targetAvailabilityResult.allowed) {
            return CommandResult.blocked(buildSnapshot(application, definition), targetAvailabilityResult);
        }

        RuleResult transitionResult = ruleEngine.evaluateStepTransitionRules(context);
        if (!transitionResult.allowed) {
            return CommandResult.blocked(buildSnapshot(application, definition), transitionResult);
        }

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

        ApplicationSnapshot snapshot = buildSnapshot(application, definition);
        eventStore.createEvent(
            application.Id,
            FrameworkConstants.EVENT_SNAPSHOT_RETURNED,
            'Submit Step Snapshot returned.',
            null
        );

        return CommandResult.ok(snapshot);
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
        consumerAccessService.validateApplicationAccess(command.consumerKey, application);
        if (application.Status__c == FrameworkConstants.APPLICATION_STATUS_COMPLETED) {
            throw new FrameworkException('Completed Application cannot be changed.');
        }
        if (application.Current_Step_Key__c != command.stepKey) {
            throw new FrameworkException('Submitted step is not current. Current: ' + application.Current_Step_Key__c + ', Submitted: ' + command.stepKey);
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
