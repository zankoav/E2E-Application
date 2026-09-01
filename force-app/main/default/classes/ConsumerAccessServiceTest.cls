@IsTest
private class ConsumerAccessServiceTest {
    @IsTest
    static void validatesInitAccessForKnownConsumer() {
        ProcessDefinition definition = ProcessDefinition.parse(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"label":"Contact Details"}}}'
        );

        new ConsumerAccessService().validateInitAccess(
            'webPortal',
            'fuelCardApplication',
            'newCustomer',
            definition.getScenario('newCustomer')
        );
    }

    @IsTest
    static void rejectsUnknownConsumer() {
        ProcessDefinition definition = ProcessDefinition.parse(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"label":"Contact Details"}}}'
        );

        try {
            new ConsumerAccessService().validateInitAccess(
                'unknownConsumer',
                'fuelCardApplication',
                'newCustomer',
                definition.getScenario('newCustomer')
            );
            Assert.fail('Expected Consumer validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Consumer Definition'));
        }
    }

    @IsTest
    static void rejectsScenarioLevelConsumerRestriction() {
        ProcessDefinition definition = ProcessDefinition.parse(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"],"consumerKeys":["mobileApp"]}},"steps":{"contactDetails":{"label":"Contact Details"}}}'
        );

        try {
            new ConsumerAccessService().validateInitAccess(
                'webPortal',
                'fuelCardApplication',
                'newCustomer',
                definition.getScenario('newCustomer')
            );
            Assert.fail('Expected Consumer validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Scenario'));
        }
    }

    @IsTest
    static void validatesApplicationAccessForOwnerConsumer() {
        Application__c application = new Application__c(
            Consumer_Key__c = 'webPortal',
            Process_Key__c = 'fuelCardApplication',
            Scenario_Key__c = 'newCustomer'
        );

        new ConsumerAccessService().validateApplicationAccess('webPortal', application);
    }

    @IsTest
    static void rejectsApplicationAccessForDifferentConsumer() {
        Application__c application = new Application__c(
            Consumer_Key__c = 'webPortal',
            Process_Key__c = 'fuelCardApplication',
            Scenario_Key__c = 'newCustomer'
        );

        try {
            new ConsumerAccessService().validateApplicationAccess('mobileApp', application);
            Assert.fail('Expected Consumer validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Application'));
        }
    }
}
