global with sharing class ApplicationConversionScheduler implements Schedulable {
    global String processKey;
    global Integer batchSize;
    global Boolean retryFailed;
    global Boolean reschedule;

    global ApplicationConversionScheduler() {
        this(null, 50, false, true);
    }

    global ApplicationConversionScheduler(String processKey) {
        this(processKey, 50, false, true);
    }

    global ApplicationConversionScheduler(String processKey, Integer batchSize, Boolean retryFailed, Boolean reschedule) {
        this.processKey = processKey;
        this.batchSize = batchSize == null || batchSize <= 0 ? 50 : Math.min(batchSize, 200);
        this.retryFailed = retryFailed == true;
        this.reschedule = reschedule != false;
    }

    global void execute(SchedulableContext context) {
        if (String.isBlank(processKey)) {
            scheduleAllActiveProcesses();
            return;
        }

        ApplicationConversionService.startBatch(processKey, batchSize, retryFailed);
        if (reschedule == true) {
            scheduleProcess(processKey, batchSize, retryFailed, false);
        }
    }

    global static List<String> scheduleAllActiveProcesses() {
        List<String> jobIds = new List<String>();
        for (Process_Definition__mdt definition : [
            SELECT Process_Key__c, Conversion_Check_Interval_Seconds__c
            FROM Process_Definition__mdt
            WHERE Active__c = true
            AND Usage__c = :FrameworkConstants.DEFINITION_USAGE_RUNTIME
            AND Conversion_Check_Interval_Seconds__c != null
            AND Conversion_Check_Interval_Seconds__c > 0
        ]) {
            jobIds.add(scheduleProcess(definition.Process_Key__c));
        }
        return jobIds;
    }

    global static String scheduleProcess(String processKey) {
        return scheduleProcess(processKey, 50, false, true);
    }

    global static String scheduleProcess(String processKey, Integer batchSize, Boolean retryFailed) {
        return scheduleProcess(processKey, batchSize, retryFailed, true);
    }

    private static String scheduleProcess(String processKey, Integer batchSize, Boolean retryFailed, Boolean abortExisting) {
        if (String.isBlank(processKey)) {
            throw new FrameworkException('Process key is required.');
        }
        Process_Definition__mdt definition = getRuntimeDefinition(processKey);
        Integer intervalSeconds = getIntervalSeconds(definition);
        if (abortExisting == true) {
            abortExistingSchedules(processKey);
        }

        Datetime nextRunAt = System.now().addSeconds(intervalSeconds);
        String jobName = getJobName(processKey, nextRunAt);
        return System.schedule(
            jobName,
            getOneTimeCron(nextRunAt),
            new ApplicationConversionScheduler(processKey, batchSize, retryFailed, true)
        );
    }

    private static Process_Definition__mdt getRuntimeDefinition(String processKey) {
        List<Process_Definition__mdt> definitions = [
            SELECT Process_Key__c, Conversion_Check_Interval_Seconds__c
            FROM Process_Definition__mdt
            WHERE Process_Key__c = :processKey
            AND Active__c = true
            AND Usage__c = :FrameworkConstants.DEFINITION_USAGE_RUNTIME
            LIMIT 1
        ];
        if (definitions.isEmpty()) {
            throw new FrameworkException('Runnable process definition was not found. Process: ' + processKey);
        }
        return definitions[0];
    }

    private static Integer getIntervalSeconds(Process_Definition__mdt definition) {
        if (definition.Conversion_Check_Interval_Seconds__c == null || definition.Conversion_Check_Interval_Seconds__c <= 0) {
            throw new FrameworkException('Conversion check interval must be greater than zero. Process: ' + definition.Process_Key__c);
        }
        return Math.max(60, Integer.valueOf(definition.Conversion_Check_Interval_Seconds__c));
    }

    private static void abortExistingSchedules(String processKey) {
        String jobNamePrefix = getJobNamePrefix(processKey) + '%';
        for (CronTrigger scheduledJob : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :jobNamePrefix
            AND State IN ('WAITING', 'ACQUIRED')
        ]) {
            System.abortJob(scheduledJob.Id);
        }
    }

    private static String getJobName(String processKey, Datetime nextRunAt) {
        return getJobNamePrefix(processKey) + String.valueOf(nextRunAt.getTime());
    }

    private static String getJobNamePrefix(String processKey) {
        return 'E2E Conversion ' + processKey + ' ';
    }

    private static String getOneTimeCron(Datetime value) {
        return String.valueOf(value.second()) + ' ' +
            String.valueOf(value.minute()) + ' ' +
            String.valueOf(value.hour()) + ' ' +
            String.valueOf(value.day()) + ' ' +
            String.valueOf(value.month()) + ' ? ' +
            String.valueOf(value.year());
    }
}
