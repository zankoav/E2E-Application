public inherited sharing class GetReferenceDataHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ConsumerAccessService consumerAccessService;
    private ReferenceDataService referenceDataService;
    private PublicApplicationAccessService publicAccessService;

    public GetReferenceDataHandler() {
        this.definitionResolver = new DefinitionResolver();
        this.stateStore = new ApplicationStateStore();
        this.consumerAccessService = new ConsumerAccessService();
        this.referenceDataService = new ReferenceDataService();
        this.publicAccessService = new PublicApplicationAccessService();
    }

    public CommandResult execute(GetReferenceDataCommand command) {
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
        String stepKey = String.isBlank(command.stepKey) ? application.Current_Step_Key__c : command.stepKey;
        return CommandResult.okReferences(
            referenceDataService.loadReferences(application, definition, stepKey, command.getReferenceKeys())
        ).withAccess(accessGrant);
    }

    private Application__c getApplication(String applicationId) {
        return publicAccessService.isPublicAccessRequired()
            ? publicAccessService.getApplication((Id) applicationId)
            : stateStore.getApplication((Id) applicationId);
    }

    private void validateCommand(GetReferenceDataCommand command) {
        if (command == null) {
            throw new FrameworkException('GetReferenceData command is required.');
        }
        if (String.isBlank(command.applicationId)) {
            throw new FrameworkException('Application id is required.');
        }
        if (String.isBlank(command.consumerKey)) {
            throw new FrameworkException('Consumer key is required.');
        }
    }
}
