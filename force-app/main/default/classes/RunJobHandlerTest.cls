@IsTest
private class RunJobHandlerTest {
    @IsTest
    static void runsQueuedJobAndReturnsCompletedSnapshot() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_QUEUED, true);

        RunJobCommand command = createCommand(application.Id, 'contactDetails___emailValidation');

        Test.startTest();
        CommandResult result = new RunJobHandler().execute(command);
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.areEqual(1, result.snapshot.jobs.size());
        Assert.areEqual(FrameworkConstants.JOB_STATUS_COMPLETED, result.snapshot.jobs[0].status);

        Application_Job__c updatedJob = getJob(application.Id);
        Assert.areEqual(FrameworkConstants.JOB_STATUS_COMPLETED, updatedJob.Status__c);
        Assert.areEqual(null, updatedJob.Error_Code__c);

        Assert.areEqual(1, countEvents(application.Id, FrameworkConstants.EVENT_JOB_STARTED));
        Assert.areEqual(1, countEvents(application.Id, FrameworkConstants.EVENT_JOB_COMPLETED));
    }

    @IsTest
    static void marksJobFailedWhenExecutorFails() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_QUEUED, true);

        CommandResult result = createHandler(new FailingJobEngine()).execute(createCommand(application.Id, 'contactDetails___emailValidation'));

        Assert.areEqual(false, result.success);
        Assert.areEqual('Email provider rejected request.', result.errors[0]);
        Assert.areEqual(FrameworkConstants.JOB_STATUS_FAILED, result.snapshot.jobs[0].status);

        Application_Job__c updatedJob = getJob(application.Id);
        Assert.areEqual(FrameworkConstants.JOB_STATUS_FAILED, updatedJob.Status__c);
        Assert.areEqual('EMAIL_PROVIDER_ERROR', updatedJob.Error_Code__c);
        Assert.areEqual('Email provider rejected request.', updatedJob.Error_Message__c);
        Assert.areEqual(1, countEvents(application.Id, FrameworkConstants.EVENT_JOB_FAILED));
    }

    @IsTest
    static void rejectsCompletedJobRun() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_COMPLETED, true);

        try {
            new RunJobHandler().execute(createCommand(application.Id, 'contactDetails___emailValidation'));
            Assert.fail('Expected completed job run to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('cannot run'));
        }
    }

    @IsTest
    static void allowsRestartableFailedJobRun() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_FAILED, true);

        CommandResult result = new RunJobHandler().execute(createCommand(application.Id, 'contactDetails___emailValidation'));

        Assert.areEqual(true, result.success);
        Assert.areEqual(FrameworkConstants.JOB_STATUS_COMPLETED, result.snapshot.jobs[0].status);
    }

    @IsTest
    static void rejectsWrongConsumer() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_QUEUED, true);

        RunJobCommand command = createCommand(application.Id, 'contactDetails___emailValidation');
        command.consumerKey = 'mobileApp';

        try {
            new RunJobHandler().execute(command);
            Assert.fail('Expected wrong consumer to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Consumer'));
        }
    }

    @IsTest
    static void restControllerRunsJob() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_QUEUED, true);
        RestContext.request = createRunJobRequest(application.Id, 'contactDetails___emailValidation');
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationRunJobRestController.post();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(true, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('snapshot'));
    }

    @IsTest
    static void restControllerReturnsErrorForInvalidRequest() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/run-job';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"consumerKey":"webPortal"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationRunJobRestController.post();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(false, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('errors'));
    }

    @IsTest
    static void parsesRunJobCommandFromJson() {
        String requestBody = '{"applicationId":"a00123456789012AAA","consumerKey":"webPortal","jobKey":"contactDetails___emailValidation"}';

        RunJobCommand command = RunJobCommand.fromJson(requestBody);

        Assert.areEqual('a00123456789012AAA', command.applicationId);
        Assert.areEqual('webPortal', command.consumerKey);
        Assert.areEqual('contactDetails___emailValidation', command.jobKey);
    }

    private static RunJobHandler createHandler(JobEngine jobEngine) {
        return new RunJobHandler(
            new DefinitionResolver(),
            new ApplicationStateStore(),
            new ApplicationEventStore(),
            new SnapshotBuilder(),
            jobEngine
        );
    }

    private static Application__c createApplication() {
        InitApplicationCommand command = new InitApplicationCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.scenarioKey = 'newCustomer';
        command.externalReference = 'run-job-' + String.valueOf(Crypto.getRandomInteger());
        Id applicationId = (Id) new InitApplicationHandler().execute(command).snapshot.application.id;
        return [
            SELECT Id, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Consumer_Key__c, Status__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];
    }

    private static RunJobCommand createCommand(Id applicationId, String jobKey) {
        RunJobCommand command = new RunJobCommand();
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
            Can_Be_Restarted__c = canBeRestarted
        );
    }

    private static Application_Job__c getJob(Id applicationId) {
        return [
            SELECT Status__c, Error_Code__c, Error_Message__c
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

    private static RestRequest createRunJobRequest(Id applicationId, String jobKey) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/run-job';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(
            '{"applicationId":"' + String.valueOf(applicationId) + '","consumerKey":"webPortal","jobKey":"' + jobKey + '"}'
        );
        return request;
    }

    private class FailingJobEngine extends JobEngine {
        public override JobExecutionResult runJob(Application_Job__c job, ProcessDefinition definition) {
            return JobExecutionResult.fail('EMAIL_PROVIDER_ERROR', 'Email provider rejected request.');
        }
    }
}
