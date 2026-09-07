# Extension Contracts

Extension contracts are the public API between the managed package core and subscriber org code.

For managed package usage, these contracts are `global`.

Subscriber classes should implement these contracts and then be referenced by process definitions or integration metadata.

## Contracts

| Contract | Purpose | Input | Output |
| --- | --- | --- | --- |
| `ValidationRule` | Validate submitted data or state. | `StepRuntimeContext`, rule definition | `RuleResult` |
| `StepAvailabilityRule` | Decide whether a step is available, locked, skipped, or hidden. | `StepRuntimeContext`, rule definition | `RuleResult` |
| `StepTransitionRule` | Decide whether the application can move to another step. | `StepRuntimeContext`, rule definition | `RuleResult` |
| `JobExecutor` | Execute backend work for an Application Job. | `Application_Job__c`, job definition | `JobExecutionResult` |
| `IntegrationAdapter` | Call/read another system and return normalized data. | `IntegrationRequest` | `IntegrationResult` |
| `MappingTransform` | Convert one application data value into one mapped target field value. | `MappingTransformContext` | `Object` |

## Global DTOs

The following DTOs are part of the extension API:

- `StepRuntimeContext`
- `RuleResult`
- `JobExecutionResult`
- `IntegrationRequest`
- `IntegrationResult`
- `IntegrationDefinition`
- `MappingTransformContext`
- `ProcessDefinition`
- `ProcessDefinition.ScenarioDefinition`
- `SubmitStepCommand`

These are intentionally small data containers.

They expose enough context for subscriber extension code without exposing internal handler/store implementation details.

## Example Validation Rule

```apex
global class CompanyNameRequiredRule implements ValidationRule {
    global RuleResult validate(StepRuntimeContext context, Map<String, Object> ruleDefinition) {
        Object companyName = context.submittedData == null ? null : context.submittedData.get('company.name');
        if (companyName == null || String.isBlank(String.valueOf(companyName))) {
            return RuleResult.block('COMPANY_NAME_REQUIRED', 'Company name is required.');
        }
        return RuleResult.allow();
    }
}
```

## Example Job Executor

```apex
global class EmailValidationJobExecutor implements JobExecutor {
    global JobExecutionResult execute(Application_Job__c job, Map<String, Object> jobDefinition) {
        return JobExecutionResult.ok();
    }
}
```

## Example Integration Adapter

```apex
global class EmailProviderIntegrationAdapter implements IntegrationAdapter {
    global IntegrationResult execute(IntegrationRequest request) {
        Map<String, Object> data = new Map<String, Object>();
        data.put('valid', true);
        return IntegrationResult.ok(data);
    }
}
```

## Example Mapping Transform

```apex
global class UppercaseMappingTransform implements MappingTransform {
    global Object transform(MappingTransformContext context) {
        return context.sourceValue == null ? null : String.valueOf(context.sourceValue).toUpperCase();
    }
}
```

## Rules

Extension classes should:

- be `global`
- implement the expected package interface
- return framework result DTOs instead of changing runtime state directly
- keep DML out of integrations and mapping transforms
- avoid changing CRM records outside Conversion unless the contract explicitly owns that behavior

Extension classes should not:

- modify core package code
- create their own REST response shape
- bypass job, transition, or conversion lifecycle
- depend on internal store/handler classes

## Guiding Principle

The closed core owns lifecycle.

Extensions own business-specific decisions and actions at documented extension points.
