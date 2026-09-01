@IsTest
private class ContinueApplicationHandlerTest {
    @IsTest
    static void blocksWhenRequiredJobIsNotCompleted() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_QUEUED);

        CommandResult result = createHandler(new RequiredJobRuleEngine()).execute(createCommand(application.Id, 'contactDetails'));

        Assert.areEqual(false, result.success);
        Assert.areEqual('Required Job is not completed. Job: contactDetails___emailValidation', result.errors[0]);
        Assert.areEqual('contactDetails', getApplication(application.Id).Current_Step_Key__c);
        Assert.areEqual(1, countEvents(application.Id, FrameworkConstants.EVENT_TRANSITION_BLOCKED));
    }

    @IsTest
    static void movesToNextStepWhenRequiredJobIsCompleted() {
        Application__c application = createApplication();
        insert createJob(application.Id, FrameworkConstants.JOB_STATUS_COMPLETED);

        CommandResult result = createHandler(new RequiredJobRuleEngine()).execute(createCommand(application.Id, 'contactDetails'));

        Assert.areEqual(true, result.success);
        Assert.areEqual('companyDetails', result.snapshot.application.currentStep);
        Assert.areEqual('companyDetails', getApplication(application.Id).Current_Step_Key__c);
        Assert.areEqual(1, countEvents(application.Id, FrameworkConstants.EVENT_TRANSITION_COMPLETED));
    }

    @IsTest
    static void completesApplicationWhenNextStepIsFinish() {
        Application__c application = createApplication();
        application.Current_Step_Key__c = 'companyDetails';
        update application;

        CommandResult result = new ContinueApplicationHandler().execute(createCommand(application.Id, 'companyDetails'));

        Assert.areEqual(true, result.success);
        Assert.areEqual(FrameworkConstants.APPLICATION_STATUS_COMPLETED, result.snapshot.application.status);
        Assert.areEqual('finish', result.snapshot.application.currentStep);
        Assert.areEqual(1, countEvents(application.Id, FrameworkConstants.EVENT_APPLICATION_FINISHED));
    }

    @IsTest
    static void rejectsContinueForNonCurrentStep() {
        Application__c application = createApplication();

        try {
            new ContinueApplicationHandler().execute(createCommand(application.Id, 'companyDetails'));
            Assert.fail('Expected continue application to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('not current'));
        }
    }

    @IsTest
    static void restControllerContinuesApplication() {
        Application__c application = createApplication();
        RestContext.request = createContinueRequest(application.Id, 'contactDetails');
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationContinueRestController.post();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(true, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('snapshot'));
    }

    @IsTest
    static void restControllerReturnsErrorForInvalidRequest() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/continue';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"consumerKey":"webPortal"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationContinueRestController.post();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(false, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('errors'));
    }

    @IsTest
    static void parsesContinueCommandFromJson() {
        String requestBody = '{"applicationId":"a00123456789012AAA","consumerKey":"webPortal","stepKey":"contactDetails"}';

        ContinueApplicationCommand command = ContinueApplicationCommand.fromJson(requestBody);

        Assert.areEqual('a00123456789012AAA', command.applicationId);
        Assert.areEqual('webPortal', command.consumerKey);
        Assert.areEqual('contactDetails', command.stepKey);
    }

    private static ContinueApplicationHandler createHandler(RuleEngine ruleEngine) {
        return new ContinueApplicationHandler(
            new DefinitionResolver(),
            new ApplicationStateStore(),
            new ApplicationEventStore(),
            new SnapshotBuilder(),
            ruleEngine
        );
    }

    private static ContinueApplicationCommand createCommand(Id applicationId, String stepKey) {
        ContinueApplicationCommand command = new ContinueApplicationCommand();
        command.applicationId = String.valueOf(applicationId);
        command.consumerKey = 'webPortal';
        command.stepKey = stepKey;
        return command;
    }

    private static Application__c createApplication() {
        InitApplicationCommand command = new InitApplicationCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.scenarioKey = 'newCustomer';
        command.externalReference = 'continue-' + String.valueOf(Crypto.getRandomInteger());
        Id applicationId = (Id) new InitApplicationHandler().execute(command).snapshot.application.id;
        return getApplication(applicationId);
    }

    private static Application__c getApplication(Id applicationId) {
        return [
            SELECT Id, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Consumer_Key__c, Status__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];
    }

    private static Application_Job__c createJob(Id applicationId, String status) {
        return new Application_Job__c(
            Application__c = applicationId,
            Job_Key__c = 'contactDetails___emailValidation',
            Job_Name__c = 'emailValidation',
            Source_Step_Key__c = 'contactDetails',
            Status__c = status,
            Execution_Mode__c = FrameworkConstants.JOB_EXECUTION_MODE_SYNC,
            Can_Be_Restarted__c = true
        );
    }

    private static Integer countEvents(Id applicationId, String eventType) {
        return [
            SELECT COUNT()
            FROM Application_Event__c
            WHERE Application__c = :applicationId
            AND Event_Type__c = :eventType
        ];
    }

    private static RestRequest createContinueRequest(Id applicationId, String stepKey) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/continue';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(
            '{"applicationId":"' + String.valueOf(applicationId) + '","consumerKey":"webPortal","stepKey":"' + stepKey + '"}'
        );
        return request;
    }

    private class RequiredJobRuleEngine extends RuleEngine {
        public override RuleResult evaluateStepTransitionRules(StepRuntimeContext context) {
            for (Application_Job__c job : context.jobs) {
                if (job.Job_Key__c == 'contactDetails___emailValidation' && job.Status__c == FrameworkConstants.JOB_STATUS_COMPLETED) {
                    return RuleResult.allow();
                }
            }
            return RuleResult.block(
                'WAITING_FOR_JOBS',
                'Required Job is not completed. Job: contactDetails___emailValidation'
            );
        }
    }
}
