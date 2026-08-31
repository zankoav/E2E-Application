@IsTest
private class InitApplicationHandlerTest {
    @IsTest
    static void initializesApplicationAndReturnsSnapshot() {
        InitApplicationCommand command = new InitApplicationCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.scenarioKey = 'newCustomer';
        command.externalReference = uniqueExternalReference('handler-init');

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

    @IsTest
    static void reusesApplicationByExternalReference() {
        InitApplicationCommand command = new InitApplicationCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.scenarioKey = 'newCustomer';
        command.externalReference = uniqueExternalReference('handler-reuse');

        CommandResult firstResult = new InitApplicationHandler().execute(command);
        CommandResult secondResult = new InitApplicationHandler().execute(command);

        Assert.areEqual(firstResult.snapshot.application.id, secondResult.snapshot.application.id);

        Integer initializedEvents = [
            SELECT COUNT()
            FROM Application_Event__c
            WHERE Application__c = :firstResult.snapshot.application.id
            AND Event_Type__c = :FrameworkConstants.EVENT_APPLICATION_INITIALIZED
        ];
        Assert.areEqual(1, initializedEvents);
    }

    @IsTest
    static void parsesInitCommandFromJson() {
        String requestBody = '{"consumerKey":"webPortal","processKey":"fuelCardApplication","scenarioKey":"newCustomer","externalReference":"json-ref"}';

        InitApplicationCommand command = InitApplicationCommand.fromJson(requestBody);

        Assert.areEqual('webPortal', command.consumerKey);
        Assert.areEqual('fuelCardApplication', command.processKey);
        Assert.areEqual('newCustomer', command.scenarioKey);
        Assert.areEqual('json-ref', command.externalReference);
    }

    @IsTest
    static void restControllerInitializesApplication() {
        RestContext.request = createInitRequest(uniqueExternalReference('rest-init'));
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationInitRestController.post();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(true, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('snapshot'));
    }

    @IsTest
    static void restControllerReturnsErrorForInvalidCommand() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/init';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"consumerKey":"webPortal"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationInitRestController.post();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(false, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('errors'));
    }

    @IsTest
    static void commandResultCreatesFailureResponse() {
        CommandResult result = CommandResult.fail('Something failed.');

        Assert.areEqual(false, result.success);
        Assert.areEqual(1, result.errors.size());
        Assert.areEqual('Something failed.', result.errors[0]);
    }

    private static RestRequest createInitRequest(String externalReference) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/init';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(
            '{"consumerKey":"webPortal","processKey":"fuelCardApplication","scenarioKey":"newCustomer","externalReference":"' + externalReference + '"}'
        );
        return request;
    }

    private static String uniqueExternalReference(String marker) {
        return marker + '-' + String.valueOf(Crypto.getRandomInteger());
    }
}
