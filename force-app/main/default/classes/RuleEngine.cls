public virtual class RuleEngine {
    /********
     *
     * RuleEngine is the first narrow boundary between process configuration and runtime behavior.
     * SubmitStep asks rules for decisions, but the handler still owns state changes and persistence.
     *
     ********/
    public virtual RuleResult evaluateValidationRules(StepRuntimeContext context) {
        for (String ruleKey : getStepRuleKeys(context, 'validationRules')) {
            Map<String, Object> ruleDefinition = getRuleDefinition(context.definition, ruleKey);
            RuleResult result = createValidationRule(ruleDefinition).validate(context, ruleDefinition);
            if (!result.allowed) {
                return result;
            }
        }
        return RuleResult.allow();
    }

    public virtual RuleResult evaluateStepTransitionRules(StepRuntimeContext context) {
        RuleResult stopProcessResult = evaluateStopProcesses(context);
        if (!stopProcessResult.allowed) {
            return stopProcessResult;
        }

        RuleResult jobDependencyResult = evaluateJobDependencies(context);
        if (!jobDependencyResult.allowed) {
            return jobDependencyResult;
        }

        for (String ruleKey : getStepRuleKeys(context, 'transitionRules')) {
            Map<String, Object> ruleDefinition = getRuleDefinition(context.definition, ruleKey);
            RuleResult result = createStepTransitionRule(ruleDefinition).canTransition(context, ruleDefinition);
            if (!result.allowed) {
                return result;
            }
        }
        return RuleResult.allow();
    }

    private RuleResult evaluateJobDependencies(StepRuntimeContext context) {
        for (String ruleKey : getStepRuleKeys(context, 'transitionRules')) {
            Map<String, Object> ruleDefinition = getRuleDefinition(context.definition, ruleKey);
            Object rawRequirements = ruleDefinition.get('requiresJobs');
            if (!(rawRequirements instanceof List<Object>)) {
                continue;
            }

            for (Object rawRequirement : (List<Object>) rawRequirements) {
                Map<String, Object> requirement = rawRequirement instanceof Map<String, Object>
                    ? (Map<String, Object>) rawRequirement
                    : new Map<String, Object>();
                String jobName = getString(requirement, 'jobKey');
                String requiredStatus = getStringOrDefault(requirement, 'status', FrameworkConstants.JOB_STATUS_COMPLETED);
                if (String.isBlank(jobName)) {
                    throw new FrameworkException('Job dependency must define jobKey. Rule: ' + ruleKey);
                }

                String runtimeJobKey = context.currentStepKey + '___' + jobName;
                Application_Job__c job = getJobByKey(context, runtimeJobKey);
                if (job == null || job.Status__c != requiredStatus) {
                    return RuleResult.block(
                        'WAITING_FOR_JOBS',
                        'Required Job is not completed. Job: ' + runtimeJobKey
                    );
                }
            }
        }
        return RuleResult.allow();
    }

    private Application_Job__c getJobByKey(StepRuntimeContext context, String jobKey) {
        if (context.jobs == null) {
            return null;
        }
        for (Application_Job__c job : context.jobs) {
            if (job.Job_Key__c == jobKey) {
                return job;
            }
        }
        return null;
    }

    private RuleResult evaluateStopProcesses(StepRuntimeContext context) {
        if (context.activeStopProcesses == null || context.activeStopProcesses.isEmpty()) {
            return RuleResult.allow();
        }

        Set<String> allowedStopProcessCodes = new Set<String>(getStepRuleKeys(context, 'allowedStopProcesses'));
        for (Application_Stop_Process__c stopProcess : context.activeStopProcesses) {
            if (!allowedStopProcessCodes.contains(stopProcess.Code__c)) {
                return RuleResult.block(
                    'STOP_PROCESS_BLOCKED',
                    'Active Stop Process blocks transition. Code: ' + stopProcess.Code__c
                );
            }
        }
        return RuleResult.allow();
    }

    private ValidationRule createValidationRule(Map<String, Object> ruleDefinition) {
        String className = getString(ruleDefinition, 'class');
        if (String.isBlank(className)) {
            return new DefaultValidationRule();
        }

        Type ruleType = Type.forName(className);
        if (ruleType == null) {
            throw new FrameworkException('Validation Rule class was not found. Class: ' + className);
        }

        Object ruleInstance = ruleType.newInstance();
        if (!(ruleInstance instanceof ValidationRule)) {
            throw new FrameworkException('Rule class must implement ValidationRule. Class: ' + className);
        }
        return (ValidationRule) ruleInstance;
    }

    private StepTransitionRule createStepTransitionRule(Map<String, Object> ruleDefinition) {
        String className = getString(ruleDefinition, 'class');
        if (String.isBlank(className)) {
            return new DefaultStepTransitionRule();
        }

        Type ruleType = Type.forName(className);
        if (ruleType == null) {
            throw new FrameworkException('Step Transition Rule class was not found. Class: ' + className);
        }

        Object ruleInstance = ruleType.newInstance();
        if (!(ruleInstance instanceof StepTransitionRule)) {
            throw new FrameworkException('Rule class must implement StepTransitionRule. Class: ' + className);
        }
        return (StepTransitionRule) ruleInstance;
    }

    private List<String> getStepRuleKeys(StepRuntimeContext context, String ruleListKey) {
        Map<String, Object> stepDefinition = getStepDefinition(context.definition, context.currentStepKey);
        Object rawRuleKeys = stepDefinition.get(ruleListKey);
        if (!(rawRuleKeys instanceof List<Object>)) {
            return new List<String>();
        }

        List<String> ruleKeys = new List<String>();
        for (Object rawRuleKey : (List<Object>) rawRuleKeys) {
            ruleKeys.add(String.valueOf(rawRuleKey));
        }
        return ruleKeys;
    }

    private Map<String, Object> getStepDefinition(ProcessDefinition definition, String stepKey) {
        Object rawStep = definition.steps.get(stepKey);
        return rawStep instanceof Map<String, Object>
            ? (Map<String, Object>) rawStep
            : new Map<String, Object>();
    }

    private Map<String, Object> getRuleDefinition(ProcessDefinition definition, String ruleKey) {
        Map<String, Object> rules = getObjectMap(definition.raw, 'rules');
        Object rawRule = rules.get(ruleKey);
        if (!(rawRule instanceof Map<String, Object>)) {
            throw new FrameworkException('Rule definition was not found. Rule: ' + ruleKey);
        }
        return (Map<String, Object>) rawRule;
    }

    private Map<String, Object> getObjectMap(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value instanceof Map<String, Object>
            ? (Map<String, Object>) value
            : new Map<String, Object>();
    }

    private String getString(Map<String, Object> source, String key) {
        Object value = source.get(key);
        return value == null ? null : String.valueOf(value);
    }

    private String getStringOrDefault(Map<String, Object> source, String key, String defaultValue) {
        String value = getString(source, key);
        return String.isBlank(value) ? defaultValue : value;
    }
}
