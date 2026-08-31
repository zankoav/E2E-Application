public class ApplicationSnapshot {
    public ApplicationInfo application;
    public List<StepInfo> steps = new List<StepInfo>();
    public Map<String, Object> data = new Map<String, Object>();
    public List<Object> jobs = new List<Object>();
    public List<Object> stopProcesses = new List<Object>();
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
}
