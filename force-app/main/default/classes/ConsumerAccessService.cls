public inherited sharing class ConsumerAccessService {
    private ConsumerDefinitionResolver resolver;

    public ConsumerAccessService() {
        this(new ConsumerDefinitionResolver());
    }

    @TestVisible
    private ConsumerAccessService(ConsumerDefinitionResolver resolver) {
        this.resolver = resolver == null ? new ConsumerDefinitionResolver() : resolver;
    }

    public ConsumerDefinition validateInitAccess(
        String consumerKey,
        String processKey,
        String scenarioKey,
        ProcessDefinition.ScenarioDefinition scenario
    ) {
        if (scenario == null) {
            throw new FrameworkException('Scenario was not found. Scenario: ' + scenarioKey);
        }

        ConsumerDefinition consumer = resolver.resolveActive(consumerKey);
        validateRequestOrigin(consumer);
        if (!consumer.canAccessProcess(processKey)) {
            throw new FrameworkException('Consumer is not allowed for Process. Consumer: ' + consumerKey + ', Process: ' + processKey);
        }
        if (!consumer.canAccessScenario(processKey, scenarioKey)) {
            throw new FrameworkException('Consumer is not allowed for Scenario. Consumer: ' + consumerKey + ', Scenario: ' + scenarioKey);
        }
        if (!scenario.consumerKeys.isEmpty() && !scenario.consumerKeys.contains(consumerKey)) {
            throw new FrameworkException('Consumer is not allowed for Scenario. Consumer: ' + consumerKey + ', Scenario: ' + scenarioKey);
        }
        return consumer;
    }

    public void validateApplicationAccess(String consumerKey, Application__c application) {
        if (application == null) {
            throw new FrameworkException('Application is required.');
        }
        if (application.Consumer_Key__c != consumerKey) {
            throw new FrameworkException('Consumer is not allowed for Application.');
        }

        ConsumerDefinition consumer = resolver.resolveActive(consumerKey);
        validateRequestOrigin(consumer);
        if (!consumer.canAccessProcess(application.Process_Key__c)) {
            throw new FrameworkException('Consumer is not allowed for Process. Consumer: ' + consumerKey + ', Process: ' + application.Process_Key__c);
        }
        if (!consumer.canAccessScenario(application.Process_Key__c, application.Scenario_Key__c)) {
            throw new FrameworkException('Consumer is not allowed for Scenario. Consumer: ' + consumerKey + ', Scenario: ' + application.Scenario_Key__c);
        }
    }

    public void validateProcessAccess(String consumerKey, String processKey) {
        ConsumerDefinition consumer = resolver.resolveActive(consumerKey);
        validateRequestOrigin(consumer);
        if (!consumer.canAccessProcess(processKey)) {
            throw new FrameworkException('Consumer is not allowed for Process. Consumer: ' + consumerKey + ', Process: ' + processKey);
        }
    }

    private void validateRequestOrigin(ConsumerDefinition consumer) {
        String origin = getRequestOrigin();
        if (String.isBlank(origin)) {
            return;
        }
        if (!consumer.canAccessOrigin(origin)) {
            throw new FrameworkException('Consumer Origin is not allowed. Origin: ' + origin);
        }
    }

    private String getRequestOrigin() {
        if (RestContext.request == null || RestContext.request.headers == null) {
            return null;
        }
        return RestContext.request.headers.get('Origin');
    }
}
