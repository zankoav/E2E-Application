global with sharing class ApplicationConversionBatch implements Database.Batchable<SObject>, Database.Stateful {
    global String processKey;
    global Boolean retryFailed;
    global Integer requestedCount = 0;
    global Integer convertedCount = 0;
    global Integer failedCount = 0;
    global List<String> errors = new List<String>();

    global ApplicationConversionBatch(String processKey) {
        this(processKey, false);
    }

    global ApplicationConversionBatch(String processKey, Boolean retryFailed) {
        if (String.isBlank(processKey)) {
            throw new FrameworkException('Process key is required.');
        }
        this.processKey = processKey;
        this.retryFailed = retryFailed == true;
    }

    global Database.QueryLocator start(Database.BatchableContext context) {
        Set<String> conversionStatuses = new Set<String>{ FrameworkConstants.CONVERSION_STATUS_READY };
        if (retryFailed == true) {
            conversionStatuses.add(FrameworkConstants.CONVERSION_STATUS_FAILED);
        }

        return Database.getQueryLocator([
            SELECT Id
            FROM Application__c
            WHERE Process_Key__c = :processKey
            AND Status__c = :FrameworkConstants.APPLICATION_STATUS_COMPLETED
            AND Conversion_Status__c IN :conversionStatuses
        ]);
    }

    global void execute(Database.BatchableContext context, List<SObject> scope) {
        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.processKey = processKey;
        command.maxBatchSize = scope.size();
        command.retryFailed = retryFailed;
        for (SObject record : scope) {
            command.applicationIds.add(String.valueOf(record.Id));
        }

        ConversionResult result = new ConvertApplicationsHandler().executeSystem(command).conversion;
        requestedCount += result.requestedCount;
        convertedCount += result.convertedCount;
        failedCount += result.failedCount;
        errors.addAll(result.errors);
    }

    global void finish(Database.BatchableContext context) {
    }
}
