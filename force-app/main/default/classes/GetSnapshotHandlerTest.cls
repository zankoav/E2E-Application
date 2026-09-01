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
        Assert.areEqual(FrameworkConstants.STEP_STATUS_COMPLETED, getStepByKey(result.snapshot.steps, 'contactDetails').status);
        Assert.areEqual(FrameworkConstants.STEP_STATUS_CURRENT, getStepByKey(result.snapshot.steps, 'companyDetails').status);
        Assert.areEqual(FrameworkConstants.STEP_STATUS_AVAILABLE, getStepByKey(result.snapshot.steps, 'finish').status);
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
    static void returnsActiveStopProcessesInSnapshot() {
        Application__c application = createApplication();
        insert new Application_Stop_Process__c(
            Application__c = application.Id,
            Code__c = 'DUPLICATE_CUSTOMER',
            Label__c = 'Duplicate Customer',
            Type__c = 'ManualUnlockRequired',
            Status__c = FrameworkConstants.STOP_PROCESS_STATUS_ACTIVE,
            Message__c = 'Manual review is required.',
            Activated_At__c = System.now()
        );

        CommandResult result = new GetSnapshotHandler().execute(createSnapshotCommand(application.Id, 'webPortal'));

        Assert.areEqual(true, result.success);
        Assert.areEqual(1, result.snapshot.stopProcesses.size());
        Assert.areEqual('DUPLICATE_CUSTOMER', result.snapshot.stopProcesses[0].code);
        Assert.areEqual('Duplicate Customer', result.snapshot.stopProcesses[0].label);
    }

    @IsTest
    static void returnsAvailableActionsForEachJob() {
        Application__c application = createApplication();
        insert new List<Application_Job__c>{
            createJob(application.Id, 'queuedSync', FrameworkConstants.JOB_STATUS_QUEUED, FrameworkConstants.JOB_EXECUTION_MODE_SYNC, true),
            createJob(application.Id, 'preparingCallout', FrameworkConstants.JOB_STATUS_PREPARING, FrameworkConstants.JOB_EXECUTION_MODE_SYNC_CALLOUT, true),
            createJob(application.Id, 'processingAsync', FrameworkConstants.JOB_STATUS_PROCESSING, FrameworkConstants.JOB_EXECUTION_MODE_ASYNC, true),
            createJob(application.Id, 'failedRestartable', FrameworkConstants.JOB_STATUS_FAILED, FrameworkConstants.JOB_EXECUTION_MODE_SYNC, true),
            createJob(application.Id, 'completedSync', FrameworkConstants.JOB_STATUS_COMPLETED, FrameworkConstants.JOB_EXECUTION_MODE_SYNC, true),
            createJob(application.Id, 'failedNonRestartable', FrameworkConstants.JOB_STATUS_FAILED, FrameworkConstants.JOB_EXECUTION_MODE_SYNC, false)
        };

        CommandResult result = new GetSnapshotHandler().execute(createSnapshotCommand(application.Id, 'webPortal'));
        Map<String, ApplicationSnapshot.JobInfo> jobsByKey = getJobsByKey(result.snapshot.jobs);

        assertActions(jobsByKey.get('contactDetails___queuedSync'), new List<String>{ 'RunJob' });
        assertActions(jobsByKey.get('contactDetails___preparingCallout'), new List<String>{ 'RunJob', 'RestartJob' });
        assertActions(jobsByKey.get('contactDetails___processingAsync'), new List<String>{ 'RestartJob' });
        assertActions(jobsByKey.get('contactDetails___failedRestartable'), new List<String>{ 'RunJob', 'RestartJob' });
        assertActions(jobsByKey.get('contactDetails___completedSync'), new List<String>());
        assertActions(jobsByKey.get('contactDetails___failedNonRestartable'), new List<String>());
    }

    @IsTest
    static void marksUnavailableStepsInSnapshot() {
        Application__c application = createApplication();
        ProcessDefinition definition = new DefinitionResolver().resolveActive(application.Process_Key__c);

        ApplicationSnapshot snapshot = new SnapshotBuilder(new LockedCompanyDetailsRuleEngine()).build(
            application,
            definition,
            new List<Application_Data__c>(),
            new List<Application_Stop_Process__c>(),
            new List<Application_Job__c>()
        );

        Assert.areEqual(FrameworkConstants.STEP_STATUS_CURRENT, getStepByKey(snapshot.steps, 'contactDetails').status);
        Assert.areEqual(FrameworkConstants.STEP_STATUS_LOCKED, getStepByKey(snapshot.steps, 'companyDetails').status);
        Assert.areEqual('Company details are locked.', getStepByKey(snapshot.steps, 'companyDetails').unavailableReason);
        Assert.areEqual(FrameworkConstants.STEP_STATUS_LOCKED, getStepByKey(snapshot.steps, 'finish').status);
        Assert.areEqual('Complete previous steps first.', getStepByKey(snapshot.steps, 'finish').unavailableReason);
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

    private static Application_Job__c createJob(Id applicationId, String keySuffix, String status, String executionMode, Boolean canBeRestarted) {
        return new Application_Job__c(
            Application__c = applicationId,
            Job_Key__c = 'contactDetails___' + keySuffix,
            Job_Name__c = 'emailValidation',
            Source_Step_Key__c = 'contactDetails',
            Status__c = status,
            Execution_Mode__c = executionMode,
            Can_Be_Restarted__c = canBeRestarted
        );
    }

    private static Map<String, ApplicationSnapshot.JobInfo> getJobsByKey(List<ApplicationSnapshot.JobInfo> jobs) {
        Map<String, ApplicationSnapshot.JobInfo> jobsByKey = new Map<String, ApplicationSnapshot.JobInfo>();
        for (ApplicationSnapshot.JobInfo job : jobs) {
            jobsByKey.put(job.key, job);
        }
        return jobsByKey;
    }

    private static void assertActions(ApplicationSnapshot.JobInfo job, List<String> expectedActions) {
        Assert.isNotNull(job);
        Assert.areEqual(expectedActions.size(), job.availableActions.size());
        for (String expectedAction : expectedActions) {
            Assert.isTrue(job.availableActions.contains(expectedAction), 'Missing Job action: ' + expectedAction);
        }
    }

    private static ApplicationSnapshot.StepInfo getStepByKey(List<ApplicationSnapshot.StepInfo> steps, String stepKey) {
        for (ApplicationSnapshot.StepInfo step : steps) {
            if (step.key == stepKey) {
                return step;
            }
        }
        return null;
    }

    private class LockedCompanyDetailsRuleEngine extends RuleEngine {
        public override RuleResult evaluateStepAvailability(StepRuntimeContext context) {
            if (context.currentStepKey == 'companyDetails') {
                return RuleResult.block(FrameworkConstants.STEP_UNAVAILABLE_LOCKED, 'Company details are locked.');
            }
            return RuleResult.allow();
        }
    }
}
