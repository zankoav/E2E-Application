public class DefaultStepTransitionRule implements StepTransitionRule {
    public RuleResult canTransition(StepRuntimeContext context, Map<String, Object> ruleDefinition) {
        return RuleResult.allow();
    }
}
