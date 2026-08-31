# E2E Application Vision

## Goal

Build a Salesforce managed package framework for creating and running E2E business processes through a stable backend API.

The package should make rollout of new E2E processes significantly faster by providing a strict closed core and documented extension points.

## Core Idea

`Application__c` is a draft of the business process.

The package owns the process state, steps, rules, jobs, integrations, and conversion lifecycle. Salesforce CRM records such as Opportunity, Account, and Contact are created or updated later through a controlled conversion/mapping process.

## Package Model

Closed managed package core:

- application runtime
- process/step engine
- rule engine
- job engine
- REST API controllers
- conversion engine
- extension contracts

Subscriber org extension layer:

- process definitions
- step settings
- job settings
- mapping settings
- custom Apex extensions

## Main Principle

The core framework is closed for direct modification and open for extension through documented global contracts and settings.

Org-specific behavior should extend the framework horizontally, not by changing the core skeleton.

## Extension Model

Org developers extend behavior by implementing or inheriting package contracts, then registering extension classes in settings.

The core discovers these classes dynamically and invokes them through stable interfaces/base classes.

## API Boundary

Frontend is not part of the package architecture.

Any trusted consumer can use the API, including web portals, mobile apps, Salesforce UI, partner sites, or internal integrations.

Consumers can use the API to:

- init application
- get application snapshot
- submit step
- run or observe jobs
- convert completed applications

API responses return Snapshots, not Salesforce record dumps. Snapshot keys should follow the stable API contract, not internal Salesforce object or field API names.

## CRM Boundary

CRM objects are not workflow state.

`Application__c` stores E2E process state. CRM objects are the result of conversion.

Conversion can be executed after application completion and should support bulk processing of completed applications.

## Process Control

Rules decide whether data is acceptable, steps are available, jobs should run, transitions are allowed, application can finish, or conversion can happen.

Stop Processes are part of Application State. They block step transitions by default unless a transition explicitly allows a specific stop condition.
