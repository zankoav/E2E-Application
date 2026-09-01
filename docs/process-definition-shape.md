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

`consumerKeys` is an optional scenario-level restriction.

The primary trusted consumer boundary is `Consumer_Definition__mdt`. Scenario `consumerKeys` can narrow access for a specific scenario after the consumer has already been recognized as active and trusted.

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

`availabilityRules` control whether a step is available, locked, skipped, or hidden for the current Application State.

Availability rule block codes have framework meaning:

| Code | Runtime meaning |
| --- | --- |
| `LOCKED` | Show the Step but do not allow transition into it. |
| `SKIPPED` | Do not enter this Step for the current Application State. |
| `HIDDEN` | Do not show or enter this Step for the current Application State. |

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

## Definition Validation

Process Definition is validated before runtime commands use it.

Validation checks:

- process key and version
- scenario initial step and scenario step list
- scenario references to existing steps
- step references to existing availability, validation, and transition rules
- job trigger rules have `jobKey`
- job trigger rules reference existing jobs
- job `executionMode` is one of `sync`, `syncCallout`, or `async`

This validation is a package guardrail. Broken configuration should fail early, before Application State is changed by a runtime command.

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
      "adapterClass": "EmailProviderIntegrationAdapter",
      "namedCredential": "EmailProvider",
      "settings": {
        "timeoutMs": 5000
      }
    }
  }
}
```

Integration can perform callouts or Salesforce reads, but should not perform DML or change Application State.

If `definitionKey` is present, the framework loads `Integration_Definition__mdt` first and then applies process-level overrides.

If `adapterClass` is omitted, `DefaultIntegrationAdapter` is used.

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
          "source": "company.name",
          "transformClass": "CompanyNameMappingTransform"
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

Initial skeleton supports `insert` mappings.

`upsert` mappings use `match.field` and `match.source` to find an existing record. If a match is found, Conversion updates it. If not, Conversion inserts a new record.

This is framework-controlled match behavior. `match.field` does not have to be a Salesforce External Id field in the initial skeleton.

Mappings can depend on other mappings.

Use `dependsOn` when a target record needs another mapped record to be saved first.

Use field-level `fromRecord` to copy the saved parent record Id into a lookup field:

```json
{
  "mappings": {
    "account": {
      "role": "PrimaryAccount",
      "targetObject": "Account",
      "operation": "insert",
      "fields": [
        {
          "target": "Name",
          "source": "company.name"
        }
      ]
    },
    "contact": {
      "role": "PrimaryContact",
      "targetObject": "Contact",
      "operation": "insert",
      "dependsOn": ["account"],
      "fields": [
        {
          "target": "LastName",
          "source": "contact.lastName"
        },
        {
          "target": "AccountId",
          "fromRecord": "account"
        }
      ]
    }
  }
}
```

If a field uses `fromRecord`, the referenced mapping must also be listed in `dependsOn`.

Conversion executes mappings in bulk and stores created record ids in `Application_Record_Link__c`.

Definition Validation checks mapping target object, operation, and field mappings before runtime conversion.

`transformClass` is optional. When present, the class must implement `MappingTransform`.

Mapping Transform receives `MappingTransformContext` and returns the final value for the target field.

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
