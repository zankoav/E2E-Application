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
  -> evaluate Validation Rules
  -> persist accepted State changes
  -> evaluate Job Trigger Rules
  -> create/update Job instances
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
  -> IntegrationAdapter
  -> external callout or Salesforce read
  -> normalized IntegrationResult
  -> caller decides next action
```

Integrations should not perform DML, change Application State, or own process transitions.

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
  -> build target SObjects
  -> execute bulk DML
  -> create Application_Record_Link__c records
  -> update Conversion Status
  -> create Conversion events
```

Conversion is usually system/admin driven and should support bulk processing.

## Guiding Principle

Commands change or read Application State through clear runtime layers.

Controllers should stay thin. Business decisions should be explicit Rules. Custom behavior should enter through Extensions.
