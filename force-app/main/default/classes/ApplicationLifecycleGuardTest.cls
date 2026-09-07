@IsTest
private class ApplicationLifecycleGuardTest {
    @IsTest
    static void allowsActiveApplicationTransitionToCompleted() {
        Application__c application = createApplication(FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS);

        Assert.areEqual(
            true,
            ApplicationLifecycleGuard.canTransition(application.Status__c, FrameworkConstants.APPLICATION_STATUS_COMPLETED)
        );

        ApplicationLifecycleGuard.requireTransition(
            application,
            FrameworkConstants.APPLICATION_STATUS_COMPLETED,
            'Complete Application'
        );
    }

    @IsTest
    static void rejectsTransitionFromTerminalStatus() {
        Application__c application = createApplication(FrameworkConstants.APPLICATION_STATUS_COMPLETED);

        Assert.areEqual(
            false,
            ApplicationLifecycleGuard.canTransition(application.Status__c, FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS)
        );

        try {
            ApplicationLifecycleGuard.requireMutable(application, 'Submit Step');
            Assert.fail('Expected terminal Application to be immutable.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains(FrameworkConstants.APPLICATION_STATUS_COMPLETED));
        }
    }

    @IsTest
    static void supportsReservedDraftAndWaitingTransitions() {
        Assert.areEqual(
            true,
            ApplicationLifecycleGuard.canTransition(
                FrameworkConstants.APPLICATION_STATUS_DRAFT,
                FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS
            )
        );
        Assert.areEqual(
            true,
            ApplicationLifecycleGuard.canTransition(
                FrameworkConstants.APPLICATION_STATUS_DRAFT,
                FrameworkConstants.APPLICATION_STATUS_CANCELLED
            )
        );
        Assert.areEqual(
            true,
            ApplicationLifecycleGuard.canTransition(
                FrameworkConstants.APPLICATION_STATUS_DRAFT,
                FrameworkConstants.APPLICATION_STATUS_EXPIRED
            )
        );
        Assert.areEqual(
            true,
            ApplicationLifecycleGuard.canTransition(
                FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS,
                FrameworkConstants.APPLICATION_STATUS_WAITING_FOR_JOBS
            )
        );
        Assert.areEqual(
            true,
            ApplicationLifecycleGuard.canTransition(
                FrameworkConstants.APPLICATION_STATUS_WAITING_FOR_JOBS,
                FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS
            )
        );
        Assert.areEqual(
            true,
            ApplicationLifecycleGuard.canTransition(
                FrameworkConstants.APPLICATION_STATUS_WAITING_FOR_JOBS,
                FrameworkConstants.APPLICATION_STATUS_CANCELLED
            )
        );
    }

    @IsTest
    static void rejectsUnknownAndBlankTransitions() {
        Assert.areEqual(false, ApplicationLifecycleGuard.canTransition(null, FrameworkConstants.APPLICATION_STATUS_COMPLETED));
        Assert.areEqual(false, ApplicationLifecycleGuard.canTransition('', FrameworkConstants.APPLICATION_STATUS_COMPLETED));
        Assert.areEqual(false, ApplicationLifecycleGuard.canTransition(FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS, null));
        Assert.areEqual(false, ApplicationLifecycleGuard.canTransition('Unknown', FrameworkConstants.APPLICATION_STATUS_COMPLETED));

        Application__c application = createApplication(FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS);
        try {
            ApplicationLifecycleGuard.requireTransition(application, 'Unknown', 'Move Application');
            Assert.fail('Expected unknown target transition to fail.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('cannot move Application'));
        }
    }

    @IsTest
    static void rejectsMissingApplication() {
        try {
            ApplicationLifecycleGuard.requireMutable(null, 'Submit Step');
            Assert.fail('Expected missing Application to fail.');
        } catch (FrameworkException ex) {
            Assert.areEqual('Application is required.', ex.getMessage());
        }
    }

    @IsTest
    static void storeRejectsConversionBeforeApplicationCompleted() {
        Application__c application = createApplication(FrameworkConstants.APPLICATION_STATUS_IN_PROGRESS);
        application.Conversion_Status__c = FrameworkConstants.CONVERSION_STATUS_READY;

        try {
            new ApplicationStateStore().markApplicationsConverting(new List<Application__c>{ application });
            Assert.fail('Expected conversion to require Completed Application.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('must be Completed before conversion'));
        }
    }

    @IsTest
    static void storeAllowsReadyToConvertedConversionFlow() {
        Application__c application = createApplication(FrameworkConstants.APPLICATION_STATUS_COMPLETED);
        application.Conversion_Status__c = FrameworkConstants.CONVERSION_STATUS_READY;
        update application;

        ApplicationStateStore stateStore = new ApplicationStateStore();

        Test.startTest();
        stateStore.markApplicationsConverting(new List<Application__c>{ application });
        stateStore.markApplicationsConverted(new List<Application__c>{ application });
        Test.stopTest();

        Application__c updatedApplication = [
            SELECT Conversion_Status__c, Converted_At__c
            FROM Application__c
            WHERE Id = :application.Id
            LIMIT 1
        ];
        Assert.areEqual(FrameworkConstants.CONVERSION_STATUS_CONVERTED, updatedApplication.Conversion_Status__c);
        Assert.isNotNull(updatedApplication.Converted_At__c);
    }

    @IsTest
    static void storeRejectsInvalidConversionTransition() {
        Application__c application = createApplication(FrameworkConstants.APPLICATION_STATUS_COMPLETED);
        application.Conversion_Status__c = FrameworkConstants.CONVERSION_STATUS_CONVERTED;
        update application;

        try {
            new ApplicationStateStore().markApplicationsConverting(new List<Application__c>{ application });
            Assert.fail('Expected converted Application to reject conversion restart.');
        } catch (FrameworkException ex) {
            Assert.isTrue(ex.getMessage().contains('Conversion cannot move'));
        }
    }

    private static Application__c createApplication(String status) {
        Application__c application = new Application__c(
            Process_Key__c = 'fuelCardApplication',
            Scenario_Key__c = 'newCustomer',
            Current_Step_Key__c = 'contactDetails',
            Status__c = status,
            Conversion_Status__c = FrameworkConstants.CONVERSION_STATUS_NOT_READY,
            Consumer_Key__c = 'webPortal',
            External_Reference__c = 'lifecycle-' + String.valueOf(Crypto.getRandomInteger()),
            Definition_Version__c = '1.0.0',
            Started_At__c = System.now()
        );
        insert application;
        return application;
    }
}
