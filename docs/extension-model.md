# Extension Model

## Purpose

The managed core package must be closed for direct modification but open for controlled horizontal extension.

Subscriber orgs should add business-specific behavior through documented extension contracts and settings.

## Main Principle

Core defines extension points.

Subscriber orgs provide implementations.

Settings connect definitions to implementation classes.

## Horizontal Extension

Extensions add behavior next to the core, not inside it.

Preferred:

```text
new JobExecutor implementation
new IntegrationAdapter implementation
new Rule implementation
new MappingTransform implementation
```

Avoid:

```text
changing core engine logic
adding business-specific if/else inside the core
modifying REST controllers for a specific form
```

## Extension Registry

Process, step, job, rule, integration, and mapping definitions can reference extension class names.

The core resolves these classes dynamically and invokes them through package contracts.

Example:

```json
{
  "jobKey": "emailValidation",
  "executorClass": "EmailValidationJobExecutor",
  "executionMode": "syncCallout"
}
```

## Initial Extension Points

| Extension point | Responsibility |
| --- | --- |
| `Rule` | Make a specific process decision. |
| `JobExecutor` | Execute backend work for a Job. |
| `IntegrationAdapter` | Read/call another system and return normalized data. |
| `MappingTransform` | Convert application data values during Mapping. |
| `StepHandler` | Add custom step-level behavior when declarative rules are not enough. |

`IntegrationAdapter` should not perform DML or change Application State. It receives `IntegrationRequest` and returns `IntegrationResult`; the caller decides what to persist.

`MappingTransform` should not perform DML or create CRM records. It receives `MappingTransformContext` and returns one target field value.

## Contract Design

Extension contracts should be small, stable, and global.

Contracts should receive context objects and return result objects.

They should not depend on internal core implementation details.

## Dynamic Resolution

The core should instantiate extension classes by class name from settings.

Resolved classes must implement or inherit the expected package contract.

If a class cannot be found or does not match the contract, the core should return a structured configuration error.

## Boundaries

Extensions may:

- read Application State through context
- read allowed Salesforce data
- call external systems when appropriate
- return structured results
- provide business-specific logic

Extensions should not:

- modify core package code
- bypass the framework lifecycle
- directly change Application State unless the contract explicitly allows it
- create CRM records outside Conversion
- decide REST response shape

## Guiding Principle

Extension points should give org developers enough power to build new processes without giving them reasons to modify the core skeleton.
