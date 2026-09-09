public inherited sharing class GetReferenceDataHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ConsumerAccessService consumerAccessService;
    private ReferenceDataService referenceDataService;

    public GetReferenceDataHandler() {
        this.definitionResolver = new DefinitionResolver();
        this.stateStore = new ApplicationStateStore();
        this.consumerAccessService = new ConsumerAccessService();
        this.referenceDataService = new ReferenceDataService();
    }

    public CommandResult execute(GetReferenceDataCommand command) {
        validateCommand(command);

        Application__c application = stateStore.getApplication((Id) command.applicationId);
        consumerAccessService.validateApplicationAccess(command.consumerKey, application);

        ProcessDefinition definition = definitionResolver.resolveActive(application.Process_Key__c);
        String stepKey = String.isBlank(command.stepKey) ? application.Current_Step_Key__c : command.stepKey;
        return CommandResult.okReferences(
            referenceDataService.loadReferences(application, definition, stepKey, command.getReferenceKeys())
        );
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
