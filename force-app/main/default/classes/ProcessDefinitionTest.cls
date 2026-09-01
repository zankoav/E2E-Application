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

    @IsTest
    static void rejectsDefinitionWithoutVersion() {
        String definitionJson = '{"process":{"key":"fuelCardApplication"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"label":"Contact Details"}}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('version'));
        }
    }

    @IsTest
    static void rejectsDefinitionWithoutScenarios() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"steps":{"contactDetails":{"label":"Contact Details"}}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('scenario'));
        }
    }

    @IsTest
    static void rejectsStepWithMissingAvailabilityRule() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"availabilityRules":["missingRule"]}},"rules":{}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('missing Rule'));
        }
    }

    @IsTest
    static void rejectsJobTriggerRuleWithoutJobKey() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"jobTriggerRules":["runEmailValidation"]}},"rules":{"runEmailValidation":{"type":"jobTrigger"}},"jobs":{}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('jobKey'));
        }
    }

    @IsTest
    static void rejectsJobTriggerRuleWithMissingJobDefinition() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"jobTriggerRules":["runEmailValidation"]}},"rules":{"runEmailValidation":{"type":"jobTrigger","jobKey":"emailValidation"}},"jobs":{}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('missing Job'));
        }
    }

    @IsTest
    static void rejectsUnsupportedJobExecutionMode() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"label":"Contact Details"}},"jobs":{"emailValidation":{"executionMode":"futureMagic"}}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('unsupported executionMode'));
        }
    }

    @IsTest
    static void rejectsMappingWithoutTargetObject() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"label":"Contact Details"}},"mappings":{"account":{"fields":[{"target":"Name","source":"company.name"}]}}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('targetObject'));
        }
    }

    @IsTest
    static void rejectsUnsupportedMappingOperation() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"label":"Contact Details"}},"mappings":{"account":{"targetObject":"Account","operation":"merge","fields":[{"target":"Name","source":"company.name"}]}}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('operation'));
        }
    }

    @IsTest
    static void rejectsMissingMappingTransformClass() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"label":"Contact Details"}},"mappings":{"account":{"targetObject":"Account","operation":"insert","fields":[{"target":"Name","source":"company.name","transformClass":"MissingMappingTransform"}]}}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Mapping Transform'));
        }
    }

    @IsTest
    static void rejectsUpsertMappingWithoutMatch() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"label":"Contact Details"}},"mappings":{"account":{"targetObject":"Account","operation":"upsert","fields":[{"target":"Name","source":"company.name"}]}}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('match'));
        }
    }

    @IsTest
    static void acceptsDependentMappingWithRecordReference() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"label":"Contact Details"}},"mappings":{"account":{"targetObject":"Account","operation":"insert","fields":[{"target":"Name","source":"company.name"}]},"contact":{"targetObject":"Contact","operation":"insert","dependsOn":["account"],"fields":[{"target":"LastName","source":"contact.lastName"},{"target":"AccountId","fromRecord":"account"}]}}}';

        ProcessDefinition definition = ProcessDefinition.parse(definitionJson);

        new DefinitionValidator().validate(definition);
    }

    @IsTest
    static void rejectsMappingWithMissingDependency() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"label":"Contact Details"}},"mappings":{"contact":{"targetObject":"Contact","operation":"insert","dependsOn":["account"],"fields":[{"target":"LastName","source":"contact.lastName"}]}}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('missing dependency'));
        }
    }

    @IsTest
    static void rejectsMappingDependencyCycle() {
        String definitionJson = '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails"]}},"steps":{"contactDetails":{"label":"Contact Details"}},"mappings":{"account":{"targetObject":"Account","operation":"insert","dependsOn":["contact"],"fields":[{"target":"Name","source":"company.name"}]},"contact":{"targetObject":"Contact","operation":"insert","dependsOn":["account"],"fields":[{"target":"LastName","source":"contact.lastName"}]}}}';

        try {
            ProcessDefinition definition = ProcessDefinition.parse(definitionJson);
            new DefinitionValidator().validate(definition);
            Assert.fail('Expected definition validation to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('cycle'));
        }
    }
}
