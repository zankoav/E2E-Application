# Package Creation Plan

This document describes how to create the first 2GP package version from the existing Dev Hub package record.

Do not run these commands automatically.

Run them only when the Dev Hub, namespace, and package ownership are confirmed.

## Preconditions

Confirm:

- Dev Hub org alias: `Zankoav`
- package type
- namespace decision
- package owner
- Git branch or source state used for the package version

The current strategy is:

```text
2GP Managed Package
```

The project is already prepared with:

- package directory: `force-app`
- package alias: `ETE_Fleetcor_Framework`
- package id: `0HoIS0000008OMW0A2`
- namespace: `fleetcor_ete`
- version name: `ver 0.1`
- version number: `0.1.0.NEXT`
- validation matrix: `test_matrix.json`

## 1. Validate Source Before Package Work

Run a check-only validation against a known org before touching package records:

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

Use the `default.tests` list from `test_matrix.json` for broad package-level validation.

## 2. Create Package In Dev Hub

The package record already exists in Dev Hub.

Current package:

```text
Name: ETE_Fleetcor_Framework
Id: 0HoIS0000008OMW0A2
Type: Managed
Namespace: fleetcor_ete
Versions: none yet
```

Do not run `sf package create` again for the first release unless the team decides to abandon this package record.

The current `sfdx-project.json` should contain:

```json
{
  "namespace": "fleetcor_ete",
  "packageAliases": {
    "ETE_Fleetcor_Framework": "0HoIS0000008OMW0A2"
  }
}
```

## 3. Namespace

The selected namespace is `fleetcor_ete`.

Do not add an `E2E_` prefix to metadata names when namespace is used.

## 4. Create First Package Version

After package id/alias is present, create the first package version:

```bash
sf package version create \
  --package "ETE_Fleetcor_Framework" \
  --installation-key-bypass \
  --wait 30 \
  --target-dev-hub Zankoav
```

For a managed package version that must be installable outside the Dev Hub lifecycle, include the required Salesforce packaging flags for the release process used by the company.

Package version creation returns a version id that starts with:

```text
04t
```

Do not invent this id.

Add returned aliases to `sfdx-project.json` only after the command succeeds.

Expected shape:

```json
{
  "packageAliases": {
    "ETE_Fleetcor_Framework": "0HoIS0000008OMW0A2",
    "ETE_Fleetcor_Framework@0.1.0-1": "04t..."
  }
}
```

## 5. Validate Package Version

Install the package version into a clean validation org or scratch org before using it in shared sandboxes.

Command shape:

```bash
sf package install \
  --package "ETE_Fleetcor_Framework@0.1.0-1" \
  --target-org <INSTALL_TEST_ORG_ALIAS> \
  --wait 30 \
  --publish-wait 30
```

After install:

- assign `E2E_Runtime`
- grant target CRM object permissions needed by mappings
- run runtime smoke tests through REST/API or Apex tests

## 6. Promote Package Version

Promote only after install validation succeeds.

Command shape:

```bash
sf package version promote \
  --package "ETE_Fleetcor_Framework@0.1.0-1" \
  --target-dev-hub Zankoav
```

Promotion makes the package version releasable according to Salesforce 2GP rules.

## Safety Rules

- Do not create a package from unreviewed local changes.
- Do not create package aliases manually before Salesforce returns ids.
- Do not deploy metadata as a substitute for package version creation.
- Do not run package commands against an assumed Dev Hub alias.
- Do not promote a package version before install validation.

## Guiding Principle

Deployment validation proves the source can compile in an org.

Package version creation proves the source can become a distributable product.

Treat those as separate steps.
