public inherited sharing class ApplicationJobQueueable implements Queueable, Database.AllowsCallouts {
    private Id applicationId;
    private String jobKey;

    public ApplicationJobQueueable(Id applicationId, String jobKey) {
        this.applicationId = applicationId;
        this.jobKey = jobKey;
    }

    public void execute(QueueableContext context) {
        ApplicationStateStore stateStore = new ApplicationStateStore();
        ApplicationEventStore eventStore = new ApplicationEventStore();
        DefinitionResolver definitionResolver = new DefinitionResolver();
        JobEngine jobEngine = new JobEngine();

        Application__c application = stateStore.getApplication(applicationId);
        Application_Job__c job = stateStore.getApplicationJob(applicationId, jobKey);
        ProcessDefinition definition = definitionResolver.resolveActive(application.Process_Key__c);

        JobExecutionResult executionResult;
        try {
            executionResult = jobEngine.runJob(job, definition);
        } catch (Exception ex) {
            executionResult = JobExecutionResult.fail('UNEXPECTED_JOB_ERROR', ex.getMessage());
        }

        if (executionResult.success) {
            stateStore.updateJobStatus(job, FrameworkConstants.JOB_STATUS_COMPLETED, null, null);
            eventStore.createEvent(application.Id, FrameworkConstants.EVENT_JOB_COMPLETED, 'Job completed.', job);
            return;
        }

        stateStore.updateJobStatus(
            job,
            FrameworkConstants.JOB_STATUS_FAILED,
            executionResult.errorCode,
            executionResult.errorMessage
        );
        eventStore.createEvent(application.Id, FrameworkConstants.EVENT_JOB_FAILED, 'Job failed.', job);
    }
}
