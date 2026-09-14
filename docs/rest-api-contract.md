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

When the package is installed as a managed package, include the package namespace in the Apex REST URL:

```text
/services/apexrest/fleetcor_ete/e2e
```

Use the Salesforce instance/My Domain host for API calls, not the Lightning host.

Example for `UK_DEV`:

```text
https://fleetcoruk--aleksdev.sandbox.my.salesforce.com/services/apexrest/fleetcor_ete/e2e
```

Do not use:

```text
https://fleetcoruk--aleksdev.sandbox.lightning.force.com
```

## Authentication

Use a Salesforce API access token for the same org and host used by the request.

Required headers:

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

When testing with Postman, get the org instance URL and access token from Salesforce CLI:

```bash
sf org display --target-org UK_DEV --verbose
```

Common setup errors:

| Response | Likely cause |
| --- | --- |
| `INVALID_SESSION_ID` | Token is expired, belongs to another org, or is not valid for the API host. |
| `NOT_FOUND` / `Could not find a match for URL` | Managed package namespace is missing from the Apex REST path. |

## Endpoints

| Command | Method | Path | Success payload |
| --- | --- | --- | --- |
| `InitApplication` | `POST` | `/applications/init` | `snapshot` |
| `GetSnapshot` | `POST` | `/applications/snapshot` | `snapshot` |
| `GetReferenceData` | `POST` | `/applications/reference-data` | `references` |
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
  "access": null,
  "references": null,
  "errors": [],
  "errorDetails": []
}
```

Failure:

```json
{
  "success": false,
  "snapshot": null,
  "job": null,
  "conversion": null,
  "access": null,
  "references": null,
  "errors": [
    "Consumer key is required."
  ],
  "errorDetails": [
    {
      "code": "INVALID_REQUEST",
      "message": "Consumer key is required.",
      "details": {}
    }
  ]
}
```

Only one primary payload is expected per successful command:

- `snapshot`
- `job`
- `conversion`
- `references`

## HTTP Status

Runtime/controller exceptions return:

```text
400
```

with:

```json
{
  "success": false,
  "errors": ["..."],
  "errorDetails": [
    {
      "code": "...",
      "message": "...",
      "details": {}
    }
  ]
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

Consumers should use `errorDetails[].code` for stable branching and `errors[]` only as a simple message list.

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

## Public Website Access

Salesforce API tokens must not be stored in public browser code.

For public websites, expose only the required Apex REST controllers through the Salesforce Site Guest User and use Application public access.

Consumer access is configured in `Consumer_Definition__mdt`:

- `Consumer_Key__c` identifies the consumer, for example `webPortal`.
- `Allowed_Process_Keys__c` controls runnable process keys.
- `Allowed_Scenario_Keys__c` controls runnable `processKey:scenarioKey` pairs.
- `Allowed_Origins__c` optionally restricts browser `Origin` values. Empty means no framework-level origin restriction. Salesforce CORS/Trusted URLs still belong to Salesforce Setup.

Application public access is configured per scenario in `Process_Definition__mdt.Definition_JSON__c`:

```json
{
  "scenarios": {
    "newCustomer": {
      "initialStep": "contactDetails",
      "steps": ["contactDetails", "finish"],
      "publicAccess": {
        "enabled": true,
        "idleTimeoutMinutes": 60,
        "maxLifetimeMinutes": 10080
      }
    }
  }
}
```

When public access is enabled, `InitApplication` for a new Application returns a one-time `resumeToken`:

```json
{
  "success": true,
  "snapshot": {},
  "access": {
    "resumeToken": "raw-token-returned-once",
    "expiresAt": "2026-09-11T12:00:00.000Z"
  }
}
```

Application-specific public requests must include the token:

```json
{
  "consumerKey": "webPortal",
  "applicationId": "a00000000000001AAA",
  "resumeToken": "raw-token-returned-once"
}
```

The backend stores only a token hash on `Application__c`.

On every valid token-based request, `expiresAt` is refreshed by `idleTimeoutMinutes`, but never beyond `maxLifetimeMinutes`.

Existing Applications can be resumed through `InitApplication` with the same `externalReference` only when the request also includes the valid `resumeToken`.

## Snapshot Contract

`snapshot` is a stable API read model.

It is not a raw Salesforce record dump.

Important sections:

- `application`
- `steps`
- `data`
- `references`
- `jobs`
- `stopProcesses`
- `availableActions`

Consumers should use `availableActions` and per-job `availableActions` to decide which commands can be called next.

Snapshot does not auto-load reference data.

Each Step can expose `referenceDataKeys` so Consumers know which reference datasets can be requested for that Step.

This avoids DML-before-callout issues when Snapshot is returned after state-changing commands such as `InitApplication` or `SubmitStep`.

Installed package Snapshot example:

```http
POST /services/apexrest/fleetcor_ete/e2e/applications/snapshot
Authorization: Bearer <access_token>
Content-Type: application/json
```

Request:

```json
{
  "consumerKey": "webPortal",
  "applicationId": "a00000000000001AAA"
}
```

Example `UK_DEV` URL:

```text
https://fleetcoruk--aleksdev.sandbox.my.salesforce.com/services/apexrest/fleetcor_ete/e2e/applications/snapshot
```

## Reference Data Contract

`GetReferenceData` returns named reference datasets for a Step.

Request:

```json
{
  "applicationId": "a00000000000001AAA",
  "consumerKey": "webPortal",
  "stepKey": "products",
  "referenceKeys": ["availableProducts"]
}
```

`stepKey` is optional and defaults to the current Application Step.

`referenceKeys` is optional. When omitted or empty, all reference data entries for the Step are returned.

Response:

```json
{
  "success": true,
  "references": {
    "availableProducts": {
      "items": []
    }
  }
}
```

Reference data is resolved through `IntegrationService`.

Reference data integrations should not perform DML.

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

See `docs/error-model.md` for stable API error codes.
