public class RuleResult {
    public Boolean allowed;
    public String code;
    public String message;

    public RuleResult() {
        this.allowed = true;
    }

    public static RuleResult allow() {
        return new RuleResult();
    }

    public static RuleResult block(String code, String message) {
        RuleResult result = new RuleResult();
        result.allowed = false;
        result.code = code;
        result.message = String.isBlank(message) ? code : message;
        return result;
    }
}
