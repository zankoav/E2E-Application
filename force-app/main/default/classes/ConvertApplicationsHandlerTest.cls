@IsTest
private class ConvertApplicationsHandlerTest {
    @IsTest
    static void convertsReadyApplicationIntoMappedAccount() {
        Application__c application = createCompletedApplication('convert-account');
        insert new Application_Data__c(
            Application__c = application.Id,
            Step_Key__c = 'companyDetails',
            Key__c = 'company.name',
            Type__c = 'String',
            Value__c = 'Converted Test Account'
        );

        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.applicationIds = new List<String>{ String.valueOf(application.Id) };

        Test.startTest();
        CommandResult commandResult = createHandler().execute(command);
        Test.stopTest();

        Assert.areEqual(true, commandResult.success);
        Assert.areEqual(1, commandResult.conversion.convertedCount);

        Application__c convertedApplication = [
            SELECT Conversion_Status__c, Converted_At__c
            FROM Application__c
            WHERE Id = :application.Id
            LIMIT 1
        ];
        Assert.areEqual(FrameworkConstants.CONVERSION_STATUS_CONVERTED, convertedApplication.Conversion_Status__c);
        Assert.isNotNull(convertedApplication.Converted_At__c);

        Application_Record_Link__c link = [
            SELECT Conversion_Key__c, Role__c, SObject_Type__c, Record_Id__c
            FROM Application_Record_Link__c
            WHERE Application__c = :application.Id
            LIMIT 1
        ];
        Assert.areEqual('account', link.Conversion_Key__c);
        Assert.areEqual('PrimaryAccount', link.Role__c);
        Assert.areEqual('Account', link.SObject_Type__c);

        Id accountId = (Id) link.Record_Id__c;
        Account account = [
            SELECT Name
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        Assert.areEqual('Converted Test Account', account.Name);
    }

    @IsTest
    static void appliesMappingTransformBeforeWritingTargetField() {
        Application__c application = createCompletedApplication('convert-transform');
        insert new Application_Data__c(
            Application__c = application.Id,
            Step_Key__c = 'companyDetails',
            Key__c = 'company.name',
            Type__c = 'String',
            Value__c = 'converted transform account'
        );

        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.applicationIds = new List<String>{ String.valueOf(application.Id) };

        CommandResult commandResult = createHandler(new TransformDefinitionResolver()).execute(command);

        Assert.areEqual(true, commandResult.success);
        Assert.areEqual(0, commandResult.conversion.failedCount, String.join(commandResult.conversion.errors, '; '));
        Assert.areEqual(1, commandResult.conversion.convertedCount);

        Application_Record_Link__c link = [
            SELECT Record_Id__c
            FROM Application_Record_Link__c
            WHERE Application__c = :application.Id
            LIMIT 1
        ];
        Id accountId = (Id) link.Record_Id__c;
        Account account = [
            SELECT Name
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        Assert.areEqual('CONVERTED TRANSFORM ACCOUNT', account.Name);
    }

    @IsTest
    static void upsertsExistingRecordByMatchField() {
        Account existingAccount = new Account(
            Name = 'Existing Account',
            AccountNumber = 'ACC-100'
        );
        insert existingAccount;

        Application__c application = createCompletedApplication('convert-upsert');
        insert new List<Application_Data__c>{
            new Application_Data__c(
                Application__c = application.Id,
                Step_Key__c = 'companyDetails',
                Key__c = 'company.name',
                Type__c = 'String',
                Value__c = 'Updated Account'
            ),
            new Application_Data__c(
                Application__c = application.Id,
                Step_Key__c = 'companyDetails',
                Key__c = 'company.accountNumber',
                Type__c = 'String',
                Value__c = 'ACC-100'
            )
        };

        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.applicationIds = new List<String>{ String.valueOf(application.Id) };

        CommandResult commandResult = createHandler(new UpsertDefinitionResolver()).execute(command);

        Assert.areEqual(true, commandResult.success);
        Assert.areEqual(0, commandResult.conversion.failedCount, String.join(commandResult.conversion.errors, '; '));
        Assert.areEqual(1, commandResult.conversion.convertedCount);

        Account updatedAccount = [
            SELECT Name, AccountNumber
            FROM Account
            WHERE Id = :existingAccount.Id
            LIMIT 1
        ];
        Assert.areEqual('Updated Account', updatedAccount.Name);
        Assert.areEqual('ACC-100', updatedAccount.AccountNumber);

        Application_Record_Link__c link = [
            SELECT Record_Id__c
            FROM Application_Record_Link__c
            WHERE Application__c = :application.Id
            LIMIT 1
        ];
        Assert.areEqual(String.valueOf(existingAccount.Id), link.Record_Id__c);
    }

    @IsTest
    static void bulkUpsertCanUpdateAndInsertInOneBatch() {
        Account existingAccount = new Account(
            Name = 'Existing Bulk Account',
            AccountNumber = 'ACC-200'
        );
        insert existingAccount;

        Application__c updateApplication = createCompletedApplication('convert-bulk-update');
        Application__c insertApplication = createCompletedApplication('convert-bulk-insert');
        insert new List<Application_Data__c>{
            createData(updateApplication.Id, 'company.name', 'Updated Bulk Account'),
            createData(updateApplication.Id, 'company.accountNumber', 'ACC-200'),
            createData(insertApplication.Id, 'company.name', 'Inserted Bulk Account'),
            createData(insertApplication.Id, 'company.accountNumber', 'ACC-201')
        };

        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.applicationIds = new List<String>{
            String.valueOf(updateApplication.Id),
            String.valueOf(insertApplication.Id)
        };

        CommandResult commandResult = createHandler(new UpsertDefinitionResolver()).execute(command);

        Assert.areEqual(true, commandResult.success);
        Assert.areEqual(0, commandResult.conversion.failedCount, String.join(commandResult.conversion.errors, '; '));
        Assert.areEqual(2, commandResult.conversion.convertedCount);

        Account updatedAccount = [
            SELECT Name
            FROM Account
            WHERE Id = :existingAccount.Id
            LIMIT 1
        ];
        Assert.areEqual('Updated Bulk Account', updatedAccount.Name);

        Account insertedAccount = [
            SELECT Name
            FROM Account
            WHERE AccountNumber = 'ACC-201'
            LIMIT 1
        ];
        Assert.areEqual('Inserted Bulk Account', insertedAccount.Name);

        Integer links = [
            SELECT COUNT()
            FROM Application_Record_Link__c
            WHERE Application__c IN :new Set<Id>{ updateApplication.Id, insertApplication.Id }
        ];
        Assert.areEqual(2, links);
    }

    @IsTest
    static void dmlErrorsFailOnlyAffectedApplications() {
        Application__c validApplication = createCompletedApplication('convert-partial-valid');
        Application__c invalidApplication = createCompletedApplication('convert-partial-invalid');
        insert createData(validApplication.Id, 'company.name', 'Partially Converted Account');

        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.applicationIds = new List<String>{
            String.valueOf(validApplication.Id),
            String.valueOf(invalidApplication.Id)
        };

        CommandResult commandResult = createHandler().execute(command);

        Assert.areEqual(true, commandResult.success);
        Assert.areEqual(1, commandResult.conversion.convertedCount);
        Assert.areEqual(1, commandResult.conversion.failedCount);
        Assert.areEqual(1, commandResult.conversion.convertedApplicationIds.size());
        Assert.areEqual(1, commandResult.conversion.failedApplicationIds.size());
        Assert.areEqual(true, commandResult.conversion.errors[0].contains('account'));

        Map<Id, Application__c> applicationsById = new Map<Id, Application__c>([
            SELECT Conversion_Status__c
            FROM Application__c
            WHERE Id IN :new Set<Id>{ validApplication.Id, invalidApplication.Id }
        ]);
        Assert.areEqual(FrameworkConstants.CONVERSION_STATUS_CONVERTED, applicationsById.get(validApplication.Id).Conversion_Status__c);
        Assert.areEqual(FrameworkConstants.CONVERSION_STATUS_FAILED, applicationsById.get(invalidApplication.Id).Conversion_Status__c);

        Integer accounts = [
            SELECT COUNT()
            FROM Account
            WHERE Name = 'Partially Converted Account'
        ];
        Assert.areEqual(1, accounts);

        Integer links = [
            SELECT COUNT()
            FROM Application_Record_Link__c
            WHERE Application__c = :validApplication.Id
        ];
        Assert.areEqual(1, links);
    }

    @IsTest
    static void failedApplicationsAreNotRetriedByDefault() {
        Application__c application = createCompletedApplication('convert-failed-default');
        application.Conversion_Status__c = FrameworkConstants.CONVERSION_STATUS_FAILED;
        update application;

        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.applicationIds = new List<String>{ String.valueOf(application.Id) };

        CommandResult commandResult = createHandler().execute(command);

        Assert.areEqual(true, commandResult.success);
        Assert.areEqual(0, commandResult.conversion.requestedCount);
        Assert.areEqual(0, commandResult.conversion.convertedCount);
    }

    @IsTest
    static void retriesFailedApplicationWhenRequested() {
        Application__c application = createCompletedApplication('convert-failed-retry');
        application.Conversion_Status__c = FrameworkConstants.CONVERSION_STATUS_FAILED;
        update application;
        insert createData(application.Id, 'company.name', 'Retried Converted Account');

        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.applicationIds = new List<String>{ String.valueOf(application.Id) };
        command.retryFailed = true;

        CommandResult commandResult = createHandler().execute(command);

        Assert.areEqual(true, commandResult.success);
        Assert.areEqual(1, commandResult.conversion.requestedCount);
        Assert.areEqual(1, commandResult.conversion.convertedCount);
        Assert.areEqual(0, commandResult.conversion.failedCount, String.join(commandResult.conversion.errors, '; '));

        Application__c convertedApplication = [
            SELECT Conversion_Status__c
            FROM Application__c
            WHERE Id = :application.Id
            LIMIT 1
        ];
        Assert.areEqual(FrameworkConstants.CONVERSION_STATUS_CONVERTED, convertedApplication.Conversion_Status__c);
    }

    @IsTest
    static void retryUsesExistingRecordLinksInsteadOfCreatingDuplicates() {
        Application__c application = createCompletedApplication('convert-idempotent-retry');
        insert createData(application.Id, 'company.name', 'First Linked Account');

        ConvertApplicationsCommand firstCommand = new ConvertApplicationsCommand();
        firstCommand.consumerKey = 'webPortal';
        firstCommand.processKey = 'fuelCardApplication';
        firstCommand.applicationIds = new List<String>{ String.valueOf(application.Id) };

        CommandResult firstResult = createHandler(new AccountAndContactDefinitionResolver()).execute(firstCommand);

        Assert.areEqual(true, firstResult.success);
        Assert.areEqual(0, firstResult.conversion.convertedCount);
        Assert.areEqual(1, firstResult.conversion.failedCount);

        Application_Record_Link__c accountLink = [
            SELECT Record_Id__c
            FROM Application_Record_Link__c
            WHERE Application__c = :application.Id
            AND Conversion_Key__c = 'account'
            LIMIT 1
        ];
        insert createData(application.Id, 'contact.lastName', 'Retry Contact');

        ConvertApplicationsCommand retryCommand = new ConvertApplicationsCommand();
        retryCommand.consumerKey = 'webPortal';
        retryCommand.processKey = 'fuelCardApplication';
        retryCommand.applicationIds = new List<String>{ String.valueOf(application.Id) };
        retryCommand.retryFailed = true;

        CommandResult retryResult = createHandler(new AccountAndContactDefinitionResolver()).execute(retryCommand);

        Assert.areEqual(true, retryResult.success);
        Assert.areEqual(1, retryResult.conversion.convertedCount);
        Assert.areEqual(0, retryResult.conversion.failedCount, String.join(retryResult.conversion.errors, '; '));

        Integer accounts = [
            SELECT COUNT()
            FROM Account
            WHERE Name = 'First Linked Account'
        ];
        Assert.areEqual(1, accounts);

        Integer links = [
            SELECT COUNT()
            FROM Application_Record_Link__c
            WHERE Application__c = :application.Id
        ];
        Assert.areEqual(2, links);

        Application_Record_Link__c retriedAccountLink = [
            SELECT Record_Id__c
            FROM Application_Record_Link__c
            WHERE Application__c = :application.Id
            AND Conversion_Key__c = 'account'
            LIMIT 1
        ];
        Assert.areEqual(accountLink.Record_Id__c, retriedAccountLink.Record_Id__c);
    }

    @IsTest
    static void convertsDependentMappingsWithParentRecordReference() {
        Application__c application = createCompletedApplication('convert-dependent-contact');
        insert new List<Application_Data__c>{
            createData(application.Id, 'company.name', 'Dependent Account'),
            createData(application.Id, 'contact.lastName', 'Dependent Contact')
        };

        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';
        command.applicationIds = new List<String>{ String.valueOf(application.Id) };

        CommandResult commandResult = createHandler(new AccountAndContactDefinitionResolver()).execute(command);

        Assert.areEqual(true, commandResult.success);
        Assert.areEqual(1, commandResult.conversion.convertedCount);
        Assert.areEqual(0, commandResult.conversion.failedCount, String.join(commandResult.conversion.errors, '; '));

        Application_Record_Link__c accountLink = [
            SELECT Record_Id__c
            FROM Application_Record_Link__c
            WHERE Application__c = :application.Id
            AND Conversion_Key__c = 'account'
            LIMIT 1
        ];
        Application_Record_Link__c contactLink = [
            SELECT Record_Id__c
            FROM Application_Record_Link__c
            WHERE Application__c = :application.Id
            AND Conversion_Key__c = 'contact'
            LIMIT 1
        ];

        Id contactId = (Id) contactLink.Record_Id__c;
        Contact contact = [
            SELECT LastName, AccountId
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        Assert.areEqual('Dependent Contact', contact.LastName);
        Assert.areEqual((Id) accountLink.Record_Id__c, contact.AccountId);
    }

    @IsTest
    static void returnsEmptyResultWhenNoApplicationsAreReady() {
        ConvertApplicationsCommand command = new ConvertApplicationsCommand();
        command.consumerKey = 'webPortal';
        command.processKey = 'fuelCardApplication';

        CommandResult commandResult = createHandler().execute(command);

        Assert.areEqual(true, commandResult.success);
        Assert.areEqual(0, commandResult.conversion.requestedCount);
        Assert.areEqual(0, commandResult.conversion.convertedCount);
    }

    @IsTest
    static void parsesConvertCommandFromJson() {
        String requestBody = '{"consumerKey":"webPortal","processKey":"fuelCardApplication","applicationIds":["a00123456789012AAA"],"maxBatchSize":20,"retryFailed":true}';

        ConvertApplicationsCommand command = ConvertApplicationsCommand.fromJson(requestBody);

        Assert.areEqual('webPortal', command.consumerKey);
        Assert.areEqual('fuelCardApplication', command.processKey);
        Assert.areEqual(1, command.applicationIds.size());
        Assert.areEqual(20, command.getMaxBatchSize());
        Assert.areEqual(true, command.shouldRetryFailed());
    }

    @IsTest
    static void restControllerConvertsApplications() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/convert';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"consumerKey":"webPortal","processKey":"fuelCardApplication"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationConvertRestController.post();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(true, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('conversion'));
    }

    @IsTest
    static void restControllerReturnsErrorForInvalidCommand() {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/e2e/applications/convert';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"consumerKey":"webPortal"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        ApplicationConvertRestController.post();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Assert.areEqual(false, responseBody.get('success'));
        Assert.isNotNull(responseBody.get('errors'));
    }

    private static ConvertApplicationsHandler createHandler() {
        return createHandler(new TestDefinitionResolver());
    }

    private static ConvertApplicationsHandler createHandler(DefinitionResolver definitionResolver) {
        return new ConvertApplicationsHandler(
            definitionResolver,
            new ApplicationStateStore(),
            new ApplicationEventStore(),
            new ConsumerAccessService(),
            new MappingEngine()
        );
    }

    private static Application__c createCompletedApplication(String externalReference) {
        Application__c application = new Application__c(
            Process_Key__c = 'fuelCardApplication',
            Scenario_Key__c = 'newCustomer',
            Current_Step_Key__c = 'finish',
            Status__c = FrameworkConstants.APPLICATION_STATUS_COMPLETED,
            Conversion_Status__c = FrameworkConstants.CONVERSION_STATUS_READY,
            Consumer_Key__c = 'webPortal',
            External_Reference__c = externalReference,
            Definition_Version__c = '1.0.0',
            Started_At__c = System.now(),
            Completed_At__c = System.now()
        );
        insert application;
        return application;
    }

    private static Application_Data__c createData(Id applicationId, String key, String value) {
        return new Application_Data__c(
            Application__c = applicationId,
            Step_Key__c = 'companyDetails',
            Key__c = key,
            Type__c = 'String',
            Value__c = value
        );
    }

    private class TestDefinitionResolver extends DefinitionResolver {
        public override ProcessDefinition resolveActive(String processKey) {
            return ProcessDefinition.parse(
                '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{},"finish":{"type":"finish"}},"rules":{},"jobs":{},"mappings":{"account":{"role":"PrimaryAccount","targetObject":"Account","operation":"insert","fields":[{"target":"Name","source":"company.name"}]}}}'
            );
        }
    }

    private class TransformDefinitionResolver extends DefinitionResolver {
        public override ProcessDefinition resolveActive(String processKey) {
            return ProcessDefinition.parse(
                '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{},"finish":{"type":"finish"}},"rules":{},"jobs":{},"mappings":{"account":{"role":"PrimaryAccount","targetObject":"Account","operation":"insert","fields":[{"target":"Name","source":"company.name","transformClass":"TestUppercaseMappingTransform"}]}}}'
            );
        }
    }

    private class UpsertDefinitionResolver extends DefinitionResolver {
        public override ProcessDefinition resolveActive(String processKey) {
            return ProcessDefinition.parse(
                '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{},"finish":{"type":"finish"}},"rules":{},"jobs":{},"mappings":{"account":{"role":"PrimaryAccount","targetObject":"Account","operation":"upsert","match":{"field":"AccountNumber","source":"company.accountNumber"},"fields":[{"target":"Name","source":"company.name"}]}}}'
            );
        }
    }

    private class AccountAndContactDefinitionResolver extends DefinitionResolver {
        public override ProcessDefinition resolveActive(String processKey) {
            return ProcessDefinition.parse(
                '{"process":{"key":"fuelCardApplication","version":"1.0.0"},"scenarios":{"newCustomer":{"initialStep":"contactDetails","steps":["contactDetails","finish"]}},"steps":{"contactDetails":{},"finish":{"type":"finish"}},"rules":{},"jobs":{},"mappings":{"account":{"role":"PrimaryAccount","targetObject":"Account","operation":"insert","fields":[{"target":"Name","source":"company.name"}]},"contact":{"role":"PrimaryContact","targetObject":"Contact","operation":"insert","dependsOn":["account"],"fields":[{"target":"LastName","source":"contact.lastName"},{"target":"AccountId","fromRecord":"account"}]}}}'
            );
        }
    }
}
