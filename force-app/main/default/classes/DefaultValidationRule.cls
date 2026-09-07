global class DefaultValidationRule implements ValidationRule {
    global RuleResult validate(StepRuntimeContext context, Map<String, Object> ruleDefinition) {
        return RuleResult.allow();
    }
}
