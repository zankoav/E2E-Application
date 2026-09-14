public inherited sharing class GetSnapshotHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private SnapshotBuilder snapshotBuilder;
    private ConsumerAccessService consumerAccessService;
    private PublicApplicationAccessService publicAccessService;

    public GetSnapshotHandler() {
        this.definitionResolver = new DefinitionResolver();
        this.stateStore = new ApplicationStateStore();
        this.snapshotBuilder = new SnapshotBuilder();
        this.consumerAccessService = new ConsumerAccessService();
        this.publicAccessService = new PublicApplicationAccessService();
    }

    public CommandResult execute(GetSnapshotCommand command) {
        validateCommand(command);

        Application__c application = getApplication(command.applicationId);
        consumerAccessService.validateApplicationAccess(command.consumerKey, application);

        ProcessDefinition definition = definitionResolver.resolveActive(application.Process_Key__c);
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario(application.Scenario_Key__c);
        PublicApplicationAccessService.AccessGrant accessGrant = publicAccessService.validateAndRefresh(
            application,
            scenario,
            command.resumeToken
        );
        ApplicationSnapshot snapshot = snapshotBuilder.build(
            application,
            definition,
            stateStore.getApplicationData(application.Id),
            stateStore.getActiveStopProcesses(application.Id),
            stateStore.getApplicationJobs(application.Id)
        );
        return CommandResult.ok(snapshot).withAccess(accessGrant);
    }

    private Application__c getApplication(String applicationId) {
        return publicAccessService.isPublicAccessRequired()
            ? publicAccessService.getApplication((Id) applicationId)
            : stateStore.getApplication((Id) applicationId);
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
