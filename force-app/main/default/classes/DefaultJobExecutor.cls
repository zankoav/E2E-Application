global class DefaultJobExecutor implements JobExecutor {
    global JobExecutionResult execute(Application_Job__c job, Map<String, Object> jobDefinition) {
        return JobExecutionResult.ok();
    }
}
