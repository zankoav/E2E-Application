global with sharing class ApplicationConversionService {
    global static ConversionResult convertOne(Id applicationId) {
        return convertOne(applicationId, false);
    }

    global static ConversionResult convertOne(Id applicationId, Boolean retryFailed) {
        if (applicationId == null) {
            throw new FrameworkException('Application id is required.');
        }

        Application__c application = new ApplicationStateStore().getApplication(applicationId);
        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.processKey = application.Process_Key__c;
        command.applicationIds = new List<String>{ String.valueOf(applicationId) };
        command.maxBatchSize = 1;
        command.retryFailed = retryFailed;
        return new ConvertApplicationsHandler().executeSystem(command).conversion;
    }

    global static ConversionResult convertReady(String processKey, Integer maxBatchSize) {
        return convertReady(processKey, maxBatchSize, false);
    }

    global static ConversionResult convertReady(String processKey, Integer maxBatchSize, Boolean retryFailed) {
        if (String.isBlank(processKey)) {
            throw new FrameworkException('Process key is required.');
        }

        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.processKey = processKey;
        command.maxBatchSize = maxBatchSize;
        command.retryFailed = retryFailed;
        return new ConvertApplicationsHandler().executeSystem(command).conversion;
    }

    global static Id startBatch(String processKey, Integer batchSize) {
        return startBatch(processKey, batchSize, false);
    }

    global static Id startBatch(String processKey, Integer batchSize, Boolean retryFailed) {
        if (String.isBlank(processKey)) {
            throw new FrameworkException('Process key is required.');
        }
        Integer safeBatchSize = batchSize == null || batchSize <= 0 ? 50 : Math.min(batchSize, 200);
        return Database.executeBatch(new ApplicationConversionBatch(processKey, retryFailed), safeBatchSize);
    }
}
