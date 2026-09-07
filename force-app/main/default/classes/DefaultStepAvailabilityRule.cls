global class DefaultStepAvailabilityRule implements StepAvailabilityRule {
    global RuleResult isAvailable(StepRuntimeContext context, Map<String, Object> ruleDefinition) {
        return RuleResult.allow();
    }
}
