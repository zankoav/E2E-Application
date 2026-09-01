public class DefaultValidationRule implements ValidationRule {
    public RuleResult validate(StepRuntimeContext context, Map<String, Object> ruleDefinition) {
        return RuleResult.allow();
    }
}
