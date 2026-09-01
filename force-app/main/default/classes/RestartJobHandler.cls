public inherited sharing class RestartJobHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ApplicationEventStore eventStore;
    private SnapshotBuilder snapshotBuilder;
    private ConsumerAccessService consumerAccessService;

    public RestartJobHandler() {
        this(
            new DefinitionResolver(),
            new ApplicationStateStore(),
            new ApplicationEventStore(),
            new SnapshotBuilder()
        );
    }

    @TestVisible
    private RestartJobHandler(
        DefinitionResolver definitionResolver,
        ApplicationStateStore stateStore,
        ApplicationEventStore eventStore,
        SnapshotBuilder snapshotBuilder
    ) {
        this.definitionResolver = definitionResolver;
        this.stateStore = stateStore;
        this.eventStore = eventStore;
        this.snapshotBuilder = snapshotBuilder;
        this.consumerAccessService = new ConsumerAccessService();
    }

    public CommandResult execute(RestartJobCommand command) {
        validateCommand(command);

        Application__c application = stateStore.getApplication((Id) command.applicationId);
        validateApplication(command, application);

        Application_Job__c job = stateStore.getApplicationJob(application.Id, command.jobKey);
        validateJobCanRestart(job);

        ProcessDefinition definition = definitionResolver.resolveActive(application.Process_Key__c);
        stateStore.restartJob(job);
        eventStore.createEvent(application.Id, FrameworkConstants.EVENT_JOB_RESTARTED, 'Job restarted.', job);

        return CommandResult.ok(buildSnapshot(application, definition));
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

    private void validateCommand(RestartJobCommand command) {
        if (command == null) {
            throw new FrameworkException('RestartJob command is required.');
        }
        if (String.isBlank(command.applicationId)) {
            throw new FrameworkException('Application id is required.');
        }
        if (String.isBlank(command.consumerKey)) {
            throw new FrameworkException('Consumer key is required.');
        }
        if (String.isBlank(command.jobKey)) {
            throw new FrameworkException('Job key is required.');
        }
    }

    private void validateApplication(RestartJobCommand command, Application__c application) {
        consumerAccessService.validateApplicationAccess(command.consumerKey, application);
        if (application.Status__c == FrameworkConstants.APPLICATION_STATUS_COMPLETED) {
            throw new FrameworkException('Completed Application Job cannot be restarted.');
        }
    }

    private void validateJobCanRestart(Application_Job__c job) {
        if (!job.Can_Be_Restarted__c) {
            throw new FrameworkException('Application Job cannot be restarted.');
        }
        if (
            job.Status__c == FrameworkConstants.JOB_STATUS_FAILED ||
            job.Status__c == FrameworkConstants.JOB_STATUS_PROCESSING ||
            job.Status__c == FrameworkConstants.JOB_STATUS_PREPARING
        ) {
            return;
        }
        throw new FrameworkException('Application Job cannot restart from status: ' + job.Status__c);
    }
}
