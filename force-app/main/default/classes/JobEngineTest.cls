@IsTest
private class JobEngineTest {
    @IsTest
    static void createsQueuedJobsFromStepJobTriggerRules() {
        StepRuntimeContext context = createContext(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"jobTriggerRules":["runEmailValidation"]},"finish":{"type":"finish"}},"rules":{"runEmailValidation":{"type":"jobTrigger","jobKey":"emailValidation"}},"jobs":{"emailValidation":{"label":"Email Validation","executionMode":"syncCallout","canBeRestarted":true}}}'
        );

        List<Application_Job__c> jobs = new JobEngine().createJobsForStepSubmit(context);

        Assert.areEqual(1, jobs.size());
        Assert.areEqual('contactDetails___emailValidation', jobs[0].Job_Key__c);
        Assert.areEqual('emailValidation', jobs[0].Job_Name__c);
        Assert.areEqual('contactDetails', jobs[0].Source_Step_Key__c);
        Assert.areEqual(FrameworkConstants.JOB_STATUS_QUEUED, jobs[0].Status__c);
        Assert.areEqual('syncCallout', jobs[0].Execution_Mode__c);
        Assert.areEqual(true, jobs[0].Can_Be_Restarted__c);
    }

    @IsTest
    static void defaultsExecutionModeToSync() {
        StepRuntimeContext context = createContext(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"jobTriggerRules":["runEmailValidation"]},"finish":{"type":"finish"}},"rules":{"runEmailValidation":{"type":"jobTrigger","jobKey":"emailValidation"}},"jobs":{"emailValidation":{"label":"Email Validation"}}}'
        );

        List<Application_Job__c> jobs = new JobEngine().createJobsForStepSubmit(context);

        Assert.areEqual(FrameworkConstants.JOB_EXECUTION_MODE_SYNC, jobs[0].Execution_Mode__c);
    }

    @IsTest
    static void missingJobDefinitionFailsClearly() {
        StepRuntimeContext context = createContext(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"jobTriggerRules":["runEmailValidation"]},"finish":{"type":"finish"}},"rules":{"runEmailValidation":{"type":"jobTrigger","jobKey":"emailValidation"}},"jobs":{}}'
        );

        try {
            new JobEngine().createJobsForStepSubmit(context);
            Assert.fail('Expected missing job definition to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Job definition'));
        }
    }

    @IsTest
    static void saveJobsReusesExistingRuntimeJobKey() {
        Application__c application = createApplication();
        ApplicationStateStore store = new ApplicationStateStore();
        Application_Job__c job = createJob(application.Id);

        store.saveJobs(new List<Application_Job__c>{ job });
        store.saveJobs(new List<Application_Job__c>{ createJob(application.Id) });

        Integer jobCount = [
            SELECT COUNT()
            FROM Application_Job__c
            WHERE Application__c = :application.Id
            AND Job_Key__c = 'contactDetails___emailValidation'
        ];
        Assert.areEqual(1, jobCount);
    }

    @IsTest
    static void runsDefaultJobExecutor() {
        StepRuntimeContext context = createContext(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{},"finish":{"type":"finish"}},"rules":{},"jobs":{"emailValidation":{"label":"Email Validation"}}}'
        );
        Application_Job__c job = createJob(context.application.Id);

        JobExecutionResult result = new JobEngine().runJob(job, context.definition);

        Assert.areEqual(true, result.success);
    }

    @IsTest
    static void missingExecutorClassFailsClearly() {
        StepRuntimeContext context = createContext(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{},"finish":{"type":"finish"}},"rules":{},"jobs":{"emailValidation":{"label":"Email Validation","executorClass":"MissingJobExecutorClass"}}}'
        );
        Application_Job__c job = createJob(context.application.Id);

        try {
            new JobEngine().runJob(job, context.definition);
            Assert.fail('Expected missing executor class to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Job Executor class'));
        }
    }

    private static StepRuntimeContext createContext(String definitionJson) {
        Application__c application = createApplication();
        ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario('newCustomer');

        SubmitStepCommand command = new SubmitStepCommand();
        command.applicationId = String.valueOf(application.Id);
        command.consumerKey = 'webPortal';
        command.stepKey = 'contactDetails';
        command.data = new Map<String, Object>();

        return new StepRuntimeContext(application, definition, scenario, command, 'finish');
    }

    private static Application__c createApplication() {
        InitApplicationCommand command = new InitApplicationCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.scenarioKey = 'newCustomer';
        command.externalReference = 'job-' + String.valueOf(Crypto.getRandomInteger());
        Id applicationId = (Id) new InitApplicationHandler().execute(command).snapshot.application.id;
        return [
            SELECT Id, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Consumer_Key__c, Status__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];
    }

    private static Application_Job__c createJob(Id applicationId) {
        return new Application_Job__c(
            Application__c = applicationId,
            Job_Key__c = 'contactDetails___emailValidation',
            Job_Name__c = 'emailValidation',
            Source_Step_Key__c = 'contactDetails',
            Status__c = FrameworkConstants.JOB_STATUS_QUEUED,
            Execution_Mode__c = FrameworkConstants.JOB_EXECUTION_MODE_SYNC,
            Can_Be_Restarted__c = true
        );
    }
}
