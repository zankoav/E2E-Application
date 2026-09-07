global class RuleResult {
    global Boolean allowed;
    global String code;
    global String message;

    global RuleResult() {
        this.allowed = true;
    }

    global static RuleResult allow() {
        return new RuleResult();
    }

    global static RuleResult block(String code, String message) {
        RuleResult result = new RuleResult();
        result.allowed = false;
        result.code = code;
        result.message = String.isBlank(message) ? code : message;
        return result;
    }
}
