global class DefaultStepTransitionRule implements StepTransitionRule {
    global RuleResult canTransition(StepRuntimeContext context, Map<String, Object> ruleDefinition) {
        return RuleResult.allow();
    }
}
