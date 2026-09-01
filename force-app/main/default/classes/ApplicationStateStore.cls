public inherited sharing class ApplicationStateStore {
    public class InitResult {
        public Application__c application;
        public Boolean created;
    }

    public InitResult initApplication(InitApplicationCommand command, ProcessDefinition definition) {
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario(command.scenarioKey);
        if (scenario == null) {
            throw new FrameworkException('Scenario was not found. Scenario: ' + command.scenarioKey);
        }

        Application__c existingApplication = findExistingApplication(command);
        if (existingApplication != null) {
            return createResult(existingApplication, false);
        }

        Application__c application = new Application__c();
        application.Process_Key__c = command.processKey;
        application.Scenario_Key__c = command.scenarioKey;
        application.Current_Step_Key__c = scenario.initialStep;
        application.Status__c = FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS;
        application.Conversion_Status__c = FrameworkConstants.CONVERSION_STATUS_NOT_READY;
        application.Consumer_Key__c = command.consumerKey;
        application.External_Reference__c = command.externalReference;
        application.Definition_Version__c = definition.version;
        application.Started_At__c = System.now();
        insert application;

        return createResult(application, true);
    }

    public Application__c getApplication(Id applicationId) {
        if (applicationId == null) {
            throw new FrameworkException('Application id is required.');
        }

        List<Application__c> applications = [
            SELECT Id, Name, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Status__c,
                Conversion_Status__c, Consumer_Key__c, External_Reference__c, Definition_Version__c,
                Started_At__c, Completed_At__c, Converted_At__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        if (applications.isEmpty()) {
            throw new FrameworkException('Application was not found. Id: ' + String.valueOf(applicationId));
        }
        return applications[0];
    }

    public void submitStepData(Id applicationId, String stepKey, Map<String, Object> data) {
        if (applicationId == null || String.isBlank(stepKey) || data == null || data.isEmpty()) {
            return;
        }

        Map<String, Application_Data__c> existingDataByKey = new Map<String, Application_Data__c>();
        for (Application_Data__c dataRecord : [
            SELECT Id, Key__c
            FROM Application_Data__c
            WHERE Application__c = :applicationId
            AND Step_Key__c = :stepKey
            AND Key__c IN :data.keySet()
        ]) {
            existingDataByKey.put(dataRecord.Key__c, dataRecord);
        }

        List<Application_Data__c> recordsToSave = new List<Application_Data__c>();
        for (String key : data.keySet()) {
            Application_Data__c dataRecord = existingDataByKey.containsKey(key)
                ? existingDataByKey.get(key)
                : new Application_Data__c(Application__c = applicationId, Key__c = key, Step_Key__c = stepKey);
            assignValue(dataRecord, data.get(key));
            recordsToSave.add(dataRecord);
        }

        if (!recordsToSave.isEmpty()) {
            upsert recordsToSave;
        }
    }

    public List<Application_Data__c> getApplicationData(Id applicationId) {
        if (applicationId == null) {
            throw new FrameworkException('Application id is required.');
        }

        return [
            SELECT Key__c, Value__c, Value_JSON__c, Type__c, Step_Key__c
            FROM Application_Data__c
            WHERE Application__c = :applicationId
            ORDER BY Step_Key__c, Key__c
        ];
    }

    public List<Application_Stop_Process__c> getActiveStopProcesses(Id applicationId) {
        if (applicationId == null) {
            throw new FrameworkException('Application id is required.');
        }

        return [
            SELECT Code__c, Label__c, Type__c, Status__c, Message__c, Activated_At__c
            FROM Application_Stop_Process__c
            WHERE Application__c = :applicationId
            AND Status__c = :FrameworkConstants.STOP_PROCESS_STATUS_ACTIVE
            ORDER BY Code__c
        ];
    }

    public List<Application_Job__c> getApplicationJobs(Id applicationId) {
        if (applicationId == null) {
            throw new FrameworkException('Application id is required.');
        }

        return [
            SELECT Job_Key__c, Job_Name__c, Source_Step_Key__c, Status__c, Execution_Mode__c,
                Can_Be_Restarted__c, External_Job_Id__c, Error_Code__c, Error_Message__c
            FROM Application_Job__c
            WHERE Application__c = :applicationId
            ORDER BY Source_Step_Key__c, Job_Key__c
        ];
    }

    public Application_Job__c getApplicationJob(Id applicationId, String jobKey) {
        if (applicationId == null) {
            throw new FrameworkException('Application id is required.');
        }
        if (String.isBlank(jobKey)) {
            throw new FrameworkException('Job key is required.');
        }

        List<Application_Job__c> jobs = [
            SELECT Id, Application__c, Job_Key__c, Job_Name__c, Source_Step_Key__c, Status__c,
                Execution_Mode__c, Can_Be_Restarted__c, External_Job_Id__c, Error_Code__c, Error_Message__c
            FROM Application_Job__c
            WHERE Application__c = :applicationId
            AND Job_Key__c = :jobKey
            LIMIT 1
        ];

        if (jobs.isEmpty()) {
            throw new FrameworkException('Application Job was not found. Job: ' + jobKey);
        }
        return jobs[0];
    }

    public void saveJobs(List<Application_Job__c> jobs) {
        if (jobs == null || jobs.isEmpty()) {
            return;
        }

        Set<Id> applicationIds = new Set<Id>();
        Set<String> jobKeys = new Set<String>();
        for (Application_Job__c job : jobs) {
            if (job.Application__c != null && !String.isBlank(job.Job_Key__c)) {
                applicationIds.add(job.Application__c);
                jobKeys.add(job.Job_Key__c);
            }
        }

        Map<String, Application_Job__c> existingJobsByRuntimeKey = new Map<String, Application_Job__c>();
        if (!applicationIds.isEmpty() && !jobKeys.isEmpty()) {
            for (Application_Job__c existingJob : [
                SELECT Id, Application__c, Job_Key__c
                FROM Application_Job__c
                WHERE Application__c IN :applicationIds
                AND Job_Key__c IN :jobKeys
            ]) {
                existingJobsByRuntimeKey.put(createJobRuntimeKey(existingJob.Application__c, existingJob.Job_Key__c), existingJob);
            }
        }

        for (Application_Job__c job : jobs) {
            String runtimeKey = createJobRuntimeKey(job.Application__c, job.Job_Key__c);
            if (existingJobsByRuntimeKey.containsKey(runtimeKey)) {
                job.Id = existingJobsByRuntimeKey.get(runtimeKey).Id;
            }
        }
        upsert jobs;
    }

    public void updateJobStatus(Application_Job__c job, String status, String errorCode, String errorMessage) {
        job.Status__c = status;
        job.Error_Code__c = errorCode;
        job.Error_Message__c = errorMessage;
        update job;
    }

    public void updateApplicationStep(Application__c application, String nextStepKey, Boolean completed) {
        application.Current_Step_Key__c = nextStepKey;
        if (completed) {
            application.Status__c = FrameworkConstants.APPLICATION_STATUS_COMPLETED;
            application.Completed_At__c = System.now();
        }
        update application;
    }

    private InitResult createResult(Application__c application, Boolean created) {
        InitResult result = new InitResult();
        result.application = application;
        result.created = created;
        return result;
    }

    private Application__c findExistingApplication(InitApplicationCommand command) {
        if (String.isBlank(command.externalReference)) {
            return null;
        }

        List<Application__c> applications = [
            SELECT Id, Name, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Status__c,
                Conversion_Status__c, Consumer_Key__c, External_Reference__c, Definition_Version__c,
                Started_At__c, Completed_At__c, Converted_At__c
            FROM Application__c
            WHERE Process_Key__c = :command.processKey
            AND Scenario_Key__c = :command.scenarioKey
            AND Consumer_Key__c = :command.consumerKey
            AND External_Reference__c = :command.externalReference
            LIMIT 1
        ];

        return applications.isEmpty() ? null : applications[0];
    }

    private String createJobRuntimeKey(Id applicationId, String jobKey) {
        return String.valueOf(applicationId) + '|' + jobKey;
    }

    private void assignValue(Application_Data__c dataRecord, Object value) {
        dataRecord.Value__c = null;
        dataRecord.Value_JSON__c = null;

        if (value == null) {
            dataRecord.Type__c = 'String';
            return;
        }
        if (value instanceof Boolean) {
            dataRecord.Type__c = 'Boolean';
            dataRecord.Value__c = String.valueOf(value);
            return;
        }
        if (value instanceof Decimal || value instanceof Integer || value instanceof Long || value instanceof Double) {
            dataRecord.Type__c = 'Number';
            dataRecord.Value__c = String.valueOf(value);
            return;
        }
        if (value instanceof Date || value instanceof Datetime) {
            dataRecord.Type__c = 'Date';
            dataRecord.Value__c = String.valueOf(value);
            return;
        }
        if (value instanceof Map<String, Object> || value instanceof List<Object>) {
            dataRecord.Type__c = 'Json';
            dataRecord.Value_JSON__c = JSON.serialize(value);
            return;
        }

        dataRecord.Type__c = 'String';
        dataRecord.Value__c = String.valueOf(value);
    }
}
