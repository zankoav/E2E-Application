public inherited sharing class RunJobHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ApplicationEventStore eventStore;
    private SnapshotBuilder snapshotBuilder;
    private JobEngine jobEngine;
    private ConsumerAccessService consumerAccessService;

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
        this.consumerAccessService = new ConsumerAccessService();
    }

    public CommandResult execute(RunJobCommand command) {
        validateCommand(command);

        Application__c application = stateStore.getApplication((Id) command.applicationId);
        validateApplication(command, application);

        Application_Job__c job = stateStore.getApplicationJob(application.Id, command.jobKey);
        ProcessDefinition definition = definitionResolver.resolveActive(application.Process_Key__c);

        validateJobCanRun(job);

        if (getExecutionMode(job) == FrameworkConstants.JOB_EXECUTION_MODE_SYNC_CALLOUT) {
            return runSyncCalloutJob(application, definition, job);
        }
        if (getExecutionMode(job) == FrameworkConstants.JOB_EXECUTION_MODE_ASYNC) {
            return startAsyncJob(application, definition, job);
        }
        if (getExecutionMode(job) == FrameworkConstants.JOB_EXECUTION_MODE_SYNC) {
            return runSyncJob(application, definition, job);
        }

        throw new FrameworkException('Unsupported Job execution mode: ' + job.Execution_Mode__c);
    }

    private CommandResult runSyncJob(Application__c application, ProcessDefinition definition, Application_Job__c job) {
        startProcessing(application, job);
        return finishJob(application, definition, job, executeJob(job, definition));
    }

    private CommandResult runSyncCalloutJob(Application__c application, ProcessDefinition definition, Application_Job__c job) {
        if (job.Status__c != FrameworkConstants.JOB_STATUS_PREPARING) {
            stateStore.updateJobStatus(job, FrameworkConstants.JOB_STATUS_PREPARING, null, null);
            eventStore.createEvent(application.Id, FrameworkConstants.EVENT_JOB_PREPARED, 'Job prepared.', job);
            return CommandResult.ok(buildSnapshot(application, definition));
        }

        return finishJob(application, definition, job, executeJob(job, definition));
    }

    private CommandResult startAsyncJob(Application__c application, ProcessDefinition definition, Application_Job__c job) {
        startProcessing(application, job);
        String asyncJobId = System.enqueueJob(new ApplicationJobQueueable(application.Id, job.Job_Key__c));
        stateStore.updateJobAsyncId(job, asyncJobId);
        return CommandResult.ok(buildSnapshot(application, definition));
    }

    private void startProcessing(Application__c application, Application_Job__c job) {
        stateStore.updateJobStatus(job, FrameworkConstants.JOB_STATUS_PROCESSING, null, null);
        eventStore.createEvent(application.Id, FrameworkConstants.EVENT_JOB_STARTED, 'Job started.', job);
    }

    private JobExecutionResult executeJob(Application_Job__c job, ProcessDefinition definition) {
        JobExecutionResult executionResult;
        try {
            executionResult = jobEngine.runJob(job, definition);
        } catch (Exception ex) {
            executionResult = JobExecutionResult.fail('UNEXPECTED_JOB_ERROR', ex.getMessage());
        }
        return executionResult;
    }

    private CommandResult finishJob(Application__c application, ProcessDefinition definition, Application_Job__c job, JobExecutionResult executionResult) {
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
        consumerAccessService.validateApplicationAccess(command.consumerKey, application);
        if (application.Status__c == FrameworkConstants.APPLICATION_STATUS_COMPLETED) {
            throw new FrameworkException('Completed Application Job cannot be changed.');
        }
    }

    private void validateJobCanRun(Application_Job__c job) {
        if (getExecutionMode(job) == FrameworkConstants.JOB_EXECUTION_MODE_SYNC_CALLOUT && job.Status__c == FrameworkConstants.JOB_STATUS_PREPARING) {
            return;
        }
        if (job.Status__c == FrameworkConstants.JOB_STATUS_QUEUED || job.Status__c == FrameworkConstants.JOB_STATUS_RESTART) {
            return;
        }
        if (job.Status__c == FrameworkConstants.JOB_STATUS_FAILED && job.Can_Be_Restarted__c) {
            return;
        }
        throw new FrameworkException('Application Job cannot run from status: ' + job.Status__c);
    }

    private String getExecutionMode(Application_Job__c job) {
        return String.isBlank(job.Execution_Mode__c)
            ? FrameworkConstants.JOB_EXECUTION_MODE_SYNC
            : job.Execution_Mode__c;
    }
}
