public inherited sharing class RunJobHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ApplicationEventStore eventStore;
    private SnapshotBuilder snapshotBuilder;
    private JobEngine jobEngine;

    public RunJobHandler() {
        this(
            new DefinitionResolver(),
            new ApplicationStateStore(),
            new ApplicationEventStore(),
            new SnapshotBuilder(),
            new JobEngine()
        );
    }

    @TestVisible
    private RunJobHandler(
        DefinitionResolver definitionResolver,
        ApplicationStateStore stateStore,
        ApplicationEventStore eventStore,
        SnapshotBuilder snapshotBuilder,
        JobEngine jobEngine
    ) {
        this.definitionResolver = definitionResolver;
        this.stateStore = stateStore;
        this.eventStore = eventStore;
        this.snapshotBuilder = snapshotBuilder;
        this.jobEngine = jobEngine;
    }

    public CommandResult execute(RunJobCommand command) {
        validateCommand(command);

        Application__c application = stateStore.getApplication((Id) command.applicationId);
        validateApplication(command, application);

        Application_Job__c job = stateStore.getApplicationJob(application.Id, command.jobKey);
        validateJobCanRun(job);

        ProcessDefinition definition = definitionResolver.resolveActive(application.Process_Key__c);

        stateStore.updateJobStatus(job, FrameworkConstants.JOB_STATUS_PROCESSING, null, null);
        eventStore.createEvent(application.Id, FrameworkConstants.EVENT_JOB_STARTED, 'Job started.', job);

        JobExecutionResult executionResult;
        try {
            executionResult = jobEngine.runJob(job, definition);
        } catch (Exception ex) {
            executionResult = JobExecutionResult.fail('UNEXPECTED_JOB_ERROR', ex.getMessage());
        }

        if (executionResult.success) {
            stateStore.updateJobStatus(job, FrameworkConstants.JOB_STATUS_COMPLETED, null, null);
            eventStore.createEvent(application.Id, FrameworkConstants.EVENT_JOB_COMPLETED, 'Job completed.', job);
            return CommandResult.ok(buildSnapshot(application, definition));
        }

        stateStore.updateJobStatus(
            job,
            FrameworkConstants.JOB_STATUS_FAILED,
            executionResult.errorCode,
            executionResult.errorMessage
        );
        eventStore.createEvent(application.Id, FrameworkConstants.EVENT_JOB_FAILED, 'Job failed.', job);
        CommandResult result = CommandResult.fail(executionResult.errorMessage);
        result.snapshot = buildSnapshot(application, definition);
        return result;
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

    private void validateCommand(RunJobCommand command) {
        if (command == null) {
            throw new FrameworkException('RunJob command is required.');
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

    private void validateApplication(RunJobCommand command, Application__c application) {
        if (application.Consumer_Key__c != command.consumerKey) {
            throw new FrameworkException('Consumer is not allowed for Application.');
        }
        if (application.Status__c == FrameworkConstants.APPLICATION_STATUS_COMPLETED) {
            throw new FrameworkException('Completed Application Job cannot be changed.');
        }
    }

    private void validateJobCanRun(Application_Job__c job) {
        if (job.Status__c == FrameworkConstants.JOB_STATUS_QUEUED || job.Status__c == FrameworkConstants.JOB_STATUS_RESTART) {
            return;
        }
        if (job.Status__c == FrameworkConstants.JOB_STATUS_FAILED && job.Can_Be_Restarted__c) {
            return;
        }
        throw new FrameworkException('Application Job cannot run from status: ' + job.Status__c);
    }
}
