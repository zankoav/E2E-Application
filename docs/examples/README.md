# Definition Examples

These examples are reference templates for process definitions.

They are intentionally stored as documentation files, not active Custom Metadata records.

Use them as starting points when creating `Process_Definition__mdt.Definition_JSON__c`.

## Files

`minimal-process-definition.json`

A small process with one standard step and one finish step.

Use it to understand the smallest useful definition shape.

`full-process-definition.json`

A broader reference process with:

- multiple scenarios
- required and optional steps
- validation, job trigger, transition, and finish rules
- sync, syncCallout, and async jobs
- an integration definition reference
- conversion mapping with `upsert`
- mapping dependency from Contact to Account
- a stop process example

## Usage

Copy the JSON body into `Process_Definition__mdt.Definition_JSON__c`.

Then set the metadata fields:

- `Process_Key__c`
- `Version__c`
- `Active__c`
- `Description__c`

`Process_Key__c` should match `process.key`.

`Version__c` should match `process.version`.

Before using a definition at runtime, validate the project with the tests listed in `test_matrix.json`.

## Notes

The examples use default framework classes where possible.

Real projects usually replace those defaults with subscriber extension classes for business-specific validations, jobs, integrations, and mapping transforms.
