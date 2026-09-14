public inherited sharing class InitApplicationHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ApplicationEventStore eventStore;
    private SnapshotBuilder snapshotBuilder;
    private ConsumerAccessService consumerAccessService;
    private PublicApplicationAccessService publicAccessService;

    public InitApplicationHandler() {
        this.definitionResolver = new DefinitionResolver();
        this.stateStore = new ApplicationStateStore();
        this.eventStore = new ApplicationEventStore();
        this.snapshotBuilder = new SnapshotBuilder();
        this.consumerAccessService = new ConsumerAccessService();
        this.publicAccessService = new PublicApplicationAccessService();
    }

    public CommandResult execute(InitApplicationCommand command) {
        validateCommand(command);

        ProcessDefinition definition = definitionResolver.resolveActive(command.processKey);
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario(command.scenarioKey);
        ConsumerDefinition consumer = consumerAccessService.validateInitAccess(
            command.consumerKey,
            command.processKey,
            command.scenarioKey,
            scenario
        );
        publicAccessService.requirePublicInitAllowed(scenario);

        Application__c application;
        Boolean created = false;
        Id applicationOwnerId = publicAccessService.getPublicApplicationOwnerId(consumer);
        if (publicAccessService.isPublicAccessRequired()) {
            application = publicAccessService.findExistingApplication(command);
        }
        if (application == null) {
            if (publicAccessService.isPublicAccessRequired()) {
                application = publicAccessService.initPublicApplication(command, definition, applicationOwnerId);
                created = true;
            } else {
                ApplicationStateStore.InitResult initResult = stateStore.initApplication(command, definition);
                application = initResult.application;
                created = initResult.created;
            }
        }

        PublicApplicationAccessService.AccessGrant accessGrant = created
            ? publicAccessService.issue(application, scenario)
            : publicAccessService.validateAndRefresh(application, scenario, command.resumeToken);

        if (created) {
            eventStore.createEvent(
                application.Id,
                FrameworkConstants.EVENT_APPLICATION_INITIALIZED,
                'Application initialized.',
                command
            );
        }

        ApplicationSnapshot snapshot = snapshotBuilder.build(
            application,
            definition,
            stateStore.getApplicationData(application.Id),
            stateStore.getActiveStopProcesses(application.Id),
            stateStore.getApplicationJobs(application.Id)
        );
        eventStore.createEvent(
            application.Id,
            FrameworkConstants.EVENT_SNAPSHOT_RETURNED,
            'Initial Snapshot returned.',
            null
        );

        return CommandResult.ok(snapshot).withAccess(accessGrant);
    }

    private void validateCommand(InitApplicationCommand command) {
        if (command == null) {
            throw new FrameworkException('InitApplication command is required.');
        }
        if (String.isBlank(command.consumerKey)) {
            throw new FrameworkException('Consumer key is required.');
        }
        if (String.isBlank(command.processKey)) {
            throw new FrameworkException('Process key is required.');
        }
        if (String.isBlank(command.scenarioKey)) {
            throw new FrameworkException('Scenario key is required.');
        }
    }

}
