public class StepRuntimeContext {
    public Application__c application;
    public ProcessDefinition definition;
    public ProcessDefinition.ScenarioDefinition scenario;
    public SubmitStepCommand command;
    public String currentStepKey;
    public String nextStepKey;
    public Map<String, Object> submittedData;
    public List<Application_Stop_Process__c> activeStopProcesses = new List<Application_Stop_Process__c>();
    public List<Application_Job__c> jobs = new List<Application_Job__c>();

    public StepRuntimeContext(
        Application__c application,
        ProcessDefinition definition,
        ProcessDefinition.ScenarioDefinition scenario,
        SubmitStepCommand command,
        String nextStepKey
    ) {
        this(application, definition, scenario, command, nextStepKey, new List<Application_Stop_Process__c>());
    }

    public StepRuntimeContext(
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

    public void setJobs(List<Application_Job__c> jobs) {
        this.jobs = jobs == null ? new List<Application_Job__c>() : jobs;
    }
}
