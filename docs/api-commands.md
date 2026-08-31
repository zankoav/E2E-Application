# API Commands

## Purpose

API Commands describe actions that trusted Consumers can request from the E2E Application package.

REST endpoints are transport. Commands are the application-level meaning.

## Initial Commands

| Command | Purpose |
| --- | --- |
| `InitApplication` | Create or resume an Application and return a Snapshot. |
| `GetSnapshot` | Return the current Snapshot for an existing Application. |
| `SubmitStep` | Submit data for the current Step and evaluate process movement. |
| `RunJob` | Run a specific Job instance when the Snapshot allows it. |
| `GetJobStatus` | Read current Job status. |
| `ConvertApplications` | Convert completed Applications into CRM records, usually in bulk. |

## InitApplication

Starts or resumes an E2E process instance.

Responsibilities:

- validate Consumer access
- resolve Process and Scenario definitions
- create or find `Application__c`
- initialize Application State
- return Snapshot

`InitApplication` should be idempotent where possible.

## GetSnapshot

Returns the current API view of Application State.

Responsibilities:

- load Application State
- evaluate visible/available Steps
- include active Jobs and Stop Processes
- return stable API contract keys

`GetSnapshot` should not mutate Application State except for explicitly documented recovery behavior.

## SubmitStep

Submits data for the current Step.

Responsibilities:

- validate submitted data through Validation Rules
- persist accepted State changes
- evaluate Job Trigger Rules
- create or update Job instances
- evaluate Step Transition Rules
- evaluate Finish Rule when applicable
- return updated Snapshot

`SubmitStep` does not always move the Application to the next Step.

It can return a Snapshot where transition is blocked by:

- validation errors
- required Jobs
- active Stop Processes
- transition rules

## RunJob

Runs a Job instance.

Responsibilities:

- validate Job can run
- respect execution mode
- invoke JobExecutor extension
- update Job status
- store structured result or error

Jobs can run sync, async, or with callout-safe preparation.

## GetJobStatus

Returns current status of a Job instance.

Responsibilities:

- load Job by key
- return normalized Job status
- apply documented recovery rules when needed

## ConvertApplications

Converts completed Applications into CRM records.

Responsibilities:

- find Applications ready for conversion
- resolve Mapping definitions
- build target SObjects
- execute bulk DML
- create Application Record Links
- update conversion status
- return conversion result

Conversion is usually system/admin driven, not a normal frontend action.

## Guiding Principle

Every API request should map to a clear Command.

Controllers should parse requests and return responses. Process decisions should live in the application/runtime layers.

