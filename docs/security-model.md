# Security Model

The package exposes two runtime permission sets:

```text
E2E_Runtime
E2E_Public_Access
```

`E2E_Runtime` is intended for an authenticated API or runtime user that can run the E2E Application framework.

`E2E_Public_Access` is intended for Salesforce Site Guest User access to public website flows.

They grant:

- Apex access to the REST controller boundary
- read access to Process, Consumer, and Integration Custom Metadata Types
- read/create/edit access to framework runtime objects
- field access to framework runtime fields

It does not grant permissions to mapped CRM target objects such as Account, Contact, Opportunity, or custom business objects.

Those permissions belong to the consuming org, because mappings can target different objects per process and scenario.

`E2E_Public_Access` intentionally excludes the conversion controller.

Conversion is a backend/admin operation, not a public browser operation.

`E2E_Public_Access` also does not expose `Application__c.Public_Access_Key_Hash__c` as a field permission.

The framework stores only the token hash and returns the raw `resumeToken` only when it is issued.

## Runtime Objects

`E2E_Runtime` grants access to:

- `Application__c`
- `Application_Data__c`
- `Application_Event__c`
- `Application_Job__c`
- `Application_Record_Link__c`
- `Application_Stop_Process__c`

`E2E_Public_Access` grants access only to public runtime objects:

- `Application__c`
- `Application_Data__c`
- `Application_Event__c`
- `Application_Job__c`
- `Application_Stop_Process__c`

Delete access is intentionally not granted.

Application state should be corrected through framework commands or controlled admin tools, not by deleting audit/runtime records.

For public website requests, object access is only the technical permission to let Apex run.

The actual Application-level authorization is still enforced by the framework through:

- Consumer Definition
- process/scenario allowlists
- optional Origin allowlist
- scenario public access settings
- Application `resumeToken`
- token idle timeout and max lifetime

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
