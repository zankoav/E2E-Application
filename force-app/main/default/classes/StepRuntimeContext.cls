global class StepRuntimeContext {
    global Application__c application;
    global ProcessDefinition definition;
    global ProcessDefinition.ScenarioDefinition scenario;
    global SubmitStepCommand command;
    global String currentStepKey;
    global String nextStepKey;
    global Map<String, Object> submittedData;
    global List<Application_Stop_Process__c> activeStopProcesses = new List<Application_Stop_Process__c>();
    global List<Application_Job__c> jobs = new List<Application_Job__c>();

    global StepRuntimeContext(
        Application__c application,
        ProcessDefinition definition,
        ProcessDefinition.ScenarioDefinition scenario,
        SubmitStepCommand command,
        String nextStepKey
    ) {
        this(application, definition, scenario, command, nextStepKey, new List<Application_Stop_Process__c>());
    }

    global StepRuntimeContext(
        Application__c application,
        ProcessDefinition definition,
        ProcessDefinition.ScenarioDefinition scenario,
        SubmitStepCommand command,
        String nextStepKey,
        List<Application_Stop_Process__c> activeStopProcesses
    ) {
        this.application = application;
        this.definition = definition;
        this.scenario = scenario;
        this.command = command;
        this.currentStepKey = command.stepKey;
        this.nextStepKey = nextStepKey;
        this.submittedData = command.data;
        if (activeStopProcesses != null) {
            this.activeStopProcesses = activeStopProcesses;
        }
    }

    global void setJobs(List<Application_Job__c> jobs) {
        this.jobs = jobs == null ? new List<Application_Job__c>() : jobs;
    }
}
