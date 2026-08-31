@IsTest
private class InitApplicationHandlerTest {
    @IsTest
    static void initializesApplicationAndReturnsSnapshot() {
        InitApplicationCommand command = new InitApplicationCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.scenarioKey = 'newCustomer';
        command.externalReference = 'test-' + Test.getRunId();

        Test.startTest();
        CommandResult result = new InitApplicationHandler().execute(command);
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.isNotNull(result.snapshot);
        Assert.isNotNull(result.snapshot.application);
        Assert.areEqual('fuelCardApplication', result.snapshot.application.processKey);
        Assert.areEqual('newCustomer', result.snapshot.application.scenarioKey);
        Assert.areEqual('contactDetails', result.snapshot.application.currentStep);

        Application__c application = [
            SELECT Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Status__c, Conversion_Status__c
            FROM Application__c
            WHERE Id = :result.snapshot.application.id
            LIMIT 1
        ];

        Assert.areEqual('fuelCardApplication', application.Process_Key__c);
        Assert.areEqual('newCustomer', application.Scenario_Key__c);
        Assert.areEqual(FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS, application.Status__c);
        Assert.areEqual(FrameworkConstants.CONVERSION_STATUS_NOT_READY, application.Conversion_Status__c);
    }
}
