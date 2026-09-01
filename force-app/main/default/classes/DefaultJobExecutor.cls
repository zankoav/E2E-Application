public class DefaultJobExecutor implements JobExecutor {
    public JobExecutionResult execute(Application_Job__c job, Map<String, Object> jobDefinition) {
        return JobExecutionResult.ok();
    }
}
