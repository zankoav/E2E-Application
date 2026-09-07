public inherited sharing class ApplicationLifecycleGuard {
    public static void requireMutable(Application__c application, String operationName) {
        requireApplication(application);
        if (isTerminal(application.Status__c)) {
            throw new FrameworkException(operationName + ' is not allowed for Application status: ' + application.Status__c);
        }
    }

    public static void requireTransition(Application__c application, String targetStatus, String operationName) {
        requireApplication(application);
        if (!canTransition(application.Status__c, targetStatus)) {
            throw new FrameworkException(
                operationName + ' cannot move Application from ' + application.Status__c + ' to ' + targetStatus + '.'
            );
        }
    }

    public static Boolean canTransition(String currentStatus, String targetStatus) {
        if (String.isBlank(currentStatus) || String.isBlank(targetStatus)) {
            return false;
        }
        if (currentStatus == targetStatus) {
            return true;
        }
        if (isTerminal(currentStatus)) {
            return false;
        }
        if (currentStatus == FrameworkConstants.APPLICATION_STATUS_DRAFT) {
            return targetStatus == FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS ||
                targetStatus == FrameworkConstants.APPLICATION_STATUS_CANCELLED ||
                targetStatus == FrameworkConstants.APPLICATION_STATUS_EXPIRED;
        }
        if (currentStatus == FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS) {
            return targetStatus == FrameworkConstants.APPLICATION_STATUS_WAITING_FOR_JOBS ||
                targetStatus == FrameworkConstants.APPLICATION_STATUS_COMPLETED ||
                targetStatus == FrameworkConstants.APPLICATION_STATUS_CANCELLED ||
                targetStatus == FrameworkConstants.APPLICATION_STATUS_EXPIRED;
        }
        if (currentStatus == FrameworkConstants.APPLICATION_STATUS_WAITING_FOR_JOBS) {
            return targetStatus == FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS ||
                targetStatus == FrameworkConstants.APPLICATION_STATUS_COMPLETED ||
                targetStatus == FrameworkConstants.APPLICATION_STATUS_CANCELLED ||
                targetStatus == FrameworkConstants.APPLICATION_STATUS_EXPIRED;
        }
        return false;
    }

    public static Boolean isTerminal(String status) {
        return status == FrameworkConstants.APPLICATION_STATUS_COMPLETED ||
            status == FrameworkConstants.APPLICATION_STATUS_CANCELLED ||
            status == FrameworkConstants.APPLICATION_STATUS_EXPIRED;
    }

    private static void requireApplication(Application__c application) {
        if (application == null || application.Id == null) {
            throw new FrameworkException('Application is required.');
        }
    }
}
