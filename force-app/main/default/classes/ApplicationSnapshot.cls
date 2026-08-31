global class ApplicationSnapshot {
    global ApplicationInfo application;
    global List<StepInfo> steps = new List<StepInfo>();
    global Map<String, Object> data = new Map<String, Object>();
    global List<Object> jobs = new List<Object>();
    global List<Object> stopProcesses = new List<Object>();
    global List<String> availableActions = new List<String>();

    global class ApplicationInfo {
        global String id;
        global String name;
        global String processKey;
        global String scenarioKey;
        global String status;
        global String conversionStatus;
        global String currentStep;
        global String consumerKey;
        global String externalReference;
        global String definitionVersion;
    }

    global class StepInfo {
        global String key;
        global String label;
        global String status;
        global Boolean available;
    }
}
