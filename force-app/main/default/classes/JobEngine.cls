public virtual class JobEngine {
    /********
     *
     * JobEngine owns creation of Application_Job__c runtime records.
     * Executing jobs is intentionally a separate command so SubmitStep can stay focused on state changes.
     *
     ********/
    public virtual List<Application_Job__c> createJobsForStepSubmit(StepRuntimeContext context) {
        List<Application_Job__c> jobsToCreate = new List<Application_Job__c>();
        for (String ruleKey : getStepRuleKeys(context, 'jobTriggerRules')) {
            Map<String, Object> ruleDefinition = getRuleDefinition(context.definition, ruleKey);
            String jobName = getString(ruleDefinition, 'jobKey');
            if (String.isBlank(jobName)) {
                throw new FrameworkException('Job Trigger Rule must define jobKey. Rule: ' + ruleKey);
            }

            Map<String, Object> jobDefinition = getJobDefinition(context.definition, jobName);
            Application_Job__c job = new Application_Job__c();
            job.Application__c = context.application.Id;
            job.Job_Key__c = context.currentStepKey + '___' + jobName;
            job.Job_Name__c = jobName;
            job.Source_Step_Key__c = context.currentStepKey;
            job.Status__c = FrameworkConstants.JOB_STATUS_QUEUED;
            job.Execution_Mode__c = getStringOrDefault(jobDefinition, 'executionMode', FrameworkConstants.JOB_EXECUTION_MODE_SYNC);
            job.Can_Be_Restarted__c = getBoolean(jobDefinition, 'canBeRestarted');
            jobsToCreate.add(job);
        }
        return jobsToCreate;
    }

    public virtual JobExecutionResult runJob(Application_Job__c job, ProcessDefinition definition) {
        Map<String, Object> jobDefinition = getJobDefinition(definition, job.Job_Name__c);
        JobExecutor executor = createJobExecutor(jobDefinition);
        return executor.execute(job, jobDefinition);
    }

    private JobExecutor createJobExecutor(Map<String, Object> jobDefinition) {
        String className = getString(jobDefinition, 'executorClass');
        if (String.isBlank(className)) {
            return new DefaultJobExecutor();
        }

        Type executorType = Type.forName(className);
        if (executorType == null) {
            throw new FrameworkException('Job Executor class was not found. Class: ' + className);
        }

        Object executorInstance = executorType.newInstance();
        if (!(executorInstance instanceof JobExecutor)) {
            throw new FrameworkException('Job Executor class must implement JobExecutor. Class: ' + className);
        }
        return (JobExecutor) executorInstance;
    }

    private List<String> getStepRuleKeys(StepRuntimeContext context, String ruleListKey) {
        Map<String, Object> stepDefinition = getStepDefinition(context.definition, context.currentStepKey);
        Object rawRuleKeys = stepDefinition.get(ruleListKey);
        if (!(rawRuleKeys instanceof List<Object>)) {
            return new List<String>();
        }

        List<String> ruleKeys = new List<String>();
        for (Object rawRuleKey : (List<Object>) rawRuleKeys) {
            ruleKeys.add(String.valueOf(rawRuleKey));
        }
        return ruleKeys;
    }

    private Map<String, Object> getStepDefinition(ProcessDefinition definition, String stepKey) {
        Object rawStep = definition.steps.get(stepKey);
        return rawStep instanceof Map<String, Object>
            ? (Map<String, Object>) rawStep
            : new Map<String, Object>();
    }

    private Map<String, Object> getRuleDefinition(ProcessDefinition definition, String ruleKey) {
        Map<String, Object> rules = getObjectMap(definition.raw, 'rules');
        Object rawRule = rules.get(ruleKey);
        if (!(rawRule instanceof Map<String, Object>)) {
            throw new FrameworkException('Job Trigger Rule definition was not found. Rule: ' + ruleKey);
        }
        return (Map<String, Object>) rawRule;
    }

    private Map<String, Object> getJobDefinition(ProcessDefinition definition, String jobName) {
        Map<String, Object> jobs = getObjectMap(definition.raw, 'jobs');
        Object rawJob = jobs.get(jobName);
        if (!(rawJob instanceof Map<String, Object>)) {
            throw new FrameworkException('Job definition was not found. Job: ' + jobName);
        }
        return (Map<String, Object>) rawJob;
    }

    private Map<String, Object> getObjectMap(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value instanceof Map<String, Object>
            ? (Map<String, Object>) value
            : new Map<String, Object>();
    }

    private String getString(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value == null ? null : String.valueOf(value);
    }

    private String getStringOrDefault(Map<String, Object> source, String key, String defaultValue) {
        String value = getString(source, key);
        return String.isBlank(value) ? defaultValue : value;
    }

    private Boolean getBoolean(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value instanceof Boolean ? (Boolean) value : false;
    }
}
