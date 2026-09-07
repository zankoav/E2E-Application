# Admin Guide

This guide describes how to configure a new E2E process without changing the package core.

## Create A Process

Create or update a `Process_Definition__mdt` record.

Set:

- `Process_Key__c`
- `Version__c`
- `Active__c`
- `Definition_JSON__c`

`Definition_JSON__c` contains the process body.

The top-level shape is documented in `process-definition-shape.md`.

## Add A Scenario

Add a scenario under `scenarios`.

Use a scenario when the same process needs a different path, audience, or frontend behavior.

Example:

```json
{
  "scenarios": {
    "newCustomer": {
      "label": "New Customer",
      "initialStep": "contactDetails",
      "steps": ["contactDetails", "companyDetails", "finish"]
    }
  }
}
```

## Add Or Reorder Steps

Add step keys under the scenario `steps` list.

The order in the list is the default process order.

Each step must also exist in the top-level `steps` object.

Use step rules when the default order is not enough.

## Add Step Rules

Use rules for explicit decisions:

- `validationRules`: submitted data is acceptable
- `availabilityRules`: step can be shown, opened, skipped, or hidden
- `jobTriggerRules`: jobs should be created for this step
- `transitionRules`: application can move to another step

Rules may be declarative or point to custom Apex extension classes.

## Add Jobs

Add job definitions under `jobs`.

Choose execution mode:

- `sync`: no callout after status DML
- `syncCallout`: callout-safe two-step lifecycle
- `async`: Queueable execution

Use `dependsOn` when one job must wait for another job.

Step transition rules should declare required job completion when a step cannot advance without a job result.

## Add Consumers

Create or update a `Consumer_Definition__mdt` record.

Set:

- `Consumer_Key__c`
- `Active__c`
- `Allowed_Process_Keys__c`
- `Allowed_Scenario_Keys__c`

Consumers are trusted API clients such as web portals, mobile apps, partner sites, or internal integrations.

## Add Integrations

Create or update an `Integration_Definition__mdt` record when a job or conversion needs reusable external/internal access configuration.

Set:

- `Integration_Key__c`
- `Active__c`
- `Adapter_Class__c`
- `Named_Credential__c`
- `Settings_JSON__c`

Integration adapters should return normalized results.

They should not perform DML or change Application State.

## Add Conversion Mapping

Add mappings under `mappings`.

Mappings convert completed Application data into Salesforce CRM records.

Use:

- `targetObject` to select the Salesforce object
- `operation` as `insert` or `upsert`
- `fields` to map application data into target fields
- `match` for framework-controlled upsert matching
- `dependsOn` and `fromRecord` for parent-child relationships

Example:

```json
{
  "mappings": {
    "account": {
      "targetObject": "Account",
      "operation": "insert",
      "fields": [
        { "target": "Name", "source": "company.name" }
      ]
    },
    "contact": {
      "targetObject": "Contact",
      "operation": "insert",
      "dependsOn": ["account"],
      "fields": [
        { "target": "LastName", "source": "contact.lastName" },
        { "target": "AccountId", "fromRecord": "account" }
      ]
    }
  }
}
```

## Assign Permissions

Assign `E2E_Runtime` to the runtime/API user.

Then grant that user access to any mapped CRM target objects and fields outside the package permission set.

For example, if conversion creates Account and Contact records, the consuming org must grant Account and Contact access separately.

## Validate Changes

Use `test_matrix.json` to choose impacted tests.

For process definition changes, at minimum run the definition tests.

For runtime or package-level changes, use the `default.tests` list.

## Guiding Principle

New business processes should usually be created through definitions, consumers, integrations, mappings, and extension classes.

The package core should change only when the framework skeleton itself needs to evolve.
