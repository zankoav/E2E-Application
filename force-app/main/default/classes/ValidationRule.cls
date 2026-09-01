public interface ValidationRule {
    RuleResult validate(StepRuntimeContext context, Map<String, Object> ruleDefinition);
}
