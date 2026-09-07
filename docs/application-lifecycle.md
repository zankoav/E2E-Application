# Application Lifecycle

`Application__c` is the runtime draft of a customer process.

It owns the identity of the in-progress journey:

- process key
- scenario key
- current step key
- consumer key
- submitted application data
- runtime jobs
- active stop processes

`Application__c.Status__c` answers: "Can this Application still move through the process?"

`Application__c.Conversion_Status__c` answers: "Can this completed Application be mapped into CRM records?"

## Application Status

| Status | Meaning |
| --- | --- |
| `Draft` | Reserved initial state. The framework currently creates Applications directly as `InProgress`. |
| `InProgress` | The Application can accept step data, run jobs, and move between steps. |
| `WaitingForJobs` | Reserved runtime state for future explicit job waits. Jobs can still resolve the wait and return the Application to `InProgress` or finish it. |
| `Completed` | Final customer process state. Step data and jobs are immutable from the public command layer. |
| `Cancelled` | Terminal state for an intentionally stopped Application. |
| `Expired` | Terminal state for an Application that can no longer continue. |

`Completed`, `Cancelled`, and `Expired` are terminal Application statuses.

## Conversion Status

| Status | Meaning |
| --- | --- |
| `NotReady` | The Application is not completed and cannot be converted. |
| `Ready` | The Application is completed and selected conversion can start. |
| `Converting` | Conversion has claimed the Application. |
| `Converted` | CRM records were created or updated successfully. |
| `Failed` | Conversion failed for this Application. It can be retried only by an explicit retry command. |

## Allowed Application Transitions

| From | To |
| --- | --- |
| `Draft` | `InProgress`, `Cancelled`, `Expired` |
| `InProgress` | `WaitingForJobs`, `Completed`, `Cancelled`, `Expired` |
| `WaitingForJobs` | `InProgress`, `Completed`, `Cancelled`, `Expired` |
| `Completed` | none |
| `Cancelled` | none |
| `Expired` | none |

The current runtime uses the most important path:

```text
InProgress -> Completed
```

The extra statuses are intentionally present in metadata and constants because they define the package boundary for future commands.

## Allowed Conversion Transitions

| From | To |
| --- | --- |
| `Ready` | `Converting` |
| `Failed` | `Converting` |
| `Converting` | `Converted`, `Failed` |
| `NotReady` | none |
| `Converted` | none |

Conversion is allowed only when `Application__c.Status__c = Completed`.

## Enforcement

`ApplicationLifecycleGuard` owns lifecycle rules.

`ApplicationStateStore` calls it before:

- changing the Application step
- completing the Application
- changing conversion status

Handlers remain responsible for command validation, consumer access, rule evaluation, and returning snapshots.

Lifecycle rules stay below handlers so new REST endpoints, scheduled jobs, batch commands, or admin commands cannot accidentally bypass the core state machine.
