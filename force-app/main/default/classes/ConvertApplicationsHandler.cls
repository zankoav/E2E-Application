public inherited sharing class ConvertApplicationsHandler {
    private DefinitionResolver definitionResolver;
    private ApplicationStateStore stateStore;
    private ApplicationEventStore eventStore;
    private ConsumerAccessService consumerAccessService;
    private MappingEngine mappingEngine;

    public ConvertApplicationsHandler() {
        this(
            new DefinitionResolver(),
            new ApplicationStateStore(),
            new ApplicationEventStore(),
            new ConsumerAccessService(),
            new MappingEngine()
        );
    }

    @TestVisible
    private ConvertApplicationsHandler(
        DefinitionResolver definitionResolver,
        ApplicationStateStore stateStore,
        ApplicationEventStore eventStore,
        ConsumerAccessService consumerAccessService,
        MappingEngine mappingEngine
    ) {
        this.definitionResolver = definitionResolver;
        this.stateStore = stateStore;
        this.eventStore = eventStore;
        this.consumerAccessService = consumerAccessService;
        this.mappingEngine = mappingEngine;
    }

    public CommandResult execute(ConvertApplicationsCommand command) {
        validateCommand(command);
        consumerAccessService.validateProcessAccess(command.consumerKey, command.processKey);

        ProcessDefinition definition = definitionResolver.resolveActive(command.processKey);
        List<Application__c> applications = stateStore.getApplicationsForConversion(command);
        ConversionResult result = new ConversionResult();
        result.requestedCount = applications.size();
        if (applications.isEmpty()) {
            return CommandResult.ok(result);
        }

        stateStore.markApplicationsConverting(applications);
        createEvents(applications, FrameworkConstants.EVENT_CONVERSION_STARTED, 'Conversion started.');

        try {
            convertApplications(applications, definition, result);
        } catch (Exception ex) {
            stateStore.markApplicationsConversionFailed(applications);
            createEvents(applications, FrameworkConstants.EVENT_CONVERSION_FAILED, ex.getMessage());
            result.failedCount = applications.size();
            result.errors.add(ex.getMessage());
            for (Application__c application : applications) {
                result.failedApplicationIds.add(String.valueOf(application.Id));
            }
        }

        return CommandResult.ok(result);
    }

    private void convertApplications(List<Application__c> applications, ProcessDefinition definition, ConversionResult result) {
        Set<Id> applicationIds = new Set<Id>();
        for (Application__c application : applications) {
            applicationIds.add(application.Id);
        }

        List<MappingRecord> mappingRecords = mappingEngine.buildRecords(
            applications,
            definition,
            stateStore.getApplicationDataByApplicationId(applicationIds)
        );

        Map<String, Application_Record_Link__c> existingLinksByRuntimeKey = stateStore.getRecordLinksByRuntimeKey(applicationIds);
        Map<Id, List<String>> errorsByApplicationId = saveMappedRecords(mappingRecords, existingLinksByRuntimeKey);

        List<Application_Record_Link__c> links = new List<Application_Record_Link__c>();
        for (MappingRecord mappingRecord : mappingRecords) {
            if (mappingRecord.record.Id == null) {
                continue;
            }
            if (existingLinksByRuntimeKey.containsKey(createRecordLinkRuntimeKey(mappingRecord))) {
                continue;
            }
            links.add(new Application_Record_Link__c(
                Application__c = mappingRecord.applicationId,
                Conversion_Key__c = mappingRecord.mappingKey,
                Role__c = mappingRecord.role,
                SObject_Type__c = mappingRecord.targetObject,
                Record_Id__c = String.valueOf(mappingRecord.record.Id)
            ));
        }
        stateStore.saveRecordLinks(links);

        List<Application__c> convertedApplications = new List<Application__c>();
        List<Application__c> failedApplications = new List<Application__c>();
        for (Application__c application : applications) {
            if (errorsByApplicationId.containsKey(application.Id)) {
                failedApplications.add(application);
                result.failedApplicationIds.add(String.valueOf(application.Id));
                result.errors.addAll(errorsByApplicationId.get(application.Id));
            } else {
                convertedApplications.add(application);
                result.convertedApplicationIds.add(String.valueOf(application.Id));
            }
        }

        result.convertedCount = convertedApplications.size();
        result.failedCount = failedApplications.size();
        stateStore.markApplicationsConverted(convertedApplications);
        createEvents(convertedApplications, FrameworkConstants.EVENT_CONVERSION_COMPLETED, 'Conversion completed.');
        stateStore.markApplicationsConversionFailed(failedApplications);
        createEvents(failedApplications, FrameworkConstants.EVENT_CONVERSION_FAILED, 'Conversion failed.');
    }

    private Map<Id, List<String>> saveMappedRecords(
        List<MappingRecord> mappingRecords,
        Map<String, Application_Record_Link__c> existingLinksByRuntimeKey
    ) {
        List<MappingRecord> recordsToInsert = new List<MappingRecord>();
        List<MappingRecord> recordsToUpdate = new List<MappingRecord>();
        Map<String, Map<String, Id>> existingRecordIdsByGroup = findExistingRecordIds(mappingRecords);
        Map<String, Id> savedRecordIdsByRuntimeKey = getExistingRecordIdsByRuntimeKey(existingLinksByRuntimeKey);
        Map<Id, List<String>> errorsByApplicationId = new Map<Id, List<String>>();

        for (List<MappingRecord> mappingBatch : getMappingBatches(mappingRecords)) {
            recordsToInsert.clear();
            recordsToUpdate.clear();

            for (MappingRecord mappingRecord : mappingBatch) {
                if (errorsByApplicationId.containsKey(mappingRecord.applicationId)) {
                    continue;
                }
                if (!assignRecordReferences(mappingRecord, savedRecordIdsByRuntimeKey, errorsByApplicationId)) {
                    continue;
                }

                Application_Record_Link__c existingLink = existingLinksByRuntimeKey.get(createRecordLinkRuntimeKey(mappingRecord));
                if (existingLink != null) {
                    mappingRecord.record.put('Id', (Id) existingLink.Record_Id__c);
                    recordsToUpdate.add(mappingRecord);
                } else if (mappingRecord.operation == 'upsert') {
                    Id existingRecordId = getExistingRecordId(mappingRecord, existingRecordIdsByGroup);
                    if (existingRecordId == null) {
                        recordsToInsert.add(mappingRecord);
                    } else {
                        mappingRecord.record.put('Id', existingRecordId);
                        recordsToUpdate.add(mappingRecord);
                    }
                } else {
                    recordsToInsert.add(mappingRecord);
                }
            }

            saveInsertRecords(recordsToInsert, errorsByApplicationId);
            saveUpdateRecords(recordsToUpdate, errorsByApplicationId);
            addSavedRecordIds(mappingBatch, errorsByApplicationId, savedRecordIdsByRuntimeKey);
        }

        return errorsByApplicationId;
    }

    private String createRecordLinkRuntimeKey(MappingRecord mappingRecord) {
        return String.valueOf(mappingRecord.applicationId) + '|' + mappingRecord.mappingKey;
    }

    private String createRecordLinkRuntimeKey(Id applicationId, String mappingKey) {
        return String.valueOf(applicationId) + '|' + mappingKey;
    }

    private Map<String, Id> getExistingRecordIdsByRuntimeKey(Map<String, Application_Record_Link__c> existingLinksByRuntimeKey) {
        Map<String, Id> recordIdsByRuntimeKey = new Map<String, Id>();
        for (String runtimeKey : existingLinksByRuntimeKey.keySet()) {
            recordIdsByRuntimeKey.put(runtimeKey, (Id) existingLinksByRuntimeKey.get(runtimeKey).Record_Id__c);
        }
        return recordIdsByRuntimeKey;
    }

    private List<List<MappingRecord>> getMappingBatches(List<MappingRecord> mappingRecords) {
        List<List<MappingRecord>> batches = new List<List<MappingRecord>>();
        Map<String, List<MappingRecord>> recordsByMappingKey = new Map<String, List<MappingRecord>>();
        Set<String> remainingMappingKeys = new Set<String>();
        Set<String> completedMappingKeys = new Set<String>();

        for (MappingRecord mappingRecord : mappingRecords) {
            if (!recordsByMappingKey.containsKey(mappingRecord.mappingKey)) {
                recordsByMappingKey.put(mappingRecord.mappingKey, new List<MappingRecord>());
                remainingMappingKeys.add(mappingRecord.mappingKey);
            }
            recordsByMappingKey.get(mappingRecord.mappingKey).add(mappingRecord);
        }

        while (!remainingMappingKeys.isEmpty()) {
            List<MappingRecord> batch = new List<MappingRecord>();
            Set<String> batchMappingKeys = new Set<String>();
            for (String mappingKey : new List<String>(remainingMappingKeys)) {
                List<String> dependencies = recordsByMappingKey.get(mappingKey)[0].dependsOn;
                if (containsAll(completedMappingKeys, dependencies)) {
                    batch.addAll(recordsByMappingKey.get(mappingKey));
                    batchMappingKeys.add(mappingKey);
                }
            }

            if (batch.isEmpty()) {
                throw new FrameworkException('Mapping dependencies contain a cycle or missing dependency.');
            }

            batches.add(batch);
            remainingMappingKeys.removeAll(batchMappingKeys);
            completedMappingKeys.addAll(batchMappingKeys);
        }

        return batches;
    }

    private Boolean containsAll(Set<String> source, List<String> values) {
        for (String value : values) {
            if (!source.contains(value)) {
                return false;
            }
        }
        return true;
    }

    private Boolean assignRecordReferences(
        MappingRecord mappingRecord,
        Map<String, Id> savedRecordIdsByRuntimeKey,
        Map<Id, List<String>> errorsByApplicationId
    ) {
        for (String targetField : mappingRecord.recordReferenceFields.keySet()) {
            String sourceMappingKey = mappingRecord.recordReferenceFields.get(targetField);
            Id sourceRecordId = savedRecordIdsByRuntimeKey.get(createRecordLinkRuntimeKey(mappingRecord.applicationId, sourceMappingKey));
            if (sourceRecordId == null) {
                addConversionError(
                    errorsByApplicationId,
                    mappingRecord.applicationId,
                    mappingRecord.mappingKey + ': missing dependency record. Dependency: ' + sourceMappingKey
                );
                return false;
            }
            mappingRecord.record.put(targetField, sourceRecordId);
        }
        return true;
    }

    private void addSavedRecordIds(
        List<MappingRecord> mappingRecords,
        Map<Id, List<String>> errorsByApplicationId,
        Map<String, Id> savedRecordIdsByRuntimeKey
    ) {
        for (MappingRecord mappingRecord : mappingRecords) {
            if (errorsByApplicationId.containsKey(mappingRecord.applicationId) || mappingRecord.record.Id == null) {
                continue;
            }
            savedRecordIdsByRuntimeKey.put(createRecordLinkRuntimeKey(mappingRecord), mappingRecord.record.Id);
        }
    }

    private void saveInsertRecords(List<MappingRecord> mappingRecords, Map<Id, List<String>> errorsByApplicationId) {
        List<SObject> records = getSObjects(mappingRecords);
        if (records.isEmpty()) {
            return;
        }

        Database.SaveResult[] saveResults = Database.insert(records, false);
        collectSaveErrors(mappingRecords, saveResults, errorsByApplicationId);
    }

    private void saveUpdateRecords(List<MappingRecord> mappingRecords, Map<Id, List<String>> errorsByApplicationId) {
        List<SObject> records = getSObjects(mappingRecords);
        if (records.isEmpty()) {
            return;
        }

        Database.SaveResult[] saveResults = Database.update(records, false);
        collectSaveErrors(mappingRecords, saveResults, errorsByApplicationId);
    }

    private List<SObject> getSObjects(List<MappingRecord> mappingRecords) {
        List<SObject> records = new List<SObject>();
        for (MappingRecord mappingRecord : mappingRecords) {
            records.add(mappingRecord.record);
        }
        return records;
    }

    private void collectSaveErrors(
        List<MappingRecord> mappingRecords,
        Database.SaveResult[] saveResults,
        Map<Id, List<String>> errorsByApplicationId
    ) {
        for (Integer index = 0; index < saveResults.size(); index++) {
            Database.SaveResult saveResult = saveResults[index];
            if (saveResult.isSuccess()) {
                if (saveResult.getId() != null) {
                    mappingRecords[index].record.put('Id', saveResult.getId());
                }
                continue;
            }

            MappingRecord mappingRecord = mappingRecords[index];
            for (Database.Error error : saveResult.getErrors()) {
                addConversionError(
                    errorsByApplicationId,
                    mappingRecord.applicationId,
                    mappingRecord.mappingKey + ': ' + error.getMessage()
                );
            }
        }
    }

    private void addConversionError(Map<Id, List<String>> errorsByApplicationId, Id applicationId, String message) {
        if (!errorsByApplicationId.containsKey(applicationId)) {
            errorsByApplicationId.put(applicationId, new List<String>());
        }
        errorsByApplicationId.get(applicationId).add(message);
    }

    private Map<String, Map<String, Id>> findExistingRecordIds(List<MappingRecord> mappingRecords) {
        Map<String, Set<String>> matchValuesByGroup = new Map<String, Set<String>>();
        Map<String, MappingRecord> sampleRecordByGroup = new Map<String, MappingRecord>();

        for (MappingRecord mappingRecord : mappingRecords) {
            if (mappingRecord.operation != 'upsert') {
                continue;
            }

            Object matchValue = mappingRecord.record.get(mappingRecord.matchField);
            if (matchValue == null) {
                continue;
            }

            String groupKey = getMatchGroupKey(mappingRecord);
            if (!matchValuesByGroup.containsKey(groupKey)) {
                matchValuesByGroup.put(groupKey, new Set<String>());
                sampleRecordByGroup.put(groupKey, mappingRecord);
            }
            matchValuesByGroup.get(groupKey).add(String.valueOf(matchValue));
        }

        Map<String, Map<String, Id>> existingRecordIdsByGroup = new Map<String, Map<String, Id>>();
        for (String groupKey : matchValuesByGroup.keySet()) {
            MappingRecord sampleRecord = sampleRecordByGroup.get(groupKey);
            existingRecordIdsByGroup.put(
                groupKey,
                queryExistingRecordIds(sampleRecord, matchValuesByGroup.get(groupKey))
            );
        }
        return existingRecordIdsByGroup;
    }

    private Map<String, Id> queryExistingRecordIds(MappingRecord sampleRecord, Set<String> matchValues) {
        Map<String, Id> recordIdsByMatchValue = new Map<String, Id>();
        if (matchValues == null || matchValues.isEmpty()) {
            return recordIdsByMatchValue;
        }

        validateMatchField(sampleRecord);
        String query = 'SELECT Id, ' + sampleRecord.matchField + ' FROM ' + sampleRecord.targetObject +
            ' WHERE ' + sampleRecord.matchField + ' IN :matchValues';
        List<SObject> records = Database.query(query);
        for (SObject record : records) {
            Object matchValue = record.get(sampleRecord.matchField);
            if (matchValue != null && !recordIdsByMatchValue.containsKey(String.valueOf(matchValue))) {
                recordIdsByMatchValue.put(String.valueOf(matchValue), record.Id);
            }
        }
        return recordIdsByMatchValue;
    }

    private Id getExistingRecordId(MappingRecord mappingRecord, Map<String, Map<String, Id>> existingRecordIdsByGroup) {
        Object matchValue = mappingRecord.record.get(mappingRecord.matchField);
        if (matchValue == null) {
            return null;
        }

        Map<String, Id> recordIdsByMatchValue = existingRecordIdsByGroup.get(getMatchGroupKey(mappingRecord));
        return recordIdsByMatchValue == null ? null : recordIdsByMatchValue.get(String.valueOf(matchValue));
    }

    private void validateMatchField(MappingRecord mappingRecord) {
        if (!Schema.getGlobalDescribe().containsKey(mappingRecord.targetObject)) {
            throw new FrameworkException('Mapping targetObject was not found. Mapping: ' + mappingRecord.mappingKey + ', targetObject: ' + mappingRecord.targetObject);
        }
        Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get(mappingRecord.targetObject).getDescribe().fields.getMap();
        if (!fields.containsKey(mappingRecord.matchField)) {
            throw new FrameworkException('Mapping match field was not found. Mapping: ' + mappingRecord.mappingKey + ', Field: ' + mappingRecord.matchField);
        }
    }

    private String getMatchGroupKey(MappingRecord mappingRecord) {
        return mappingRecord.targetObject + '|' + mappingRecord.matchField;
    }

    private void createEvents(List<Application__c> applications, String eventType, String message) {
        for (Application__c application : applications) {
            eventStore.createEvent(application.Id, eventType, message, null);
        }
    }

    private void validateCommand(ConvertApplicationsCommand command) {
        if (command == null) {
            throw new FrameworkException('ConvertApplications command is required.');
        }
        if (String.isBlank(command.consumerKey)) {
            throw new FrameworkException('Consumer key is required.');
        }
        if (String.isBlank(command.processKey)) {
            throw new FrameworkException('Process key is required.');
        }
    }
}
