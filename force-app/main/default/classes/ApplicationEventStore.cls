public inherited sharing class ApplicationEventStore {
    public void createEvent(Id applicationId, String eventType, String message, Object details) {
        if (applicationId == null || String.isBlank(eventType)) {
            return;
        }

        Application_Event__c event = new Application_Event__c();
        event.Application__c = applicationId;
        event.Event_Type__c = eventType;
        event.Message__c = message;
        event.Occurred_At__c = System.now();
        if (details != null) {
            event.Details_JSON__c = JSON.serialize(details);
        }
        insert event;
    }
}
