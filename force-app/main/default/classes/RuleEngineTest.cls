@IsTest
private class RuleEngineTest {
    @IsTest
    static void defaultRulesAllowValidationAndTransition() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"label":"Contact Details","validationRules":["contactDataAccepted"],"transitionRules":["contactCanMoveNext"]},"finish":{"label":"Finish","type":"finish"}},"rules":{"contactDataAccepted":{"type":"validation"},"contactCanMoveNext":{"type":"stepTransition"}}}';
        ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario('newCustomer');

        SubmitStepCommand command = new SubmitStepCommand();
        command.stepKey = 'contactDetails';
        command.data = new Map<String, Object>{ 'firstName' => 'Alex' };

        Application__c application = new Application__c(
            Process_Key__c = 'fuelCardApplication',
            Scenario_Key__c = 'newCustomer',
            Current_Step_Key__c = 'contactDetails',
            Consumer_Key__c = 'webPortal',
            Status__c = FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS
        );
        StepRuntimeContext context = new StepRuntimeContext(application, definition, scenario, command, 'finish');

        RuleEngine engine = new RuleEngine();

        Assert.areEqual(true, engine.evaluateValidationRules(context).allowed);
        Assert.areEqual(true, engine.evaluateStepTransitionRules(context).allowed);
    }

    @IsTest
    static void defaultStepAvailabilityRuleAllowsStep() {
        StepRuntimeContext context = createContextWithDefinition(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"availabilityRules":["contactCanBeShown"]},"finish":{"type":"finish"}},"rules":{"contactCanBeShown":{"type":"stepAvailability"}}}'
        );

        RuleResult result = new RuleEngine().evaluateStepAvailability(context);

        Assert.areEqual(true, result.allowed);
    }

    @IsTest
    static void missingRuleDefinitionFailsClearly() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"label":"Contact Details","validationRules":["missingRule"]},"finish":{"label":"Finish","type":"finish"}},"rules":{}}';
        ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario('newCustomer');

        SubmitStepCommand command = new SubmitStepCommand();
        command.stepKey = 'contactDetails';
        command.data = new Map<String, Object>();

        Application__c application = new Application__c(Current_Step_Key__c = 'contactDetails');
        StepRuntimeContext context = new StepRuntimeContext(application, definition, scenario, command, 'finish');

        try {
            new RuleEngine().evaluateValidationRules(context);
            Assert.fail('Expected missing rule definition to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Rule definition'));
        }
    }

    @IsTest
    static void missingValidationRuleClassFailsClearly() {
        StepRuntimeContext context = createContextWithDefinition(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"validationRules":["customValidation"]},"finish":{"type":"finish"}},"rules":{"customValidation":{"type":"validation","class":"MissingValidationRuleClass"}}}'
        );

        try {
            new RuleEngine().evaluateValidationRules(context);
            Assert.fail('Expected missing validation rule class to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Validation Rule class'));
        }
    }

    @IsTest
    static void missingTransitionRuleClassFailsClearly() {
        StepRuntimeContext context = createContextWithDefinition(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"transitionRules":["customTransition"]},"finish":{"type":"finish"}},"rules":{"customTransition":{"type":"stepTransition","class":"MissingTransitionRuleClass"}}}'
        );

        try {
            new RuleEngine().evaluateStepTransitionRules(context);
            Assert.fail('Expected missing step transition rule class to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Step Transition Rule class'));
        }
    }

    @IsTest
    static void allowedStopProcessDoesNotBlockTransition() {
        StepRuntimeContext context = createContextWithDefinition(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"allowedStopProcesses":["DUPLICATE_CUSTOMER"]},"finish":{"type":"finish"}},"rules":{}}'
        );
        context.activeStopProcesses.add(new Application_Stop_Process__c(Code__c = 'DUPLICATE_CUSTOMER'));

        RuleResult result = new RuleEngine().evaluateStepTransitionRules(context);

        Assert.areEqual(true, result.allowed);
    }

    @IsTest
    static void activeStopProcessBlocksTransitionWhenNotAllowed() {
        StepRuntimeContext context = createContextWithDefinition(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{},"finish":{"type":"finish"}},"rules":{}}'
        );
        context.activeStopProcesses.add(new Application_Stop_Process__c(Code__c = 'DUPLICATE_CUSTOMER'));

        RuleResult result = new RuleEngine().evaluateStepTransitionRules(context);

        Assert.areEqual(false, result.allowed);
        Assert.areEqual('STOP_PROCESS_BLOCKED', result.code);
    }

    @IsTest
    static void requiredQueuedJobBlocksTransition() {
        StepRuntimeContext context = createContextWithDefinition(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"transitionRules":["contactCanMoveNext"]},"finish":{"type":"finish"}},"rules":{"contactCanMoveNext":{"type":"stepTransition","requiresJobs":[{"jobKey":"emailValidation","status":"Completed"}]}}}'
        );
        context.setJobs(new List<Application_Job__c>{
            new Application_Job__c(
                Job_Key__c = 'contactDetails___emailValidation',
                Job_Name__c = 'emailValidation',
                Status__c = FrameworkConstants.JOB_STATUS_QUEUED
            )
        });

        RuleResult result = new RuleEngine().evaluateStepTransitionRules(context);

        Assert.areEqual(false, result.allowed);
        Assert.areEqual('WAITING_FOR_JOBS', result.code);
    }

    @IsTest
    static void requiredCompletedJobAllowsTransition() {
        StepRuntimeContext context = createContextWithDefinition(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"transitionRules":["contactCanMoveNext"]},"finish":{"type":"finish"}},"rules":{"contactCanMoveNext":{"type":"stepTransition","requiresJobs":[{"jobKey":"emailValidation","status":"Completed"}]}}}'
        );
        context.setJobs(new List<Application_Job__c>{
            new Application_Job__c(
                Job_Key__c = 'contactDetails___emailValidation',
                Job_Name__c = 'emailValidation',
                Status__c = FrameworkConstants.JOB_STATUS_COMPLETED
            )
        });

        RuleResult result = new RuleEngine().evaluateStepTransitionRules(context);

        Assert.areEqual(true, result.allowed);
    }

    private static StepRuntimeContext createContextWithDefinition(String definitionJson) {
        ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario('newCustomer');

        SubmitStepCommand command = new SubmitStepCommand();
        command.stepKey = 'contactDetails';
        command.data = new Map<String, Object>();

        Application__c application = new Application__c(Current_Step_Key__c = 'contactDetails');
        return new StepRuntimeContext(application, definition, scenario, command, 'finish');
    }
}
