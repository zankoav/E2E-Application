global class DefaultIntegrationAdapter implements IntegrationAdapter {
    global IntegrationResult execute(IntegrationRequest request) {
        return IntegrationResult.ok(new Map<String, Object>());
    }
}
