public class DefaultStepAvailabilityRule implements StepAvailabilityRule {
    public RuleResult isAvailable(StepRuntimeContext context, Map<String, Object> ruleDefinition) {
        return RuleResult.allow();
    }
}
