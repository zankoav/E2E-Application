# Process Definition Shape

## Purpose

`Process_Definition__mdt.Definition_JSON__c` stores the developer-friendly definition body for an E2E process version.

Custom Metadata is the Salesforce-native container. JSON is the process definition body.

## Top-Level Shape

```json
{
  "process": {
    "key": "fuelCardApplication",
    "label": "Fuel Card Application",
    "version": "1.0.0"
  },
  "scenarios": {},
  "steps": {},
  "rules": {},
  "jobs": {},
  "integrations": {},
  "mappings": {},
  "stopProcesses": {}
}
```

## Process

Defines the process identity.

```json
{
  "process": {
    "key": "fuelCardApplication",
    "label": "Fuel Card Application",
    "version": "1.0.0"
  }
}
```

`process.key` should match `Process_Definition__mdt.Process_Key__c`.

## Scenarios

Scenarios define variants of the process.

```json
{
  "scenarios": {
    "newCustomer": {
      "label": "New Customer",
      "initialStep": "contactDetails",
      "steps": [
        "contactDetails",
        "companyDetails",
        "productSelection",
        "checkout",
        "finish"
      ]
    },
    "mobileShortFlow": {
      "label": "Mobile Short Flow",
      "consumerKeys": ["mobileApp"],
      "initialStep": "contactDetails",
      "steps": [
        "contactDetails",
        "checkout",
        "finish"
      ]
    }
  }
}
```

A scenario can have a different step list, step order, rules, jobs, mappings, and consumer restrictions.

## Steps

Steps define process stages.

```json
{
  "steps": {
    "contactDetails": {
      "label": "Contact Details",
      "type": "standard",
      "required": true,
      "dataKeys": [
        "contact.email",
        "contact.phone"
      ],
      "availabilityRules": [],
      "validationRules": [
        "contactEmailRequired"
      ],
      "jobTriggerRules": [
        "runEmailValidationWhenEmailChanged"
      ],
      "transitionRules": [
        "contactDetailsCanMoveNext"
      ],
      "allowedStopProcesses": []
    }
  }
}
```

Step can be required, optional, or conditional.

Active Stop Processes block step transition by default. `allowedStopProcesses` explicitly lists stop process codes that this step transition can pass.

## Rules

Rules make decisions during the application lifecycle.

```json
{
  "rules": {
    "contactEmailRequired": {
      "type": "validation",
      "class": "ContactEmailRequiredRule",
      "blocking": true
    },
    "runEmailValidationWhenEmailChanged": {
      "type": "jobTrigger",
      "jobKey": "emailValidation",
      "when": {
        "dataChanged": ["contact.email"]
      }
    },
    "contactDetailsCanMoveNext": {
      "type": "stepTransition",
      "requiresJobs": [
        {
          "jobKey": "emailValidation",
          "status": "Completed"
        }
      ]
    }
  }
}
```

Rule definitions can be declarative or can reference custom Apex extension classes.

## Jobs

Jobs define backend work.

```json
{
  "jobs": {
    "emailValidation": {
      "label": "Email Validation",
      "executorClass": "EmailValidationJobExecutor",
      "executionMode": "syncCallout",
      "canBeRestarted": true,
      "dependsOn": []
    },
    "syncApplicationData": {
      "label": "Sync Application Data",
      "executorClass": "SyncApplicationDataJobExecutor",
      "executionMode": "async",
      "canBeRestarted": false,
      "dependsOn": ["emailValidation"]
    }
  }
}
```

Job dependencies define execution order and transition requirements.

## Integrations

Integrations define reusable adapter references.

```json
{
  "integrations": {
    "emailProvider": {
      "definitionKey": "emailProvider",
      "adapterClass": "EmailProviderIntegrationAdapter"
    }
  }
}
```

Integration can perform callouts or Salesforce reads, but should not perform DML or change Application State.

## Mappings

Mappings describe how Application data becomes CRM records.

```json
{
  "mappings": {
    "account": {
      "scenarioKeys": ["newCustomer"],
      "targetObject": "Account",
      "operation": "upsert",
      "match": {
        "field": "VAT_Number__c",
        "source": "company.vatNumber"
      },
      "fields": [
        {
          "target": "Name",
          "source": "company.name"
        },
        {
          "target": "Phone",
          "source": "contact.phone"
        }
      ]
    }
  }
}
```

Mapping without `scenarioKeys` applies to all scenarios in the process.

Mapping with `scenarioKeys` applies only to those scenarios.

Conversion executes mappings in bulk.

## Stop Processes

Stop Processes define known stop conditions.

```json
{
  "stopProcesses": {
    "DUPLICATE_CUSTOMER": {
      "label": "Duplicate Customer",
      "type": "ManualUnlockRequired",
      "defaultBlocking": true
    }
  }
}
```

Stop Processes are active on Application State. Step Transition Rules decide whether a specific transition can pass them.

Runtime state is stored in `Application_Stop_Process__c`.

Strict policy:

```text
active Stop Processes block transition by default
allowedStopProcesses explicitly lists codes that the current step transition can pass
resolved Stop Processes are returned only for audit/support, not as active blockers
```

## Guiding Principle

The process definition should describe behavior.

The closed core should execute behavior.

Subscriber extensions should provide custom logic only through documented contracts.
