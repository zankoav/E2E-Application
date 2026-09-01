public class DefaultIntegrationAdapter implements IntegrationAdapter {
    public IntegrationResult execute(IntegrationRequest request) {
        return IntegrationResult.ok(new Map<String, Object>());
    }
}
