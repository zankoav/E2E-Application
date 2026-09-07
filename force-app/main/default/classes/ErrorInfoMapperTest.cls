@IsTest
private class ErrorInfoMapperTest {
    @IsTest
    static void mapsRequiredFieldMessageToInvalidRequest() {
        ErrorInfo errorInfo = ErrorInfoMapper.fromMessage('Consumer key is required.');

        Assert.areEqual(FrameworkErrorCodes.INVALID_REQUEST, errorInfo.code);
        Assert.areEqual('Consumer key is required.', errorInfo.message);
        Assert.isNotNull(errorInfo.details);
    }

    @IsTest
    static void mapsFrameworkExceptionMessageToStableCode() {
        try {
            throw new FrameworkException('Application Job cannot run from status: Completed');
        } catch (Exception ex) {
            ErrorInfo errorInfo = ErrorInfoMapper.fromException(ex);

            Assert.areEqual(FrameworkErrorCodes.JOB_NOT_RUNNABLE, errorInfo.code);
            Assert.areEqual('Application Job cannot run from status: Completed', errorInfo.message);
        }
    }

    @IsTest
    static void mapsRuleResultCodeDirectly() {
        RuleResult ruleResult = RuleResult.block(
            'REQUIRED_JOB_NOT_COMPLETED',
            'Required Job is not completed. Job: contactDetails___emailValidation'
        );

        ErrorInfo errorInfo = ErrorInfoMapper.fromRuleResult(ruleResult);

        Assert.areEqual('REQUIRED_JOB_NOT_COMPLETED', errorInfo.code);
        Assert.areEqual('Required Job is not completed. Job: contactDetails___emailValidation', errorInfo.message);
    }

    @IsTest
    static void commandResultKeepsLegacyAndStructuredErrorsTogether() {
        CommandResult result = CommandResult.fail(FrameworkErrorCodes.ACCESS_DENIED, 'Consumer is not allowed for Application.');

        Assert.areEqual(false, result.success);
        Assert.areEqual(1, result.errors.size());
        Assert.areEqual(1, result.errorDetails.size());
        Assert.areEqual('Consumer is not allowed for Application.', result.errors[0]);
        Assert.areEqual(FrameworkErrorCodes.ACCESS_DENIED, result.errorDetails[0].code);
    }

    @IsTest
    static void blockedResultUsesRuleCode() {
        CommandResult result = CommandResult.blocked(
            null,
            RuleResult.block('STOP_PROCESS_ACTIVE', 'Active Stop Process blocks transition.')
        );

        Assert.areEqual(false, result.success);
        Assert.areEqual('Active Stop Process blocks transition.', result.errors[0]);
        Assert.areEqual('STOP_PROCESS_ACTIVE', result.errorDetails[0].code);
    }
}
