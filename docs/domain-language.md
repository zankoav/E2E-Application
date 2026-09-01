# Domain Language

This document defines the main words used by the E2E Application package.

## Application

A concrete E2E process instance.

In Salesforce it is stored as `Application__c`. It owns workflow state while the customer or external consumer is moving through the process.

Short formula: Application = who/what this process instance is.

## Process

A type of business process that the package can run.

Examples: fuel card application, customer onboarding, contract renewal.

## Scenario

A variant of a process.

Examples: new customer, existing customer, hybrid flow.

## Step

A stage of the process.

A step defines what data is expected, what validations can run, what jobs can be triggered, job dependencies, availability conditions, and what transition can happen next.

A step can be required, optional, or conditional. Conditional steps are included in the process only when their conditions match the current application state.

Step availability is backend truth. Snapshot can mark steps as `Current`, `Completed`, `Available`, `Locked`, `Skipped`, or `Hidden`.

## Command

An action requested through the API.

Examples: init application, submit step, run job, restart job, continue application, get job status, convert application.

## State

The current persisted condition of an application.

Examples: current step, application status, collected data, job statuses, validation results.

Short formula: State = where/how this process instance is now.

## Snapshot

A read model returned by the API.

It represents the current application state in a stable response format for any trusted consumer.

Snapshot = external API view of the current State at response time.

It is not a Salesforce record dump. It should use stable API contract names, not internal Salesforce object or field API names.

## Consumer

A trusted system or frontend that uses the E2E API.

Examples: web portal, mobile app, partner site, Salesforce UI, internal backend integration.

## Job

A unit of backend work related to an application.

Jobs can run synchronously, asynchronously, or with a callout-safe preparation step.

## Rule

A decision rule used by the framework.

Rules answer specific questions during the application lifecycle. A rule should be explicit about what decision it owns.

Common rule types:

| Rule type | Question |
| --- | --- |
| Validation Rule | Is this data or state acceptable? |
| Step Availability Rule | Can this step be shown or opened? |
| Job Trigger Rule | Should this job run? |
| Step Transition Rule | Can the application move from one step to another? |
| Finish Rule | Can the application enter the final immutable state? |
| Conversion Rule | Can the application be converted into CRM records? |

## Integration

An external or internal system interaction used by a job or conversion.

Examples: credit provider, email validation, payment gateway, document service.

From the framework point of view, Integration behaves like a pure function: it receives input and returns a normalized result.

Integration can perform callouts or Salesforce reads, but it should not perform DML, change Application State, or own process transitions. The next layer decides what to do with the returned data.

## Stop Process

A condition or state that blocks normal process movement.

A Stop Process can affect Step Transition Rules, route an application to manual review, or prevent the application from reaching the final state until the stop condition is resolved.

Stop Process is active on Application State, but blocking is evaluated by Step Transition Rules.

Strict policy: active Stop Processes block step transition by default. A transition can pass only those Stop Processes that are explicitly allowed by that transition.

## Mapping

A definition that describes how application data is converted into Salesforce CRM records.

## Conversion

The process that creates or updates CRM records from completed applications.

CRM records are conversion results, not workflow state.

## Extension

Custom Apex code written outside the closed core package.

Extensions implement documented package contracts and are registered through settings.

## Product Owner Language

| Product request | E2E concept |
| --- | --- |
| Create a new form | Create a Process or Scenario |
| Create a new page on the form | Add a Step |
| Move pages in this flow | Change Step order or Transition rules in a Scenario |
| Run checks after this page | Add Validations or Jobs after Step submit |
| Run an external action | Add a Job that uses an Integration |
| Create a shorter mobile flow | Create a Scenario for a specific Consumer |
| Use another frontend | Add or enable another Consumer |
| Send completed data to CRM | Add or update Conversion Mapping |
