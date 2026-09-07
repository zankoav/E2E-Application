# Package Readiness

This project is shaped as a Salesforce 2GP package project.

The current package directory is:

```text
force-app
```

The package configuration in `sfdx-project.json` defines:

- package name: `E2E Application`
- initial version name: `ver 0.1`
- initial version number: `0.1.0.NEXT`

The project does not define a package id or package alias yet.

Those values should be added only after the package is created in Dev Hub.

## Namespace

The namespace is currently empty.

For a managed package, the namespace should be set after it is registered and connected to the Dev Hub/package.

Do not invent a namespace in source before the package ownership is decided in Salesforce.

## Test Matrix

`test_matrix.json` defines the smallest relevant Apex tests by functional area.

Before validation or package version creation, choose tests from the impacted area first.

Use the `default.tests` list for package-level or cross-cutting changes.

## Validation Policy

Use check-only validation before package work.

Do not deploy or create package versions from local changes unless explicitly requested.

Use `package-creation-plan.md` when the team is ready to create package records in Dev Hub.

## Guiding Principle

Package metadata should be explicit enough to build from, but should not contain invented Salesforce ids.
