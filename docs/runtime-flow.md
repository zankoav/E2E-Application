# Runtime Flow

## Purpose

This document describes how the closed core executes E2E Application commands.

REST endpoints are only controllers. Runtime flow describes the application-level execution inside the package.

## Main Runtime Layers

| Layer | Responsibility |
| --- | --- |
| Controller | Parse API request and return API response. |
| Command Handler | Execute one application command. |
| Definition Resolver | Load process, scenario, step, rule, job, mapping, and consumer definitions. |
| State Store | Load and persist Application State. |
| Rule Engine | Evaluate explicit process decisions. |
| Job Engine | Create, run, observe, and recover Job instances. |
| Conversion Engine | Convert completed Applications into CRM records. |
| Snapshot Builder | Build API Snapshot from State and selected Definitions. |

## Definition Validation

Definition Resolver validates Process Definition before command handlers execute runtime behavior.

It checks that scenarios, steps, rules, job trigger rules, job definitions, and job execution modes are internally consistent.

Runtime handlers should work with already validated definitions, so configuration mistakes fail before state-changing business flow starts.

## Consumer Access

Every API command belongs to a trusted Consumer.

Consumer access is checked by the backend, not inferred by the frontend:

- `InitApplication` checks active Consumer Definition, allowed process, allowed scenario, and optional scenario `consumerKeys`.
- Commands for an existing Application check that the request consumer owns that Application.
- Existing Application commands also check that the Consumer still has access to the Application's process and scenario.

This keeps API access rules centralized and makes future web, mobile, partner, or internal consumers use the same backend boundary.

## InitApplication Flow

```text
API request
  -> Controller
  -> InitApplication Command Handler
  -> validate Consumer
  -> resolve Process Definition
  -> resolve Scenario
  -> create or resume Application__c
  -> initialize State
  -> build Snapshot
  -> API response
```

Important rules:

- `InitApplication` should be idempotent where possible.
- Consumer access must be checked before creating or resuming Application.
- Snapshot should use API contract keys, not Salesforce field API names.

## GetSnapshot Flow

```text
API request
  -> Controller
  -> GetSnapshot Command Handler
  -> load Application State
  -> resolve Definitions
  -> evaluate Step Availability Rules
  -> include active Jobs
  -> include active Stop Processes
  -> build Snapshot
  -> API response
```

Important rules:

- `GetSnapshot` should mainly read State.
- Any recovery mutation must be explicitly documented.
- Consumer should receive process meaning, not internal storage shape.

## SubmitStep Flow

```text
API request
  -> Controller
  -> SubmitStep Command Handler
  -> load Application State
  -> resolve current Step Definition
  -> resolve next transition candidate through Step Availability Rules
  -> evaluate Validation Rules
  -> persist accepted State changes
  -> evaluate Job Trigger Rules
  -> create/update Job instances
  -> evaluate target Step Availability
  -> evaluate Step Transition Rules
  -> evaluate Finish Rule if target is final state
  -> build Snapshot
  -> API response
```

`SubmitStep` does not always move the Application to the next Step.

Possible outcomes:

| Outcome | Meaning |
| --- | --- |
| `StateUpdated` | Data was accepted, current step remains active. |
| `ValidationBlocked` | Submitted data was rejected by Validation Rules. |
| `WaitingForJobs` | Required Jobs must finish before transition. |
| `StopProcessBlocked` | Active Stop Process blocks transition. |
| `TransitionCompleted` | Application moved to another Step. |
| `ApplicationFinished` | Application entered final immutable State. |

## ContinueApplication Flow

```text
API request
  -> Controller
  -> ContinueApplication Command Handler
  -> load Application State
  -> resolve current Step Definition
  -> load active Jobs and Stop Processes
  -> resolve next transition candidate through Step Availability Rules
  -> evaluate target Step Availability
  -> evaluate Step Transition Rules
  -> move Application if transition is allowed
  -> build Snapshot
  -> API response
```

`ContinueApplication` is used after `SubmitStep` accepted data but could not move forward.

It does not:

- run Validation Rules again
- persist submitted data again
- create Job instances again
- run Job execution

## Step Transition Flow

Step Transition Rules decide whether Application can move from one Step to another.

Inputs:

- current State
- submitted data result
- active Stop Processes
- required Job statuses
- scenario step order
- target Step availability

Strict Stop Process policy:

```text
active Stop Processes block transition by default
only explicitly allowed stop process codes can pass
```

## Step Availability Flow

Step Availability Rules decide how a Step appears in Snapshot and whether it can be selected as the next transition candidate.

Snapshot step statuses:

| Status | Meaning |
| --- | --- |
| `Current` | Application is currently on this Step. |
| `Completed` | Step is before the current Step in the Scenario. |
| `Available` | Step is the next enterable Step. |
| `Locked` | Step is visible but cannot be entered yet. |
| `Skipped` | Step does not apply to this Application State. |
| `Hidden` | Step should not be shown to the Consumer. |

Navigation rule:

```text
Hidden and Skipped steps are skipped while resolving the next transition candidate.
Locked steps are not skipped; they block transition until their availability rule allows entry.
```

This keeps UI Snapshot and backend transition behavior aligned.

## Job Flow

```text
Job Trigger Rule matched
  -> Job Engine creates or updates Application_Job__c
  -> Snapshot exposes runnable or observable Jobs
  -> RunJob Command Handler validates Job can run
  -> JobExecutor extension runs
  -> Job Engine stores result/status
  -> Consumer calls ContinueApplication when required Jobs are completed
```

