@IsTest
private class ReferenceDataServiceTest {
    @IsTest
    static void loadsStepReferenceDataFromIntegration() {
        ProcessDefinition definition = createDefinition();
        Application__c application = createApplication();

        Map<String, Object> references = new ReferenceDataService().loadReferences(
            application,
            definition,
            'products',
            new Set<String>{ 'availableProducts' }
        );

        Assert.areEqual(1, references.size());
        Map<String, Object> availableProducts = (Map<String, Object>) references.get('availableProducts');
        Assert.areEqual('availableProducts', availableProducts.get('referenceKey'));
        Assert.areEqual('products', availableProducts.get('stepKey'));
        Assert.areEqual(true, availableProducts.get('activeOnly'));
    }

    @IsTest
    static void loadsAllReferencesWhenRequestDoesNotFilterKeys() {
        ProcessDefinition definition = createDefinition();
        Application__c application = createApplication();

        Map<String, Object> references = new ReferenceDataService().loadReferences(
            application,
            definition,
            'products',
            new Set<String>()
        );

        Assert.areEqual(2, references.size());
        Assert.isTrue(references.containsKey('availableProducts'));
        Assert.isTrue(references.containsKey('vehicleTypes'));
    }

    @IsTest
    static void restControllerReturnsReferenceData() {
        Application__c application = createPersistedApplication();
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/reference-data';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(
            '{"applicationId":"' + String.valueOf(application.Id) + '","consumerKey":"webPortal","stepKey":"contactDetails"}'
        );
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationReferenceDataRestController.post();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(true, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('references'));
    }

    @IsTest
    static void restControllerReturnsErrorForInvalidRequest() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/reference-data';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"consumerKey":"webPortal"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationReferenceDataRestController.post();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(false, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('errorDetails'));
    }

    @IsTest
    static void parsesGetReferenceDataCommandFromJson() {
        String requestBody = '{"applicationId":"a00123456789012AAA","consumerKey":"webPortal","stepKey":"products","referenceKeys":["availableProducts"]}';

        GetReferenceDataCommand command = GetReferenceDataCommand.fromJson(requestBody);

        Assert.areEqual('a00123456789012AAA', command.applicationId);
        Assert.areEqual('webPortal', command.consumerKey);
        Assert.areEqual('products', command.stepKey);
        Assert.areEqual(true, command.getReferenceKeys().contains('availableProducts'));
    }

    @IsTest
    static void commandReturnsEmptyReferenceKeySetWhenUnset() {
        GetReferenceDataCommand command = new GetReferenceDataCommand();
        command.referenceKeys = null;

        Assert.areEqual(0, command.getReferenceKeys().size());
    }

    @IsTest
    static void rejectsMissingStepKey() {
        try {
            new ReferenceDataService().loadReferences(createApplication(), createDefinition(), null, new Set<String>());
            Assert.fail('Expected missing step key to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Step key'));
        }
    }

    @IsTest
    static void rejectsMissingStepDefinition() {
        try {
            new ReferenceDataService().loadReferences(createApplication(), createDefinition(), 'missingStep', new Set<String>());
            Assert.fail('Expected missing step definition to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Step definition'));
        }
    }

    @IsTest
    static void rejectsMissingApplicationAndDefinition() {
        try {
            new ReferenceDataService().loadReferences(null, createDefinition(), 'products', new Set<String>());
            Assert.fail('Expected missing Application to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Application'));
        }

        try {
            new ReferenceDataService().loadReferences(createApplication(), null, 'products', new Set<String>());
            Assert.fail('Expected missing Process definition to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Process definition'));
        }
    }

    private static ProcessDefinition createDefinition() {
        return ProcessDefinition.parse(
            '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"products","steps":["products"]}},"steps":{"products":{"label":"Products","referenceData":{"availableProducts":{"integrationKey":"productCatalog","input":{"activeOnly":true}},"vehicleTypes":{"integrationKey":"vehicleCatalog"}}}},"integrations":{"productCatalog":{"adapterClass":"TestReferenceDataIntegrationAdapter"},"vehicleCatalog":{"adapterClass":"TestReferenceDataIntegrationAdapter"}}}'
        );
    }

    private static Application__c createApplication() {
        return new Application__c(
            Consumer_Key__c = 'webPortal',
            Process_Key__c = 'fuelCardApplication',
            Scenario_Key__c = 'newCustomer',
            Current_Step_Key__c = 'products'
        );
    }

    private static Application__c createPersistedApplication() {
        InitApplicationCommand command = new InitApplicationCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.scenarioKey = 'newCustomer';
        command.externalReference = 'reference-' + String.valueOf(Crypto.getRandomInteger());
        Id applicationId = (Id) new InitApplicationHandler().execute(command).snapshot.application.id;
        return [
            SELECT Id, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Consumer_Key__c, Status__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];
    }
}
