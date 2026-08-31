@IsTest
private class ProcessDefinitionTest {
    @IsTest
    static void parsesAndValidatesMinimalDefinition() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","label":"Fuel Card Application","version":"1.0.0"},"scenarios":{"newCustomer":{"label":"New Customer","initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{"label":"Contact Details"},"finish":{"label":"Finish"}}}';

        ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
        new DefinitionValidator().validate(definition);

        Assert.areEqual('fuelCardApplication', definition.key);
        Assert.areEqual('1.0.0', definition.version);
        Assert.areEqual('contactDetails', definition.getScenario('newCustomer').initialStep);
        Assert.areEqual(2, definition.getScenario('newCustomer').steps.size());
    }

    @IsTest
    static void rejectsScenarioWithMissingStep() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('missing step'));
        }
    }
}