Job execution modes:

| Mode | Purpose |
| --- | --- |
| `sync` | Run in the current transaction when safe. |
| `syncCallout` | Prepare before callout-safe sync execution. |
| `async` | Run through async Apex. |

Job dependencies define execution order and can block Step Transition Rules.

In the first runtime skeleton, `SubmitStep` only creates or updates `Application_Job__c` records in `Queued` status.

Job execution is intentionally handled by `RunJob`, not by `SubmitStep`.

Initial `RunJob` lifecycle:

```text
Queued or Restart or restartable Failed
  -> Processing
  -> Completed or Failed
```

`RunJob` validates the Application, Consumer, and Job status before execution.

Snapshot exposes allowed actions per Job.

Consumers should use each Job's `availableActions` instead of duplicating backend lifecycle rules.

## GetJobStatus Flow

```text
API request
  -> Controller
  -> GetJobStatus Command Handler
  -> load Application State
  -> validate Consumer
  -> load one Application_Job__c by runtime key
  -> resolve Process Definition
  -> build JobInfo
  -> API response
```

`GetJobStatus` is a read-only polling command for one Job.

It returns the same JobInfo shape used inside Snapshot, including `availableActions`.

Mode-specific lifecycle:

| Mode | Runtime behavior |
| --- | --- |
| `sync` | `RunJob` updates the Job to `Processing`, runs the executor in the same transaction, then stores `Completed` or `Failed`. |
| `syncCallout` | First `RunJob` updates the Job to `Preparing` and returns Snapshot. A later `RunJob` from `Preparing` runs the executor without pre-execution DML, then stores `Completed` or `Failed`. |
| `async` | `RunJob` updates the Job to `Processing`, enqueues async Apex, stores the async job id, and returns Snapshot. The Queueable runs the executor and stores `Completed` or `Failed`. |

`Preparing` is intentionally runnable for `syncCallout`.

This protects the flow from a browser reload or network failure between prepare and execute: after reload, Snapshot still exposes the Job and the Consumer can call `RunJob` again.

Restart lifecycle:

```text
Failed / Processing / Preparing
  -> RestartJob
  -> Restart
  -> RunJob
  -> mode-specific execution
```

Only Jobs with `Can_Be_Restarted__c = true` can be restarted.

`Completed` Jobs are intentionally not restartable through `RestartJob`.

When a Job dependency blocks a Step Transition, the Consumer should call `RunJob` for required runnable Jobs and then call `ContinueApplication`.

The Consumer should not call `SubmitStep` again only to retry the transition, because that would mean resubmitting the same Step data and re-evaluating Job Trigger Rules.

## Integration Flow

```text
JobExecutor or Conversion Engine
  -> IntegrationService
  -> IntegrationDefinitionResolver
  -> IntegrationAdapter
  -> external callout or Salesforce read
  -> normalized IntegrationResult
  -> caller decides next action
```

Integrations should not perform DML, change Application State, or own process transitions.

Integration Definition can come from:

- process `integrations` JSON
- `Integration_Definition__mdt`
- metadata definition plus process-level overrides

The caller owns any state change after reading `IntegrationResult`.

## Finish Flow

```text
SubmitStep
  -> Step Transition Rules passed
  -> target is final state
  -> Finish Rule evaluated
  -> Application status becomes Completed
  -> Completed_At__c is set
  -> ApplicationFinished event is created
  -> Snapshot returned
```

After finish, Application State should be treated as immutable except for conversion, audit, and support operations.

## Conversion Flow

```text
Completed Applications
  -> ConvertApplications Command Handler
  -> resolve Mapping Definitions
  -> update Conversion Status to Converting
  -> build target SObjects
  -> apply optional Mapping Transforms
  -> execute bulk DML by dependency batch
  -> create Application_Record_Link__c records
  -> update Conversion Status to Converted or Failed
  -> create Conversion events
```

Conversion is usually system/admin driven and should support bulk processing.

Initial conversion lifecycle:

```text
Ready
  -> Converting
  -> Converted or Failed
```

When Application enters the final state, `Conversion_Status__c` becomes `Ready`.

Failed Applications are not retried by the default conversion command.

To retry them, the caller must explicitly send `retryFailed = true`.

The initial Mapping Engine supports `insert`, `upsert`, and field-level transforms.

`upsert` uses Mapping `match.field` and `match.source` to find an existing CRM record before deciding between update and insert.

This is framework-controlled match behavior, not Salesforce native External Id upsert.

Match lookup is grouped by target object and match field so one conversion batch does not run one SOQL query per Application.

Mapping dependencies are executed in batches.

For example, Account mappings are saved first, then Contact mappings can use `fromRecord = account` to receive the saved Account Id in `Contact.AccountId`.

Conversion DML uses partial success handling.

If one mapped CRM record fails to save, only the owning Application is marked `Failed`; other Applications in the same conversion batch can still become `Converted`.

Conversion retry uses `Application_Record_Link__c` as the idempotency boundary.

If an earlier conversion attempt created or updated one mapped CRM record and then another mapped record failed, the retry reuses the existing link. The linked CRM record is updated instead of inserting another record for the same Application and Mapping key.

Mapping Transform is field-level:

```text
source value
  -> MappingTransform
  -> target field value
```

Transform classes should not perform DML. They should only return a value for the current target field.

## Guiding Principle

Commands change or read Application State through clear runtime layers.

Controllers should stay thin. Business decisions should be explicit Rules. Custom behavior should enter through Extensions.
