public interface StepTransitionRule {
    RuleResult canTransition(StepRuntimeContext context, Map<String, Object> ruleDefinition);
}
