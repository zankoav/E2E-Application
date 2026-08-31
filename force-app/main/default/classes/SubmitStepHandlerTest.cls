@IsTest
private class SubmitStepHandlerTest {
    @IsTest
    static void submitsCurrentStepAndMovesToNextStep() {
        Application__c application = createApplication();
        SubmitStepCommand command = createSubmitCommand(application.Id, 'contactDetails');
        command.data.put('firstName', 'Alex');
        command.data.put('acceptedTerms', true);

        Test.startTest();
        CommandResult result = new SubmitStepHandler().execute(command);
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.areEqual('companyDetails', result.snapshot.application.currentStep);
        Assert.areEqual('Alex', result.snapshot.data.get('firstName'));
        Assert.areEqual(true, result.snapshot.data.get('acceptedTerms'));

        Application__c updatedApplication = [
            SELECT Current_Step_Key__c, Status__c
            FROM Application__c
            WHERE Id = :application.Id
            LIMIT 1
        ];
        Assert.areEqual('companyDetails', updatedApplication.Current_Step_Key__c);
        Assert.areEqual(FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS, updatedApplication.Status__c);

        Map<String, Application_Data__c> dataByKey = getDataByKey(application.Id);
        Assert.areEqual('Alex', dataByKey.get('firstName').Value__c);
        Assert.areEqual('Boolean', dataByKey.get('acceptedTerms').Type__c);
        Assert.areEqual('true', dataByKey.get('acceptedTerms').Value__c);
    }

    @IsTest
    static void submittingStepBeforeFinishCompletesApplication() {
        Application__c application = createApplication();
        application.Current_Step_Key__c = 'companyDetails';
        update application;

        SubmitStepCommand command = createSubmitCommand(application.Id, 'companyDetails');
        command.data.put('companyName', 'Fleet Test Ltd');

        Test.startTest();
        CommandResult result = new SubmitStepHandler().execute(command);
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.areEqual(FrameworkConstants.APPLICATION_STATUS_COMPLETED, result.snapshot.application.status);
        Assert.areEqual('finish', result.snapshot.application.currentStep);

        Application__c updatedApplication = [
            SELECT Current_Step_Key__c, Status__c, Completed_At__c
            FROM Application__c
            WHERE Id = :application.Id
            LIMIT 1
        ];
        Assert.areEqual('finish', updatedApplication.Current_Step_Key__c);
        Assert.areEqual(FrameworkConstants.APPLICATION_STATUS_COMPLETED, updatedApplication.Status__c);
        Assert.isNotNull(updatedApplication.Completed_At__c);

        Integer finishedEvents = [
            SELECT COUNT()
            FROM Application_Event__c
            WHERE Application__c = :application.Id
            AND Event_Type__c = :FrameworkConstants.EVENT_APPLICATION_FINISHED
        ];
        Assert.areEqual(1, finishedEvents);
    }

    @IsTest
    static void rejectsSubmitForNonCurrentStep() {
        Application__c application = createApplication();
        SubmitStepCommand command = createSubmitCommand(application.Id, 'companyDetails');

        try {
            new SubmitStepHandler().execute(command);
            Assert.fail('Expected submit step to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('not current'));
        }
    }

    @IsTest
    static void restControllerSubmitsStep() {
        Application__c application = createApplication();
        RestContext.request = createSubmitRequest(application.Id, 'contactDetails');
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationSubmitStepRestController.post();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(true, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('snapshot'));
    }

    @IsTest
    static void restControllerReturnsErrorForInvalidSubmit() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/submit-step';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"consumerKey":"webPortal"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationSubmitStepRestController.post();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(false, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('errors'));
    }

    @IsTest
    static void parsesSubmitCommandFromJson() {
        String requestBody = '{"applicationId":"a00123456789012AAA","consumerKey":"webPortal","stepKey":"contactDetails","data":{"firstName":"Alex","age":42}}';

        SubmitStepCommand command = SubmitStepCommand.fromJson(requestBody);

        Assert.areEqual('a00123456789012AAA', command.applicationId);
        Assert.areEqual('webPortal', command.consumerKey);
        Assert.areEqual('contactDetails', command.stepKey);
        Assert.areEqual('Alex', command.data.get('firstName'));
        Assert.areEqual(42, command.data.get('age'));
    }

    private static Application__c createApplication() {
        InitApplicationCommand command = new InitApplicationCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.scenarioKey = 'newCustomer';
        command.externalReference = 'submit-' + String.valueOf(Crypto.getRandomInteger());
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

    private static SubmitStepCommand createSubmitCommand(Id applicationId, String stepKey) {
        SubmitStepCommand command = new SubmitStepCommand();
        command.applicationId = String.valueOf(applicationId);
        command.consumerKey = 'webPortal';
        command.stepKey = stepKey;
        command.data = new Map<String, Object>();
        return command;
    }

    private static RestRequest createSubmitRequest(Id applicationId, String stepKey) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/submit-step';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(
            '{"applicationId":"' + String.valueOf(applicationId) + '","consumerKey":"webPortal","stepKey":"' + stepKey + '","data":{"firstName":"Alex"}}'
        );
        return request;
    }

    private static Map<String, Application_Data__c> getDataByKey(Id applicationId) {
        Map<String, Application_Data__c> dataByKey = new Map<String, Application_Data__c>();
        for (Application_Data__c dataRecord : [
            SELECT Key__c, Value__c, Value_JSON__c, Type__c
            FROM Application_Data__c
            WHERE Application__c = :applicationId
        ]) {
            dataByKey.put(dataRecord.Key__c, dataRecord);
        }
        return dataByKey;
    }
}
