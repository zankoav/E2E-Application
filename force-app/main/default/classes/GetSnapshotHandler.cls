public inherited sharing class GetSnapshotHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private SnapshotBuilder snapshotBuilder;
    private ConsumerAccessService consumerAccessService;

    public GetSnapshotHandler() {
        this.definitionResolver = new DefinitionResolver();
        this.stateStore = new ApplicationStateStore();
        this.snapshotBuilder = new SnapshotBuilder();
        this.consumerAccessService = new ConsumerAccessService();
    }

    public CommandResult execute(GetSnapshotCommand command) {
        validateCommand(command);

        Application__c application = stateStore.getApplication((Id) command.applicationId);
        consumerAccessService.validateApplicationAccess(command.consumerKey, application);

        ProcessDefinition definition = definitionResolver.resolveActive(application.Process_Key__c);
        ApplicationSnapshot snapshot = snapshotBuilder.build(
            application,
            definition,
            stateStore.getApplicationData(application.Id),
            stateStore.getActiveStopProcesses(application.Id),
            stateStore.getApplicationJobs(application.Id)
        );
        return CommandResult.ok(snapshot);
    }

    private void validateCommand(GetSnapshotCommand command) {
        if (command == null) {
            throw new FrameworkException('GetSnapshot command is required.');
        }
        if (String.isBlank(command.applicationId)) {
            throw new FrameworkException('Application id is required.');
        }
        if (String.isBlank(command.consumerKey)) {
            throw new FrameworkException('Consumer key is required.');
        }
    }
}
