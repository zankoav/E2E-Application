@IsTest
private class GetSnapshotHandlerTest {
    @IsTest
    static void returnsCurrentSnapshotWithData() {
        Application__c application = createApplication();
        SubmitStepCommand submitCommand = new SubmitStepCommand();
        submitCommand.applicationId = String.valueOf(application.Id);
        submitCommand.consumerKey = 'webPortal';
        submitCommand.stepKey = 'contactDetails';
        submitCommand.data = new Map<String, Object>{
            'firstName' => 'Alex',
            'vehicleCount' => 3
        };
        new SubmitStepHandler().execute(submitCommand);

        GetSnapshotCommand command = createSnapshotCommand(application.Id, 'webPortal');

        Test.startTest();
        CommandResult result = new GetSnapshotHandler().execute(command);
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.areEqual('companyDetails', result.snapshot.application.currentStep);
        Assert.areEqual('Alex', result.snapshot.data.get('firstName'));
        Assert.areEqual(Decimal.valueOf(3), result.snapshot.data.get('vehicleCount'));
    }

    @IsTest
    static void rejectsWrongConsumer() {
        Application__c application = createApplication();
        GetSnapshotCommand command = createSnapshotCommand(application.Id, 'mobileApp');

        try {
            new GetSnapshotHandler().execute(command);
            Assert.fail('Expected get snapshot to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Consumer'));
        }
    }

    @IsTest
    static void restControllerReturnsSnapshot() {
        Application__c application = createApplication();
        RestContext.request = createSnapshotRequest(application.Id);
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationSnapshotRestController.post();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(true, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('snapshot'));
    }

    @IsTest
    static void restControllerReturnsErrorForInvalidRequest() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/snapshot';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"consumerKey":"webPortal"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationSnapshotRestController.post();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(false, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('errors'));
    }

    @IsTest
    static void parsesGetSnapshotCommandFromJson() {
        String requestBody = '{"applicationId":"a00123456789012AAA","consumerKey":"webPortal"}';

        GetSnapshotCommand command = GetSnapshotCommand.fromJson(requestBody);

        Assert.areEqual('a00123456789012AAA', command.applicationId);
        Assert.areEqual('webPortal', command.consumerKey);
    }

    private static Application__c createApplication() {
        InitApplicationCommand command = new InitApplicationCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.scenarioKey = 'newCustomer';
        command.externalReference = 'snapshot-' + String.valueOf(Crypto.getRandomInteger());
        Id applicationId = (Id) new InitApplicationHandler().execute(command).snapshot.application.id;
        return [
            SELECT Id, Name, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Status__c,
                Conversion_Status__c, Consumer_Key__c, External_Reference__c, Definition_Version__c,
                Started_At__c, Completed_At__c, Converted_At__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];
    }

    private static GetSnapshotCommand createSnapshotCommand(Id applicationId, String consumerKey) {
        GetSnapshotCommand command = new GetSnapshotCommand();
        command.applicationId = String.valueOf(applicationId);
        command.consumerKey = consumerKey;
        return command;
    }

    private static RestRequest createSnapshotRequest(Id applicationId) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/snapshot';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(
            '{"applicationId":"' + String.valueOf(applicationId) + '","consumerKey":"webPortal"}'
        );
        return request;
    }
}
