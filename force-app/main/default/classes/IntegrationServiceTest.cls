@IsTest
private class IntegrationServiceTest {
    @IsTest
    static void executesProcessDefinedIntegrationWithDefaultAdapter() {
        ProcessDefinition definition = ProcessDefinition.parse(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{}},"integrations":{"emailProvider":{"settings":{"timeoutMs":5000}}}}'
        );

        IntegrationResult result = new IntegrationService().execute(
            'emailProvider',
            createApplication(),
            definition,
            new Map<String, Object>{ 'email' => 'test@example.com' }
        );

        Assert.areEqual(true, result.success);
        Assert.areEqual(0, result.data.size());
    }

    @IsTest
    static void resolvesMetadataIntegrationWhenProcessDoesNotOverrideIt() {
        ProcessDefinition definition = ProcessDefinition.parse(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{}},"integrations":{}}'
        );

        IntegrationDefinition integrationDefinition = new IntegrationDefinitionResolver().resolve(definition, 'default');

        Assert.areEqual('default', integrationDefinition.key);
        Assert.areEqual('DefaultIntegrationAdapter', integrationDefinition.adapterClass);
    }

    @IsTest
    static void processDefinitionCanReferenceMetadataDefinitionAndOverrideSettings() {
        ProcessDefinition definition = ProcessDefinition.parse(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{}},"integrations":{"emailProvider":{"definitionKey":"default","settings":{"timeoutMs":5000}}}}'
        );

        IntegrationDefinition integrationDefinition = new IntegrationDefinitionResolver().resolve(definition, 'emailProvider');

        Assert.areEqual('emailProvider', integrationDefinition.key);
        Assert.areEqual('DefaultIntegrationAdapter', integrationDefinition.adapterClass);
        Assert.areEqual(5000, integrationDefinition.settings.get('timeoutMs'));
    }

    @IsTest
    static void rejectsMissingIntegrationDefinition() {
        ProcessDefinition definition = ProcessDefinition.parse(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{}},"integrations":{}}'
        );

        try {
            new IntegrationDefinitionResolver().resolve(definition, 'missingIntegration');
            Assert.fail('Expected Integration Definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Integration Definition'));
        }
    }

    @IsTest
    static void returnsFailedResultWhenAdapterFails() {
        ProcessDefinition definition = ProcessDefinition.parse(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{}},"integrations":{"broken":{"adapterClass":"MissingIntegrationAdapter"}}}'
        );

        IntegrationResult result = new IntegrationService().execute(
            'broken',
            createApplication(),
            definition,
            null
        );

        Assert.areEqual(false, result.success);
        Assert.areEqual('UNEXPECTED_INTEGRATION_ERROR', result.errorCode);
    }

    private static Application__c createApplication() {
        return new Application__c(
            Consumer_Key__c = 'webPortal',
            Process_Key__c = 'fuelCardApplication',
            Scenario_Key__c = 'newCustomer'
        );
    }
}
