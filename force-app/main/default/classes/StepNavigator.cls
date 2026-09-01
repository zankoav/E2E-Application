public inherited sharing class StepNavigator {
    private RuleEngine ruleEngine;

    public StepNavigator() {
        this(new RuleEngine());
    }

    public StepNavigator(RuleEngine ruleEngine) {
        this.ruleEngine = ruleEngine == null ? new RuleEngine() : ruleEngine;
    }

    public String getNextTransitionCandidate(
        Application__c application,
        ProcessDefinition definition,
        ProcessDefinition.ScenarioDefinition scenario,
        String currentStepKey,
        List<Application_Stop_Process__c> activeStopProcesses,
        List<Application_Job__c> jobs
    ) {
        Integer currentIndex = scenario.steps.indexOf(currentStepKey);
        if (currentIndex < 0) {
            throw new FrameworkException('Current step is not part of Scenario. Step: ' + currentStepKey);
        }

        for (Integer stepIndex = currentIndex + 1; stepIndex < scenario.steps.size(); stepIndex++) {
            String candidateStepKey = scenario.steps[stepIndex];
            RuleResult availabilityResult = evaluateAvailability(
                application,
                definition,
                scenario,
                candidateStepKey,
                activeStopProcesses,
                jobs
            );
            if (!shouldSkip(availabilityResult)) {
                return candidateStepKey;
            }
        }
        return null;
    }

    public RuleResult evaluateAvailability(
        Application__c application,
        ProcessDefinition definition,
        ProcessDefinition.ScenarioDefinition scenario,
        String stepKey,
        List<Application_Stop_Process__c> activeStopProcesses,
        List<Application_Job__c> jobs
    ) {
        SubmitStepCommand command = new SubmitStepCommand();
        command.applicationId = String.valueOf(application.Id);
        command.consumerKey = application.Consumer_Key__c;
        command.stepKey = stepKey;
        command.data = new Map<String, Object>();

        StepRuntimeContext context = new StepRuntimeContext(
            application,
            definition,
            scenario,
            command,
            stepKey,
            activeStopProcesses
        );
        context.setJobs(jobs);
        return ruleEngine.evaluateStepAvailability(context);
    }

    private Boolean shouldSkip(RuleResult availabilityResult) {
        if (availabilityResult == null || availabilityResult.allowed) {
            return false;
        }
        return availabilityResult.code == FrameworkConstants.STEP_UNAVAILABLE_HIDDEN ||
            availabilityResult.code == FrameworkConstants.STEP_UNAVAILABLE_SKIPPED;
    }
}
