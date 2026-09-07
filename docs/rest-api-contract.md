# REST API Contract

The REST API is the transport boundary for trusted Consumers.

Consumers can be web frontends, mobile apps, partner sites, Salesforce UI, or internal backend integrations.

The backend owns process truth.

Consumers should follow returned state and actions instead of re-implementing lifecycle rules.

## Base Path

All endpoints are exposed under Salesforce Apex REST:

```text
/services/apexrest/e2e
```

## Endpoints

| Command | Method | Path | Success payload |
| --- | --- | --- | --- |
| `InitApplication` | `POST` | `/applications/init` | `snapshot` |
| `GetSnapshot` | `POST` | `/applications/snapshot` | `snapshot` |
| `SubmitStep` | `POST` | `/applications/submit-step` | `snapshot` |
| `ContinueApplication` | `POST` | `/applications/continue` | `snapshot` |
| `RunJob` | `POST` | `/applications/run-job` | `snapshot` |
| `RestartJob` | `POST` | `/applications/restart-job` | `snapshot` |
| `GetJobStatus` | `POST` | `/applications/job-status` | `job` |
| `ConvertApplications` | `POST` | `/applications/convert` | `conversion` |

## Response Envelope

Every endpoint returns `CommandResult`.

Success:

```json
{
  "success": true,
  "snapshot": {},
  "job": null,
  "conversion": null,
  "errors": []
}
```

Failure:

```json
{
  "success": false,
  "snapshot": null,
  "job": null,
  "conversion": null,
  "errors": [
    "Consumer key is required."
  ]
}
```

Only one primary payload is expected per successful command:

- `snapshot`
- `job`
- `conversion`

## HTTP Status

Runtime/controller exceptions return:

```text
400
```

with:

```json
{
  "success": false,
  "errors": ["..."]
}
```

Business blocking can still return:

```text
200
```

with:

```json
{
  "success": false,
  "snapshot": {}
}
```

This is intentional.

The request was understood and processed, but the Application cannot move because validation, jobs, stop processes, or transition rules blocked it.

Consumers should use `success` and returned payload, not HTTP status alone, to decide UI behavior.

## Request Rules

Every command requires:

```json
{
  "consumerKey": "webPortal"
}
```

Application-specific commands require:

```json
{
  "applicationId": "a00000000000001AAA"
}
```

Step commands require:

```json
{
  "stepKey": "contactDetails"
}
```

Job commands require:

```json
{
  "jobKey": "emailValidation"
}
```

Conversion requires:

```json
{
  "processKey": "fuelCardApplication"
}
```

## Snapshot Contract

`snapshot` is a stable API read model.

It is not a raw Salesforce record dump.

Important sections:

- `application`
- `steps`
- `data`
- `jobs`
- `stopProcesses`
- `availableActions`

Consumers should use `availableActions` and per-job `availableActions` to decide which commands can be called next.

## Job Contract

`GetJobStatus` returns only one normalized job payload:

```json
{
  "success": true,
  "job": {
    "key": "emailValidation",
    "status": "Completed",
    "availableActions": []
  }
}
```

Use this endpoint for lightweight polling when a full Snapshot is not needed.

## Conversion Contract

`ConvertApplications` returns:

```json
{
  "success": true,
  "conversion": {
    "requestedCount": 2,
    "convertedCount": 1,
    "failedCount": 1,
    "convertedApplicationIds": ["a00000000000001AAA"],
    "failedApplicationIds": ["a00000000000002AAA"],
    "errors": ["account: Required fields are missing: [Name]"]
  }
}
```

Partial conversion failure is represented in the payload.

The command itself can still return `success = true` when the conversion run completed and reported per-Application results.

## Controller Responsibility

REST controllers should stay thin:

```text
parse request body
build command
call command handler
write CommandResult
```

Response serialization is centralized in `E2ERestResponseWriter` so all endpoints use the same JSON envelope and content type.

## Guiding Principle

HTTP transports commands.

Application State decides behavior.

Snapshot tells Consumers what is true now and what can happen next.
