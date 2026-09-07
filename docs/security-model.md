# Security Model

The package exposes a small runtime permission set:

```text
E2E_Runtime
```

This permission set is intended for an API or runtime user that can run the E2E Application framework.

It grants:

- Apex access to the REST controller boundary
- read access to Process, Consumer, and Integration Custom Metadata Types
- read/create/edit access to framework runtime objects
- field access to framework runtime fields

It does not grant permissions to mapped CRM target objects such as Account, Contact, Opportunity, or custom business objects.

Those permissions belong to the consuming org, because mappings can target different objects per process and scenario.

## Runtime Objects

The runtime permission set grants access to:

- `Application__c`
- `Application_Data__c`
- `Application_Event__c`
- `Application_Job__c`
- `Application_Record_Link__c`
- `Application_Stop_Process__c`

Delete access is intentionally not granted.

Application state should be corrected through framework commands or controlled admin tools, not by deleting audit/runtime records.

## Definition Metadata

The runtime permission set grants read access to:

- `Process_Definition__mdt`
- `Consumer_Definition__mdt`
- `Integration_Definition__mdt`

Definition changes should be delivered through metadata deployment or package configuration, not runtime API calls.

## Target Object Permissions

Conversion can create or update Salesforce business records through Mapping.

The package does not know all possible target objects in advance.

For that reason, target object access is configured outside the package permission set.

The consuming org must decide which integration/runtime user can access mapped objects and fields.

## Guiding Principle

The package permission set opens the framework boundary.

Business object access remains an org-level decision.
