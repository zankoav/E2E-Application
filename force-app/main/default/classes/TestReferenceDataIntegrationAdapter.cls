@IsTest
global class TestReferenceDataIntegrationAdapter implements IntegrationAdapter {
    global IntegrationResult execute(IntegrationRequest request) {
        Map<String, Object> data = new Map<String, Object>();
        data.put('integrationKey', request.integrationKey);
        data.put('referenceKey', request.input.get('referenceKey'));
        data.put('stepKey', request.input.get('stepKey'));
        data.put('activeOnly', request.input.get('activeOnly'));
        return IntegrationResult.ok(data);
    }
}
