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
