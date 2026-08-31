global inherited sharing class SnapshotBuilder {
    global ApplicationSnapshot build(Application__c application, ProcessDefinition definition) {
        if (application == null) {
            throw new FrameworkException('Application is required to build Snapshot.');
        }
        if (definition == null) {
            throw new FrameworkException('Process definition is required to build Snapshot.');
        }

        ApplicationSnapshot snapshot = new ApplicationSnapshot();
        snapshot.application = buildApplicationInfo(application);
        snapshot.steps = buildSteps(application, definition);
        snapshot.availableActions.add('GetSnapshot');
        snapshot.availableActions.add('SubmitStep');
        return snapshot;
    }

    private ApplicationSnapshot.ApplicationInfo buildApplicationInfo(Application__c application) {
        ApplicationSnapshot.ApplicationInfo info = new ApplicationSnapshot.ApplicationInfo();
        info.id = String.valueOf(application.Id);
        info.name = application.Name;
        info.processKey = application.Process_Key__c;
        info.scenarioKey = application.Scenario_Key__c;
        info.status = application.Status__c;
        info.conversionStatus = application.Conversion_Status__c;
        info.currentStep = application.Current_Step_Key__c;
        info.consumerKey = application.Consumer_Key__c;
        info.externalReference = application.External_Reference__c;
        info.definitionVersion = application.Definition_Version__c;
        return info;
    }

    private List<ApplicationSnapshot.StepInfo> buildSteps(Application__c application, ProcessDefinition definition) {
        List<ApplicationSnapshot.StepInfo> steps = new List<ApplicationSnapshot.StepInfo>();
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario(application.Scenario_Key__c);
        if (scenario == null) {
            return steps;
        }

        for (String stepKey : scenario.steps) {
            ApplicationSnapshot.StepInfo stepInfo = new ApplicationSnapshot.StepInfo();
            stepInfo.key = stepKey;
            stepInfo.label = getStepLabel(definition, stepKey);
            stepInfo.status = stepKey == application.Current_Step_Key__c ? 'Current' : 'Available';
            stepInfo.available = true;
            steps.add(stepInfo);
        }
        return steps;
    }

    private String getStepLabel(ProcessDefinition definition, String stepKey) {
        Object rawStep = definition.steps.get(stepKey);
        if (rawStep instanceof Map<String, Object>) {
            Object label = ((Map<String, Object>) rawStep).get('label');
            if (label != null) {
                return String.valueOf(label);
            }
        }
        return stepKey;
    }
}
