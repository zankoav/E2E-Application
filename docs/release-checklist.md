# Release Checklist

Use this checklist before creating the first package version.

## Source State

- Local changes are reviewed.
- `git status` contains only intended source changes.
- No package ids or package version ids are invented manually.
- `sfdx-project.json` still uses `0.1.0.NEXT` until Salesforce returns a real version id.

## Package Shape

- Package directory is `force-app`.
- Runtime metadata is explicit and deployable.
- Test-only Apex classes are marked `@IsTest`.
- Custom Metadata Types intended for org configuration are `Public`.
- Runtime object names do not duplicate the future namespace with an `E2E_` prefix.

## API Boundary

- REST controllers are the public runtime entrypoints.
- Response serialization is centralized in `E2ERestResponseWriter`.
- `CommandResult.errors` remains backward compatible.
- `CommandResult.errorDetails` provides stable error codes for Consumers.

## Extension Boundary

- Only documented extension contracts are `global`.
- Default implementations are `global` only because subscriber org configuration may reference them.
- Internal stores, handlers, builders, engines, and mappers remain package-owned implementation details.

## Security

- `E2E_Runtime` grants Apex access to REST controllers.
- `E2E_Runtime` grants access to runtime objects and public Custom Metadata Types.
- Internal helper classes are not exposed through permission set class access.
- Subscriber orgs must grant additional CRM object permissions for concrete conversion mappings.

## Validation

Run the default test matrix before package version creation:

```bash
sf project deploy validate \
  --source-dir force-app \
  --target-org <VALIDATION_ORG_ALIAS> \
  --test-level RunSpecifiedTests \
  --tests ProcessDefinitionTest \
  --tests ConsumerAccessServiceTest \
  --tests ErrorInfoMapperTest \
  --tests IntegrationServiceTest \
  --tests ReferenceDataServiceTest \
  --tests ConvertApplicationsHandlerTest \
  --tests ApplicationLifecycleGuardTest \
  --tests InitApplicationHandlerTest \
  --tests SubmitStepHandlerTest \
  --tests GetSnapshotHandlerTest \
  --tests GetJobStatusHandlerTest \
  --tests RuleEngineTest \
  --tests JobEngineTest \
  --tests RunJobHandlerTest \
  --tests ContinueApplicationHandlerTest \
  --tests RestartJobHandlerTest
```

## Package Creation

Create package records only after these values are confirmed:

- Dev Hub alias
- package type
- namespace
- package owner
- source branch or commit used for version creation

Follow `docs/package-creation-plan.md` for commands.
