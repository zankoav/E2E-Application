public inherited sharing class GetJobStatusHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private SnapshotBuilder snapshotBuilder;
    private ConsumerAccessService consumerAccessService;
    private PublicApplicationAccessService publicAccessService;

    public GetJobStatusHandler() {
        this.definitionResolver = new DefinitionResolver();
        this.stateStore = new ApplicationStateStore();
        this.snapshotBuilder = new SnapshotBuilder();
        this.consumerAccessService = new ConsumerAccessService();
        this.publicAccessService = new PublicApplicationAccessService();
    }

    public CommandResult execute(GetJobStatusCommand command) {
        validateCommand(command);

        Application__c application = getApplication(command.applicationId);
        consumerAccessService.validateApplicationAccess(command.consumerKey, application);

        Application_Job__c job = stateStore.getApplicationJob(application.Id, command.jobKey);
        ProcessDefinition definition = definitionResolver.resolveActive(application.Process_Key__c);
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario(application.Scenario_Key__c);
        PublicApplicationAccessService.AccessGrant accessGrant = publicAccessService.validateAndRefresh(
            application,
            scenario,
            command.resumeToken
        );
        return CommandResult.ok(snapshotBuilder.buildJobInfo(job, definition)).withAccess(accessGrant);
    }

    private Application__c getApplication(String applicationId) {
        return publicAccessService.isPublicAccessRequired()
            ? publicAccessService.getApplication((Id) applicationId)
            : stateStore.getApplication((Id) applicationId);
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
