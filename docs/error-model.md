# Error Model

The API keeps backward compatibility with the simple string error list and adds structured errors for Consumers that need stable behavior.

## Response Shape

Every failed `CommandResult` can include both fields:

```json
{
  "success": false,
  "errors": ["Consumer key is required."],
  "errorDetails": [
    {
      "code": "INVALID_REQUEST",
      "message": "Consumer key is required.",
      "details": {}
    }
  ]
}
```

`errors` is a legacy-friendly list of messages.

`errorDetails` is the stable API contract.

Consumers should use `errorDetails[].code` for branching and `message` for display or diagnostics.

## Standard Codes

| Code | Meaning |
| --- | --- |
| `INVALID_REQUEST` | Command payload is missing required data or cannot be understood. |
| `ACCESS_DENIED` | Consumer is not allowed to access the requested process, scenario, or Application. |
| `APPLICATION_NOT_FOUND` | Requested Application does not exist. |
| `INVALID_APPLICATION_STATE` | Command is not valid for the current Application lifecycle state. |
| `JOB_NOT_FOUND` | Requested Application Job does not exist. |
| `JOB_NOT_RUNNABLE` | Job exists but cannot run or restart from its current status. |
| `BLOCKED_BY_RULE` | A rule blocked progress and did not provide a more specific code. |
| `DEFINITION_ERROR` | Process/scenario/definition configuration is invalid or missing. |
| `RULE_ERROR` | Rule configuration or rule class resolution failed. |
| `MAPPING_ERROR` | Conversion mapping configuration or mapping execution failed. |
| `CONVERSION_ERROR` | Conversion lifecycle failed outside a specific mapping error. |
| `INTEGRATION_ERROR` | Integration definition or adapter resolution failed. |
| `UNKNOWN_ERROR` | Fallback for unexpected or uncategorized errors. |

## Blocking Is Not Always HTTP Failure

Business blocking can return HTTP `200` with `success = false`.

Example:

```json
{
  "success": false,
  "snapshot": {},
  "errors": ["Required Job is not completed. Job: contactDetails___emailValidation"],
  "errorDetails": [
    {
      "code": "REQUIRED_JOB_NOT_COMPLETED",
      "message": "Required Job is not completed. Job: contactDetails___emailValidation",
      "details": {}
    }
  ]
}
```

This means the command was valid, but backend process rules decided the Application cannot move yet.

## Implementation

`CommandResult` owns the public response shape.

`ErrorInfoMapper` maps framework exceptions and rule results to `ErrorInfo`.

REST controllers pass exceptions into `CommandResult.fail(ex)` instead of serializing only `ex.getMessage()`.
