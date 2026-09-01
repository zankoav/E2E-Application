@IsTest
private class GetJobStatusHandlerTest {
    @IsTest
    static void returnsSingleJobStatusWithAvailableActions() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_PREPARING, FrameworkConstants.JOB_EXECUTION_MODE_SYNC_CALLOUT, true);

        CommandResult result = new GetJobStatusHandler().execute(createCommand(application.Id, 'contactDetails___emailValidation'));

        Assert.areEqual(true, result.success);
        Assert.isNotNull(result.job);
        Assert.areEqual('contactDetails___emailValidation', result.job.key);
        Assert.areEqual('emailValidation', result.job.name);
        Assert.areEqual('Email Validation', result.job.label);
        Assert.areEqual(FrameworkConstants.JOB_STATUS_PREPARING, result.job.status);
        Assert.areEqual(FrameworkConstants.JOB_EXECUTION_MODE_SYNC_CALLOUT, result.job.executionMode);
        Assert.isTrue(result.job.availableActions.contains('RunJob'));
        Assert.isTrue(result.job.availableActions.contains('RestartJob'));
        Assert.areEqual(null, result.snapshot);
    }

    @IsTest
    static void rejectsWrongConsumer() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_QUEUED, FrameworkConstants.JOB_EXECUTION_MODE_SYNC, true);
        GetJobStatusCommand command = createCommand(application.Id, 'contactDetails___emailValidation');
        command.consumerKey = 'mobileApp';

        try {
            new GetJobStatusHandler().execute(command);
            Assert.fail('Expected wrong consumer to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Consumer'));
        }
    }

    @IsTest
    static void rejectsMissingJob() {
        Application__c application = createApplication();

        try {
            new GetJobStatusHandler().execute(createCommand(application.Id, 'contactDetails___emailValidation'));
            Assert.fail('Expected missing job to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('was not found'));
        }
    }

    @IsTest
    static void restControllerReturnsJobStatus() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_QUEUED, FrameworkConstants.JOB_EXECUTION_MODE_SYNC, true);
        RestContext.request = createJobStatusRequest(application.Id, 'contactDetails___emailValidation');
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationJobStatusRestController.post();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(true, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('job'));
    }

    @IsTest
    static void restControllerReturnsErrorForInvalidRequest() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/job-status';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"consumerKey":"webPortal"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationJobStatusRestController.post();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(false, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('errors'));
    }

    @IsTest
    static void parsesGetJobStatusCommandFromJson() {
        String requestBody = '{"applicationId":"a00123456789012AAA","consumerKey":"webPortal","jobKey":"contactDetails___emailValidation"}';

        GetJobStatusCommand command = GetJobStatusCommand.fromJson(requestBody);

        Assert.areEqual('a00123456789012AAA', command.applicationId);
        Assert.areEqual('webPortal', command.consumerKey);
        Assert.areEqual('contactDetails___emailValidation', command.jobKey);
    }

    private static Application__c createApplication() {
        InitApplicationCommand command = new InitApplicationCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.scenarioKey = 'newCustomer';
        command.externalReference = 'job-status-' + String.valueOf(Crypto.getRandomInteger());
        Id applicationId = (Id) new InitApplicationHandler().execute(command).snapshot.application.id;
        return [
            SELECT Id, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Consumer_Key__c, Status__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];
    }

    private static GetJobStatusCommand createCommand(Id applicationId, String jobKey) {
        GetJobStatusCommand command = new GetJobStatusCommand();
        command.applicationId = String.valueOf(applicationId);
        command.consumerKey = 'webPortal';
        command.jobKey = jobKey;
        return command;
    }

    private static Application_Job__c createJob(Id applicationId, String status, String executionMode, Boolean canBeRestarted) {
        return new Application_Job__c(
            Application__c = applicationId,
            Job_Key__c = 'contactDetails___emailValidation',
            Job_Name__c = 'emailValidation',
            Source_Step_Key__c = 'contactDetails',
            Status__c = status,
            Execution_Mode__c = executionMode,
            Can_Be_Restarted__c = canBeRestarted
        );
    }

    private static RestRequest createJobStatusRequest(Id applicationId, String jobKey) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/job-status';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(
            '{"applicationId":"' + String.valueOf(applicationId) + '","consumerKey":"webPortal","jobKey":"' + jobKey + '"}'
        );
        return request;
    }
}
