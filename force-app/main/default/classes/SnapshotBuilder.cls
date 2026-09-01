public inherited sharing class SnapshotBuilder {
    private StepNavigator stepNavigator;

    public SnapshotBuilder() {
        this(new RuleEngine());
    }

    public SnapshotBuilder(RuleEngine ruleEngine) {
        this.stepNavigator = new StepNavigator(ruleEngine);
    }

    public ApplicationSnapshot build(Application__c application, ProcessDefinition definition) {
        return build(application, definition, new List<Application_Data__c>(), new List<Application_Stop_Process__c>(), new List<Application_Job__c>());
    }

    public ApplicationSnapshot build(Application__c application, ProcessDefinition definition, List<Application_Data__c> dataRecords) {
        return build(application, definition, dataRecords, new List<Application_Stop_Process__c>(), new List<Application_Job__c>());
    }

    public ApplicationSnapshot build(
        Application__c application,
        ProcessDefinition definition,
        List<Application_Data__c> dataRecords,
        List<Application_Stop_Process__c> stopProcesses
    ) {
        return build(application, definition, dataRecords, stopProcesses, new List<Application_Job__c>());
    }

    public ApplicationSnapshot build(
        Application__c application,
        ProcessDefinition definition,
        List<Application_Data__c> dataRecords,
        List<Application_Stop_Process__c> stopProcesses,
        List<Application_Job__c> jobs
    ) {
        if (application == null) {
            throw new FrameworkException('Application is required to build Snapshot.');
        }
        if (definition == null) {
            throw new FrameworkException('Process definition is required to build Snapshot.');
        }

        ApplicationSnapshot snapshot = new ApplicationSnapshot();
        snapshot.application = buildApplicationInfo(application);
        snapshot.steps = buildSteps(application, definition, stopProcesses, jobs);
        snapshot.data = buildData(dataRecords);
        snapshot.jobs = buildJobs(jobs, definition);
        snapshot.stopProcesses = buildStopProcesses(stopProcesses);
        snapshot.availableActions.add('GetSnapshot');
        snapshot.availableActions.add('SubmitStep');
        if (jobs != null && !jobs.isEmpty()) {
            snapshot.availableActions.add('RunJob');
            snapshot.availableActions.add('RestartJob');
            snapshot.availableActions.add('ContinueApplication');
        }
        return snapshot;
    }

    private ApplicationSnapshot.ApplicationInfo buildApplicationInfo(Application__c application) {
        ApplicationSnapshot.ApplicationInfo info = new ApplicationSnapshot.ApplicationInfo();
        info.id = String.valueOf(application.Id);
        info.name = application.Name;
        info.processKey = application.Process_Key__c;
        info.scenarioKey = application.Scenario_Key__c;
        info.status = application.Status__c;
        info.conversionStatus = application.Conversion_Status__c;
        info.currentStep = application.Current_Step_Key__c;
        info.consumerKey = application.Consumer_Key__c;
        info.externalReference = application.External_Reference__c;
        info.definitionVersion = application.Definition_Version__c;
        return info;
    }

    private List<ApplicationSnapshot.StepInfo> buildSteps(
        Application__c application,
        ProcessDefinition definition,
        List<Application_Stop_Process__c> stopProcesses,
        List<Application_Job__c> jobs
    ) {
        List<ApplicationSnapshot.StepInfo> steps = new List<ApplicationSnapshot.StepInfo>();
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario(application.Scenario_Key__c);
        if (scenario == null) {
            return steps;
        }

        Integer currentIndex = scenario.steps.indexOf(application.Current_Step_Key__c);
        String nextStepKey = stepNavigator.getNextTransitionCandidate(application, definition, scenario, application.Current_Step_Key__c, stopProcesses, jobs);
        for (String stepKey : scenario.steps) {
            ApplicationSnapshot.StepInfo stepInfo = new ApplicationSnapshot.StepInfo();
            stepInfo.key = stepKey;
            stepInfo.label = getStepLabel(definition, stepKey);
            assignStepAvailability(stepInfo, application, definition, scenario, stepKey, currentIndex, nextStepKey, stopProcesses, jobs);
            steps.add(stepInfo);
        }
        return steps;
    }

    private void assignStepAvailability(
        ApplicationSnapshot.StepInfo stepInfo,
        Application__c application,
        ProcessDefinition definition,
        ProcessDefinition.ScenarioDefinition scenario,
        String stepKey,
        Integer currentIndex,
        String nextStepKey,
        List<Application_Stop_Process__c> stopProcesses,
        List<Application_Job__c> jobs
    ) {
        if (stepKey == application.Current_Step_Key__c) {
            stepInfo.status = FrameworkConstants.STEP_STATUS_CURRENT;
            stepInfo.available = true;
            return;
        }

        Integer stepIndex = scenario.steps.indexOf(stepKey);
        if (currentIndex >= 0 && stepIndex >= 0 && stepIndex < currentIndex) {
            stepInfo.status = FrameworkConstants.STEP_STATUS_COMPLETED;
            stepInfo.available = true;
            return;
        }

        RuleResult availabilityResult = stepNavigator.evaluateAvailability(
            application,
            definition,
            scenario,
            stepKey,
            stopProcesses,
            jobs
        );
        if (!availabilityResult.allowed) {
            stepInfo.status = getUnavailableStepStatus(availabilityResult);
            stepInfo.available = false;
            stepInfo.unavailableReason = availabilityResult.message;
            return;
        }

        if (stepKey != nextStepKey) {
            stepInfo.status = FrameworkConstants.STEP_STATUS_LOCKED;
            stepInfo.available = false;
            stepInfo.unavailableReason = 'Complete previous steps first.';
            return;
        }

        if (availabilityResult.allowed) {
            stepInfo.status = FrameworkConstants.STEP_STATUS_AVAILABLE;
            stepInfo.available = true;
            return;
        }
    }

    private String getUnavailableStepStatus(RuleResult availabilityResult) {
        if (availabilityResult.code == FrameworkConstants.STEP_UNAVAILABLE_HIDDEN) {
            return FrameworkConstants.STEP_STATUS_HIDDEN;
        }
        if (availabilityResult.code == FrameworkConstants.STEP_UNAVAILABLE_SKIPPED) {
            return FrameworkConstants.STEP_STATUS_SKIPPED;
        }
        return FrameworkConstants.STEP_STATUS_LOCKED;
    }

    private Map<String, Object> buildData(List<Application_Data__c> dataRecords) {
        Map<String, Object> data = new Map<String, Object>();
        if (dataRecords == null) {
            return data;
        }

        for (Application_Data__c dataRecord : dataRecords) {
            data.put(dataRecord.Key__c, getDataValue(dataRecord));
        }
        return data;
    }

    private List<ApplicationSnapshot.JobInfo> buildJobs(List<Application_Job__c> jobs, ProcessDefinition definition) {
        List<ApplicationSnapshot.JobInfo> jobInfos = new List<ApplicationSnapshot.JobInfo>();
        if (jobs == null) {
            return jobInfos;
        }

        for (Application_Job__c job : jobs) {
            jobInfos.add(buildJobInfo(job, definition));
        }
        return jobInfos;
    }

    public ApplicationSnapshot.JobInfo buildJobInfo(Application_Job__c job, ProcessDefinition definition) {
        if (job == null) {
            throw new FrameworkException('Application Job is required to build JobInfo.');
        }
        if (definition == null) {
            throw new FrameworkException('Process definition is required to build JobInfo.');
        }

        ApplicationSnapshot.JobInfo jobInfo = new ApplicationSnapshot.JobInfo();
        jobInfo.key = job.Job_Key__c;
        jobInfo.name = job.Job_Name__c;
        jobInfo.label = getJobLabel(definition, job.Job_Name__c);
        jobInfo.sourceStepKey = job.Source_Step_Key__c;
        jobInfo.status = job.Status__c;
        jobInfo.executionMode = job.Execution_Mode__c;
        jobInfo.canBeRestarted = job.Can_Be_Restarted__c;
        jobInfo.errorCode = job.Error_Code__c;
        jobInfo.errorMessage = job.Error_Message__c;
        jobInfo.availableActions = buildJobActions(job);
        return jobInfo;
    }

    private List<String> buildJobActions(Application_Job__c job) {
        List<String> actions = new List<String>();
        if (canRunJob(job)) {
            actions.add('RunJob');
        }
        if (canRestartJob(job)) {
            actions.add('RestartJob');
        }
        return actions;
    }

    private Boolean canRunJob(Application_Job__c job) {
        if (job.Status__c == FrameworkConstants.JOB_STATUS_QUEUED || job.Status__c == FrameworkConstants.JOB_STATUS_RESTART) {
            return true;
        }
        if (job.Status__c == FrameworkConstants.JOB_STATUS_FAILED && job.Can_Be_Restarted__c) {
            return true;
        }
        return getExecutionMode(job) == FrameworkConstants.JOB_EXECUTION_MODE_SYNC_CALLOUT &&
            job.Status__c == FrameworkConstants.JOB_STATUS_PREPARING;
    }

    private Boolean canRestartJob(Application_Job__c job) {
        if (!job.Can_Be_Restarted__c) {
            return false;
        }
        return job.Status__c == FrameworkConstants.JOB_STATUS_FAILED ||
            job.Status__c == FrameworkConstants.JOB_STATUS_PROCESSING ||
            job.Status__c == FrameworkConstants.JOB_STATUS_PREPARING;
    }

    private String getExecutionMode(Application_Job__c job) {
        return String.isBlank(job.Execution_Mode__c)
            ? FrameworkConstants.JOB_EXECUTION_MODE_SYNC
            : job.Execution_Mode__c;
    }

    private List<ApplicationSnapshot.StopProcessInfo> buildStopProcesses(List<Application_Stop_Process__c> stopProcesses) {
        List<ApplicationSnapshot.StopProcessInfo> stopProcessInfos = new List<ApplicationSnapshot.StopProcessInfo>();
        if (stopProcesses == null) {
            return stopProcessInfos;
        }

        for (Application_Stop_Process__c stopProcess : stopProcesses) {
            ApplicationSnapshot.StopProcessInfo stopProcessInfo = new ApplicationSnapshot.StopProcessInfo();
            stopProcessInfo.code = stopProcess.Code__c;
            stopProcessInfo.label = stopProcess.Label__c;
            stopProcessInfo.type = stopProcess.Type__c;
            stopProcessInfo.status = stopProcess.Status__c;
            stopProcessInfo.message = stopProcess.Message__c;
            stopProcessInfos.add(stopProcessInfo);
        }
        return stopProcessInfos;
    }

    private Object getDataValue(Application_Data__c dataRecord) {
        if (dataRecord.Type__c == 'Json') {
            return String.isBlank(dataRecord.Value_JSON__c)
                ? null
                : JSON.deserializeUntyped(dataRecord.Value_JSON__c);
        }
        if (dataRecord.Type__c == 'Boolean') {
            return dataRecord.Value__c == 'true';
        }
        if (dataRecord.Type__c == 'Number') {
            return String.isBlank(dataRecord.Value__c)
                ? null
                : Decimal.valueOf(dataRecord.Value__c);
        }
        return dataRecord.Value__c;
    }

    private String getJobLabel(ProcessDefinition definition, String jobName) {
        Map<String, Object> jobs = getObjectMap(definition.raw, 'jobs');
        Object rawJob = jobs.get(jobName);
        if (rawJob instanceof Map<String, Object>) {
            Object label = ((Map<String, Object>) rawJob).get('label');
            if (label != null) {
                return String.valueOf(label);
            }
        }
        return jobName;
    }

    private String getStepLabel(ProcessDefinition definition, String stepKey) {
        Object rawStep = definition.steps.get(stepKey);
        if (rawStep instanceof Map<String, Object>) {
            Object label = ((Map<String, Object>) rawStep).get('label');
            if (label != null) {
                return String.valueOf(label);
            }
        }
        return stepKey;
    }

    private Map<String, Object> getObjectMap(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value instanceof Map<String, Object>
            ? (Map<String, Object>) value
            : new Map<String, Object>();
    }
}
