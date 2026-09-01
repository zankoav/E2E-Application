public interface JobExecutor {
    JobExecutionResult execute(Application_Job__c job, Map<String, Object> jobDefinition);
}
