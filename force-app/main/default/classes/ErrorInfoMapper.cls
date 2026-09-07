public inherited sharing class ErrorInfoMapper {
    public static ErrorInfo fromException(Exception ex) {
        if (ex instanceof FrameworkException) {
            return fromMessage(ex.getMessage());
        }
        return new ErrorInfo(FrameworkErrorCodes.UNKNOWN_ERROR, ex == null ? null : ex.getMessage());
    }

    public static ErrorInfo fromMessage(String message) {
        return new ErrorInfo(resolveCode(message), message);
    }

    public static ErrorInfo fromRuleResult(RuleResult ruleResult) {
        String code = ruleResult == null ? null : ruleResult.code;
        String message = ruleResult == null ? null : ruleResult.message;
        return new ErrorInfo(String.isBlank(code) ? FrameworkErrorCodes.BLOCKED_BY_RULE : code, message);
    }

    private static String resolveCode(String message) {
        if (String.isBlank(message)) {
            return FrameworkErrorCodes.UNKNOWN_ERROR;
        }

        String normalized = message.toLowerCase();
        if (normalized.contains('consumer is not allowed')) {
            return FrameworkErrorCodes.ACCESS_DENIED;
        }
        if (normalized.contains('application was not found')) {
            return FrameworkErrorCodes.APPLICATION_NOT_FOUND;
        }
        if (normalized.contains('application job was not found')) {
            return FrameworkErrorCodes.JOB_NOT_FOUND;
        }
        if (
            normalized.contains('command is required') ||
            normalized.contains(' id is required') ||
            normalized.contains(' key is required')
        ) {
            return FrameworkErrorCodes.INVALID_REQUEST;
        }
        if (
            normalized.contains('cannot run from status') ||
            normalized.contains('cannot restart from status') ||
            normalized.contains('cannot be restarted')
        ) {
            return FrameworkErrorCodes.JOB_NOT_RUNNABLE;
        }
        if (
            normalized.contains('completed application') ||
            normalized.contains('submitted step is not current') ||
            normalized.contains('continue step is not current') ||
            normalized.contains('not allowed for application status') ||
            normalized.contains('cannot move application')
        ) {
            return FrameworkErrorCodes.INVALID_APPLICATION_STATE;
        }
        if (normalized.contains('mapping')) {
            return FrameworkErrorCodes.MAPPING_ERROR;
        }
        if (normalized.contains('conversion')) {
            return FrameworkErrorCodes.CONVERSION_ERROR;
        }
        if (normalized.contains('integration')) {
            return FrameworkErrorCodes.INTEGRATION_ERROR;
        }
        if (normalized.contains('rule')) {
            return FrameworkErrorCodes.RULE_ERROR;
        }
        if (normalized.contains('definition') || normalized.contains('scenario was not found')) {
            return FrameworkErrorCodes.DEFINITION_ERROR;
        }
        return FrameworkErrorCodes.UNKNOWN_ERROR;
    }
}
