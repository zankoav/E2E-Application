# Package Readiness

This project is shaped as a Salesforce 2GP package project.

The current package directory is:

```text
force-app
```

The package configuration in `sfdx-project.json` defines:

- package name: `E2E Application`
- package alias: `ETE_Fleetcor_Framework`
- package id: `0HoIS0000008OMW0A2`
- initial version name: `ver 0.1`
- initial version number: `0.1.0.NEXT`
- namespace: `fleetcor_ete`

The project reuses the existing Dev Hub package record `ETE_Fleetcor_Framework`.

## Namespace

The namespace is `fleetcor_ete`.

It is already associated with the selected managed package record in Dev Hub.

## Test Matrix

`test_matrix.json` defines the smallest relevant Apex tests by functional area.

Before validation or package version creation, choose tests from the impacted area first.

Use the `default.tests` list for package-level or cross-cutting changes.

## Validation Policy

Use check-only validation before package work.

Do not deploy or create package versions from local changes unless explicitly requested.

Use `package-creation-plan.md` when the team is ready to create package records in Dev Hub.

## Guiding Principle

Package metadata should be explicit enough to build from, and package ids should only come from Salesforce CLI/Dev Hub output.
