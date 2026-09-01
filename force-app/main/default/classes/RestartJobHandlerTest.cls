@IsTest
private class RestartJobHandlerTest {
    @IsTest
    static void restartsFailedRestartableJob() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_FAILED, true);

        CommandResult result = new RestartJobHandler().execute(createCommand(application.Id, 'contactDetails___emailValidation'));

        Assert.areEqual(true, result.success);
        Assert.areEqual(FrameworkConstants.JOB_STATUS_RESTART, result.snapshot.jobs[0].status);

        Application_Job__c updatedJob = getJob(application.Id);
        Assert.areEqual(FrameworkConstants.JOB_STATUS_RESTART, updatedJob.Status__c);
        Assert.areEqual(null, updatedJob.External_Job_Id__c);
        Assert.areEqual(null, updatedJob.Error_Code__c);
        Assert.areEqual(null, updatedJob.Error_Message__c);
        Assert.areEqual(1, countEvents(application.Id, FrameworkConstants.EVENT_JOB_RESTARTED));
    }

    @IsTest
    static void restartsProcessingRestartableJob() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_PROCESSING, true);

        CommandResult result = new RestartJobHandler().execute(createCommand(application.Id, 'contactDetails___emailValidation'));

        Assert.areEqual(true, result.success);
        Assert.areEqual(FrameworkConstants.JOB_STATUS_RESTART, result.snapshot.jobs[0].status);
    }

    @IsTest
    static void restartsPreparingRestartableJob() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_PREPARING, true);

        CommandResult result = new RestartJobHandler().execute(createCommand(application.Id, 'contactDetails___emailValidation'));

        Assert.areEqual(true, result.success);
        Assert.areEqual(FrameworkConstants.JOB_STATUS_RESTART, result.snapshot.jobs[0].status);
    }

    @IsTest
    static void rejectsCompletedJobRestart() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_COMPLETED, true);

        try {
            new RestartJobHandler().execute(createCommand(application.Id, 'contactDetails___emailValidation'));
            Assert.fail('Expected completed job restart to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('cannot restart'));
        }
    }

    @IsTest
    static void rejectsNonRestartableJob() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_FAILED, false);

        try {
            new RestartJobHandler().execute(createCommand(application.Id, 'contactDetails___emailValidation'));
            Assert.fail('Expected non restartable job to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('cannot be restarted'));
        }
    }

    @IsTest
    static void rejectsWrongConsumer() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_FAILED, true);
        RestartJobCommand command = createCommand(application.Id, 'contactDetails___emailValidation');
        command.consumerKey = 'mobileApp';

        try {
            new RestartJobHandler().execute(command);
            Assert.fail('Expected wrong consumer to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Consumer'));
        }
    }

    @IsTest
    static void restControllerRestartsJob() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_FAILED, true);
        RestContext.request = createRestartJobRequest(application.Id, 'contactDetails___emailValidation');
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationRestartJobRestController.post();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(true, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('snapshot'));
    }

    @IsTest
    static void restControllerReturnsErrorForInvalidRequest() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/restart-job';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"consumerKey":"webPortal"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationRestartJobRestController.post();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(false, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('errors'));
    }

    @IsTest
    static void parsesRestartJobCommandFromJson() {
        String requestBody = '{"applicationId":"a00123456789012AAA","consumerKey":"webPortal","jobKey":"contactDetails___emailValidation"}';

        RestartJobCommand command = RestartJobCommand.fromJson(requestBody);

        Assert.areEqual('a00123456789012AAA', command.applicationId);
        Assert.areEqual('webPortal', command.consumerKey);
        Assert.areEqual('contactDetails___emailValidation', command.jobKey);
    }

    private static Application__c createApplication() {
        InitApplicationCommand command = new InitApplicationCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.scenarioKey = 'newCustomer';
        command.externalReference = 'restart-' + String.valueOf(Crypto.getRandomInteger());
        Id applicationId = (Id) new InitApplicationHandler().execute(command).snapshot.application.id;
        return [
            SELECT Id, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Consumer_Key__c, Status__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];
    }

    private static RestartJobCommand createCommand(Id applicationId, String jobKey) {
        RestartJobCommand command = new RestartJobCommand();
        command.applicationId = String.valueOf(applicationId);
        command.consumerKey = 'webPortal';
        command.jobKey = jobKey;
        return command;
    }

    private static Application_Job__c createJob(Id applicationId, String status, Boolean canBeRestarted) {
        return new Application_Job__c(
            Application__c = applicationId,
            Job_Key__c = 'contactDetails___emailValidation',
            Job_Name__c = 'emailValidation',
            Source_Step_Key__c = 'contactDetails',
            Status__c = status,
            Execution_Mode__c = FrameworkConstants.JOB_EXECUTION_MODE_SYNC,
            Can_Be_Restarted__c = canBeRestarted,
            External_Job_Id__c = '707000000000000AAA',
            Error_Code__c = 'PREVIOUS_ERROR',
            Error_Message__c = 'Previous error.'
        );
    }

    private static Application_Job__c getJob(Id applicationId) {
        return [
            SELECT Status__c, External_Job_Id__c, Error_Code__c, Error_Message__c
            FROM Application_Job__c
            WHERE Application__c = :applicationId
            LIMIT 1
        ];
    }

    private static Integer countEvents(Id applicationId, String eventType) {
        return [
            SELECT COUNT()
            FROM Application_Event__c
            WHERE Application__c = :applicationId
            AND Event_Type__c = :eventType
        ];
    }

    private static RestRequest createRestartJobRequest(Id applicationId, String jobKey) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/restart-job';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(
            '{"applicationId":"' + String.valueOf(applicationId) + '","consumerKey":"webPortal","jobKey":"' + jobKey + '"}'
        );
        return request;
    }
}
