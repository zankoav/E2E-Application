# Package Strategy

## Decision

Use a Salesforce 2GP Managed Package with namespace.

The package is intended for internal company use across multiple Salesforce orgs, but the core should behave like a closed product framework.

## Why Managed

The E2E Application package should provide a strict framework skeleton that org developers cannot modify directly.

Managed packaging supports this goal better than unlocked packaging because the core package remains owned and controlled by the framework team.

## Namespace

Use a short namespace, for example:

```text
e2e
```

When namespace is used, metadata names should not repeat the `E2E_` prefix.

Preferred:

```text
e2e__Application__c
e2e__Application_Job__c
e2e__Process_Definition__mdt
```

Avoid:

```text
e2e__E2E_Application__c
e2e__E2E_Application_Job__c
```

## Closed Core

The managed package owns:

- application runtime
- process and step engine
- rule engine
- job engine
- integration contracts
- conversion engine
- REST API controllers
- extension contracts

Core code should be changed only through new package versions.

## Extension Layer

Subscriber orgs extend behavior through documented global contracts and settings.

Examples:

- custom step handlers
- custom job executors
- custom integration adapters
- custom rule implementations
- custom mapping transforms
- process/scenario/step/job/mapping definitions

Extensions add behavior horizontally. They should not require modification of the managed core.

## Release Model

Core package versions should be released rarely and intentionally.

New package versions are expected when:

- the framework skeleton changes
- new extension contracts are introduced
- existing contracts need safe evolution
- core engine bugs are fixed
- platform/security issues require changes

New business forms should usually be delivered through definitions and extensions, not by changing the core package.

## Guiding Principle

The package should make new E2E process rollout much faster while keeping the core framework stable, protected, and predictable.

