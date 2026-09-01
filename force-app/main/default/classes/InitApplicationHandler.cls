public inherited sharing class InitApplicationHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ApplicationEventStore eventStore;
    private SnapshotBuilder snapshotBuilder;

    public InitApplicationHandler() {
        this.definitionResolver = new DefinitionResolver();
        this.stateStore = new ApplicationStateStore();
        this.eventStore = new ApplicationEventStore();
        this.snapshotBuilder = new SnapshotBuilder();
    }

    public CommandResult execute(InitApplicationCommand command) {
        validateCommand(command);

        ProcessDefinition definition = definitionResolver.resolveActive(command.processKey);
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario(command.scenarioKey);
        validateConsumer(command, scenario);

        ApplicationStateStore.InitResult initResult = stateStore.initApplication(command, definition);
        Application__c application = initResult.application;
        if (initResult.created) {
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

        return CommandResult.ok(snapshot);
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

    private void validateConsumer(InitApplicationCommand command, ProcessDefinition.ScenarioDefinition scenario) {
        if (scenario == null) {
            throw new FrameworkException('Scenario was not found. Scenario: ' + command.scenarioKey);
        }
        if (!scenario.consumerKeys.isEmpty() && !scenario.consumerKeys.contains(command.consumerKey)) {
            throw new FrameworkException('Consumer is not allowed for scenario. Consumer: ' + command.consumerKey + ', Scenario: ' + command.scenarioKey);
        }
    }
}
