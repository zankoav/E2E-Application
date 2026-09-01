public inherited sharing class GetJobStatusHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private SnapshotBuilder snapshotBuilder;
    private ConsumerAccessService consumerAccessService;

    public GetJobStatusHandler() {
        this.definitionResolver = new DefinitionResolver();
        this.stateStore = new ApplicationStateStore();
        this.snapshotBuilder = new SnapshotBuilder();
        this.consumerAccessService = new ConsumerAccessService();
    }

    public CommandResult execute(GetJobStatusCommand command) {
        validateCommand(command);

        Application__c application = stateStore.getApplication((Id) command.applicationId);
        consumerAccessService.validateApplicationAccess(command.consumerKey, application);

        Application_Job__c job = stateStore.getApplicationJob(application.Id, command.jobKey);
        ProcessDefinition definition = definitionResolver.resolveActive(application.Process_Key__c);
        return CommandResult.ok(snapshotBuilder.buildJobInfo(job, definition));
    }

    private void validateCommand(GetJobStatusCommand command) {
        if (command == null) {
            throw new FrameworkException('GetJobStatus command is required.');
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
}
