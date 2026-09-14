public without sharing class PublicApplicationAccessService {
    private ApplicationStateStore stateStore;

    public class AccessGrant {
        public String resumeToken;
        public Datetime expiresAt;
    }

    public PublicApplicationAccessService() {
        this(new ApplicationStateStore());
    }

    @TestVisible
    private PublicApplicationAccessService(ApplicationStateStore stateStore) {
        this.stateStore = stateStore == null ? new ApplicationStateStore() : stateStore;
    }

    public Boolean isPublicAccessRequired() {
        return UserInfo.getUserType() == 'Guest';
    }

    public Application__c findExistingApplication(InitApplicationCommand command) {
        if (command == null || String.isBlank(command.externalReference)) {
            return null;
        }

        List<Application__c> applications = [
            SELECT Id, Name, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Status__c,
                Conversion_Status__c, Consumer_Key__c, External_Reference__c, Definition_Version__c,
                Started_At__c, Completed_At__c, Converted_At__c, Public_Access_Key_Hash__c,
                Public_Access_Expires_At__c, Public_Access_Max_Expires_At__c, Public_Access_Last_Used_At__c
            FROM Application__c
            WHERE Process_Key__c = :command.processKey
            AND Scenario_Key__c = :command.scenarioKey
            AND Consumer_Key__c = :command.consumerKey
            AND External_Reference__c = :command.externalReference
            LIMIT 1
        ];

        return applications.isEmpty() ? null : applications[0];
    }

    public Application__c getApplication(Id applicationId) {
        if (applicationId == null) {
            throw new FrameworkException('Application id is required.');
        }

        List<Application__c> applications = [
            SELECT Id, Name, Process_Key__c, Scenario_Key__c, Current_Step_Key__c, Status__c,
                Conversion_Status__c, Consumer_Key__c, External_Reference__c, Definition_Version__c,
                Started_At__c, Completed_At__c, Converted_At__c, Public_Access_Key_Hash__c,
                Public_Access_Expires_At__c, Public_Access_Max_Expires_At__c, Public_Access_Last_Used_At__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        if (applications.isEmpty()) {
            throw new FrameworkException('Application was not found. Id: ' + String.valueOf(applicationId));
        }
        return applications[0];
    }

    public void requirePublicInitAllowed(ProcessDefinition.ScenarioDefinition scenario) {
        if (isPublicAccessRequired() && !isPublicAccessEnabled(scenario)) {
            throw new FrameworkException('Public access is not enabled for Scenario. Scenario: ' + getScenarioKey(scenario));
        }
    }

    public Id getPublicApplicationOwnerId(ConsumerDefinition consumer) {
        if (!isPublicAccessRequired()) {
            return null;
        }
        if (consumer == null || String.isBlank(consumer.applicationOwnerUsername)) {
            throw new FrameworkException('Public Application owner username is required for Consumer.');
        }

        List<User> owners = [
            SELECT Id, UserType
            FROM User
            WHERE Username = :consumer.applicationOwnerUsername
            AND IsActive = true
            LIMIT 1
        ];
        if (owners.isEmpty()) {
            throw new FrameworkException('Public Application owner user was not found or is inactive. Username: ' + consumer.applicationOwnerUsername);
        }
        if (owners[0].UserType == 'Guest') {
            throw new FrameworkException('Public Application owner cannot be a Guest User.');
        }
        return owners[0].Id;
    }

    public Application__c initPublicApplication(InitApplicationCommand command, ProcessDefinition definition, Id ownerId) {
        ProcessDefinition.ScenarioDefinition scenario = definition.getScenario(command.scenarioKey);
        if (scenario == null) {
            throw new FrameworkException('Scenario was not found. Scenario: ' + command.scenarioKey);
        }
        if (ownerId == null) {
            throw new FrameworkException('Public Application owner is required.');
        }

        Application__c application = new Application__c();
        application.OwnerId = ownerId;
        application.Process_Key__c = command.processKey;
        application.Scenario_Key__c = command.scenarioKey;
        application.Current_Step_Key__c = scenario.initialStep;
        application.Status__c = FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS;
        application.Conversion_Status__c = FrameworkConstants.CONVERSION_STATUS_NOT_READY;
        application.Consumer_Key__c = command.consumerKey;
        application.External_Reference__c = command.externalReference;
        application.Definition_Version__c = definition.version;
        application.Started_At__c = System.now();
        insert application;
        return application;
    }

    public AccessGrant issue(Application__c application, ProcessDefinition.ScenarioDefinition scenario) {
        if (!isPublicAccessEnabled(scenario)) {
            return null;
        }

        Datetime nowValue = System.now();
        String resumeToken = generateResumeToken();
        application.Public_Access_Key_Hash__c = hashToken(resumeToken);
        application.Public_Access_Last_Used_At__c = nowValue;
        application.Public_Access_Expires_At__c = nowValue.addMinutes(scenario.publicAccess.idleTimeoutMinutes);
        application.Public_Access_Max_Expires_At__c = nowValue.addMinutes(scenario.publicAccess.maxLifetimeMinutes);
        savePublicAccess(application);

        AccessGrant grant = new AccessGrant();
        grant.resumeToken = resumeToken;
        grant.expiresAt = application.Public_Access_Expires_At__c;
        return grant;
    }

    public AccessGrant validateAndRefresh(
        Application__c application,
        ProcessDefinition.ScenarioDefinition scenario,
        String resumeToken
    ) {
        Boolean shouldValidate = isPublicAccessRequired() || !String.isBlank(resumeToken);
        if (!shouldValidate) {
            return null;
        }
        if (!isPublicAccessEnabled(scenario)) {
            throw new FrameworkException('Public access is not enabled for Scenario. Scenario: ' + getScenarioKey(scenario));
        }
        if (String.isBlank(resumeToken)) {
            throw new FrameworkException('Application resume token is required.');
        }
        if (application == null || String.isBlank(application.Public_Access_Key_Hash__c)) {
            throw new FrameworkException('Application public access token was not issued.');
        }
        if (application.Public_Access_Key_Hash__c != hashToken(resumeToken)) {
            throw new FrameworkException('Application resume token is invalid.');
        }

        Datetime nowValue = System.now();
        if (application.Public_Access_Expires_At__c == null || application.Public_Access_Expires_At__c <= nowValue) {
            throw new FrameworkException('Application resume token is expired.');
        }
        if (application.Public_Access_Max_Expires_At__c == null || application.Public_Access_Max_Expires_At__c <= nowValue) {
            throw new FrameworkException('Application resume token max lifetime is expired.');
        }

        Datetime refreshedExpiresAt = nowValue.addMinutes(scenario.publicAccess.idleTimeoutMinutes);
        if (refreshedExpiresAt > application.Public_Access_Max_Expires_At__c) {
            refreshedExpiresAt = application.Public_Access_Max_Expires_At__c;
        }

        application.Public_Access_Last_Used_At__c = nowValue;
        application.Public_Access_Expires_At__c = refreshedExpiresAt;
        savePublicAccess(application);

        AccessGrant grant = new AccessGrant();
        grant.expiresAt = application.Public_Access_Expires_At__c;
        return grant;
    }

    private Boolean isPublicAccessEnabled(ProcessDefinition.ScenarioDefinition scenario) {
        return scenario != null && scenario.publicAccess != null && scenario.publicAccess.enabled == true;
    }

    private String getScenarioKey(ProcessDefinition.ScenarioDefinition scenario) {
        return scenario == null ? null : scenario.key;
    }

    @TestVisible
    private String generateResumeToken() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(256));
    }

    @TestVisible
    private String hashToken(String resumeToken) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(resumeToken)));
    }

    private void savePublicAccess(Application__c application) {
        update new Application__c(
            Id = application.Id,
            Public_Access_Key_Hash__c = application.Public_Access_Key_Hash__c,
            Public_Access_Expires_At__c = application.Public_Access_Expires_At__c,
            Public_Access_Max_Expires_At__c = application.Public_Access_Max_Expires_At__c,
            Public_Access_Last_Used_At__c = application.Public_Access_Last_Used_At__c
        );
    }
}
