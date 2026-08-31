# Core Object Model

## Decision

Use a hybrid Salesforce persistence model.

`Application__c` is the root process record. Related records store dynamic data, jobs, events, and conversion links.

## Main Objects

| Object | Purpose |
| --- | --- |
| `Application__c` | Root E2E process instance and lifecycle owner. |
| `Application_Data__c` | Dynamic collected process data. |
| `Application_Job__c` | Job instances and status lifecycle. |
| `Application_Event__c` | Audit/debug event history. |
| `Application_Record_Link__c` | Links from Application to created or updated CRM records. |

## Application__c

`Application__c` stores stable identity and lifecycle fields.

Initial fields:

| Field | Purpose |
| --- | --- |
| `Name` | Human-readable application number/name. |
| `Process_Key__c` | Process definition key. |
| `Scenario_Key__c` | Scenario definition key. |
| `Current_Step_Key__c` | Current step in the process. |
| `Status__c` | Application lifecycle status. |
| `Conversion_Status__c` | Conversion lifecycle status. |
| `Consumer_Key__c` | Trusted consumer that initialized the application. |
| `External_Reference__c` | Optional external id/reference from consumer. |
| `Definition_Version__c` | Definition version used by this application. |
| `Started_At__c` | When the application was initialized. |
| `Completed_At__c` | When the application reached final immutable state. |
| `Converted_At__c` | When conversion finished successfully. |

## Application_Data__c

Stores dynamic process data by logical keys.

The API should use stable contract keys, not Salesforce field API names.

Example keys:

```text
company.name
company.vatNumber
contact.email
payment.method
products.items
```

Possible fields:

| Field | Purpose |
| --- | --- |
| `Application__c` | Parent application. |
| `Key__c` | Logical data key. |
| `Value__c` | Stored value for simple values. |
| `Value_JSON__c` | Stored JSON for complex values. |
| `Type__c` | Value type. |
| `Step_Key__c` | Step that collected or last changed the value. |

## Application_Job__c

Stores concrete job instances.

Possible fields:

| Field | Purpose |
| --- | --- |
| `Application__c` | Parent application. |
| `Job_Key__c` | Unique job instance key. |
| `Job_Name__c` | Clean job name/definition key. |
| `Source_Step_Key__c` | Step that triggered the job. |
| `Status__c` | Job status. |
| `Execution_Mode__c` | `sync`, `syncCallout`, or `async`. |
| `Can_Be_Restarted__c` | Whether retries are allowed. |
| `External_Job_Id__c` | Async/platform job id when applicable. |
| `Error_Code__c` | Structured error code. |
| `Error_Message__c` | Structured error message. |

## Application_Event__c

Stores audit and debug history.

Events make support/debugging easier without reading every object manually.

Example event types:

```text
ApplicationInitialized
StepSubmitted
StateChanged
JobQueued
JobStarted
JobCompleted
JobFailed
StopProcessActivated
FinalSubmitRequested
ApplicationFinished
ConversionStarted
ConversionCompleted
ConversionFailed
```

## Application_Record_Link__c

Stores links to CRM records created or updated by Conversion.

This keeps the framework generic. The core does not need hardcoded lookup fields for every possible CRM object.

Possible fields:

| Field | Purpose |
| --- | --- |
| `Application__c` | Parent application. |
| `Role__c` | Business role, for example `PrimaryAccount` or `MainOpportunity`. |
| `SObject_Type__c` | Target Salesforce object API name. |
| `Record_Id__c` | Target record id. |
| `Conversion_Key__c` | Mapping/conversion step that produced the link. |

## Definition Objects

Definitions describe how processes work.

Use Custom Metadata as Salesforce-native definition containers and JSON as the developer-friendly definition body.

This keeps definitions easy to deploy, query, cache, and package without losing the convenience of current JSON-based development.

Initial definition containers:

| Definition | Purpose |
| --- | --- |
| `Process_Definition__mdt` | Defines a process version. Contains scenario, step, rule, job, stop process, and mapping definitions in JSON. |
| `Consumer_Definition__mdt` | Defines trusted API consumers and allowed processes/scenarios. |
| `Integration_Definition__mdt` | Defines reusable integration adapter settings such as adapter class and named credential. |

Possible `Process_Definition__mdt` fields:

| Field | Purpose |
| --- | --- |
| `Process_Key__c` | Stable process key. |
| `Version__c` | Definition version. |
| `Active__c` | Whether this definition version is active. |
| `Definition_JSON__c` | Full process definition body. |
| `Description__c` | Human-readable description. |

`Definition_JSON__c` can contain:

```text
scenarios
steps
rules
jobs
mappings
stop process policies
```

Definitions should be validated by an Apex validator before use.

## Guiding Principle

Application records store runtime state.

Definition records describe process behavior.

CRM records are conversion results.
