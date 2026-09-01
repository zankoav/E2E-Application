public interface StepAvailabilityRule {
    RuleResult isAvailable(StepRuntimeContext context, Map<String, Object> ruleDefinition);
}
