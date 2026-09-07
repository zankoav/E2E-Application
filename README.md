# E2E Application

Salesforce package project for a backend-first E2E Application framework.

The framework provides a strict runtime skeleton for:

- application initialization
- step state and snapshots
- job execution
- integration boundaries
- conversion mapping into CRM records
- REST API commands

## Documentation

- `docs/vision.md`
- `docs/domain-language.md`
- `docs/core-object-model.md`
- `docs/application-lifecycle.md`
- `docs/process-definition-shape.md`
- `docs/runtime-flow.md`
- `docs/api-commands.md`
- `docs/rest-api-contract.md`
- `docs/error-model.md`
- `docs/extension-model.md`
- `docs/extension-contracts.md`
- `docs/admin-guide.md`
- `docs/security-model.md`
- `docs/package-strategy.md`
- `docs/package-readiness.md`
- `docs/package-creation-plan.md`
- `docs/release-checklist.md`
- `docs/examples/README.md`

## Validation

Use `test_matrix.json` to choose impacted Apex tests.

For broad runtime/package changes, use the `default.tests` list.

Do not run all local tests unless explicitly required.

## Package

The package directory is `force-app`.

`sfdx-project.json` is prepared for an initial `0.1.0.NEXT` package version, but package aliases and namespace should be added only after package creation/registration in Salesforce.

## Original Salesforce DX Notes

Now that you’ve created a Salesforce DX project, what’s next? Here are some documentation resources to get you started.

## How Do You Plan to Deploy Your Changes?

Do you want to deploy a set of changes, or create a self-contained application? Choose a [development model](https://developer.salesforce.com/tools/vscode/en/user-guide/development-models).

## Configure Your Salesforce DX Project

The `sfdx-project.json` file contains useful configuration information for your project. See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm) in the _Salesforce DX Developer Guide_ for details about this file.

## Read All About It

- [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
