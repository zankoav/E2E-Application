public class ApplicationSnapshot {
    public ApplicationInfo application;
    public List<StepInfo> steps = new List<StepInfo>();
    public Map<String, Object> data = new Map<String, Object>();
    public List<JobInfo> jobs = new List<JobInfo>();
    public List<StopProcessInfo> stopProcesses = new List<StopProcessInfo>();
    public List<String> availableActions = new List<String>();

    public class ApplicationInfo {
        public String id;
        public String name;
        public String processKey;
        public String scenarioKey;
        public String status;
        public String conversionStatus;
        public String currentStep;
        public String consumerKey;
        public String externalReference;
        public String definitionVersion;
    }

    public class StepInfo {
        public String key;
        public String label;
        public String status;
        public Boolean available;
    }

    public class StopProcessInfo {
        public String code;
        public String label;
        public String type;
        public String status;
        public String message;
    }

    public class JobInfo {
        public String key;
        public String name;
        public String label;
        public String sourceStepKey;
        public String status;
        public String executionMode;
        public Boolean canBeRestarted;
        public String errorCode;
        public String errorMessage;
    }
}
