global inherited sharing class ApplicationStateStore {
    global Application__c initApplication(InitApplicationCommand command, ProcessDefinition definition) {
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario(command.scenarioKey);
        if (scenario == null) {
            throw new FrameworkException('Scenario was not found. Scenario: ' + command.scenarioKey);
        }

        Application__c existingApplication = findExistingApplication(command);
        if (existingApplication != null) {
            return existingApplication;
        }

        Application__c application = new Application__c();
        application.Process_Key__c = command.processKey;
        application.Scenario_Key__c = command.scenarioKey;
        application.Current_Step_Key__c = scenario.initialStep;
        application.Status__c = FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS;
        application.Conversion_Status__c = FrameworkConstants.CONVERSION_STATUS_NOT_READY;
        application.Consumer_Key__c = command.consumerKey;
        application.External_Reference__c = command.externalReference;
        application.Definition_Version__c = definition.version;
        application.Started_At__c = System.now();
        insert application;

        return application;
    }

    private Application__c findExistingApplication(InitApplicationCommand command) {
        if (String.isBlank(command.externalReference)) {
            return null;
        }

        List<Application__c> applications = [
            SELECT Id, Name, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Status__c,
                Conversion_Status__c, Consumer_Key__c, External_Reference__c, Definition_Version__c,
                Started_At__c, Completed_At__c, Converted_At__c
            FROM Application__c
            WHERE Process_Key__c = :command.processKey
            AND Consumer_Key__c = :command.consumerKey
            AND External_Reference__c = :command.externalReference
            LIMIT 1
        ];

        return applications.isEmpty() ? null : applications[0];
    }
}
