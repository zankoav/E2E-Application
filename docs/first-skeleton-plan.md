# First Skeleton Plan

## Purpose

Define the first implementation slice for the E2E Application managed package.

The goal is to create a minimal closed core that proves the architecture without building the full framework at once.

## First Slice Goal

Support this flow:

```text
InitApplication
  -> create Application__c
  -> load Process Definition
  -> initialize State
  -> return Snapshot
```

This slice should not implement full jobs, conversion, mappings, or complex rules yet.

## Step 1: Core Metadata

Create the minimal runtime objects:

| Metadata | Purpose |
| --- | --- |
| `Application__c` | Root process record. |
| `Application_Data__c` | Dynamic application data. |
| `Application_Event__c` | Audit/debug events. |

Create the minimal definition container:

| Metadata | Purpose |
| --- | --- |
| `Process_Definition__mdt` | Stores `Definition_JSON__c` for process definitions. |

Jobs and conversion objects can wait until the first Init/Snapshot flow is stable.

## Step 2: Core Apex Models

Create small DTO/context classes:

| Class | Purpose |
| --- | --- |
| `ApplicationContext` | Runtime context for one command. |
| `ApplicationSnapshot` | API response model. |
| `CommandResult` | Common command result wrapper. |
| `ProcessDefinition` | Parsed process definition model. |

These classes should stay small and stable.

## Step 3: Definition Loading

Create:

| Class | Purpose |
| --- | --- |
| `DefinitionResolver` | Loads active `Process_Definition__mdt`. |
| `DefinitionParser` | Parses `Definition_JSON__c`. |
| `DefinitionValidator` | Validates required definition shape. |

First validation should check only required fields:

- process key
- process version
- at least one scenario
- scenario initial step
- steps referenced by scenario exist

## Step 4: State Store

Create:

| Class | Purpose |
| --- | --- |
| `ApplicationStateStore` | Creates and loads `Application__c`. |
| `ApplicationEventStore` | Writes basic events. |

First events:

```text
ApplicationInitialized
SnapshotReturned
```

## Step 5: InitApplication Command

Create:

| Class | Purpose |
| --- | --- |
| `InitApplicationCommand` | Input DTO. |
| `InitApplicationHandler` | Executes init flow. |

First request fields:

```text
consumerKey
processKey
scenarioKey
externalReference
```

First behavior:

- load process definition
- resolve scenario
- create `Application__c`
- set initial step
- write `ApplicationInitialized` event
- return Snapshot

## Step 6: Snapshot Builder

Create:

| Class | Purpose |
| --- | --- |
| `SnapshotBuilder` | Builds API-friendly Snapshot. |

Snapshot should return stable API contract keys, not Salesforce field API names.

First snapshot shape:

```json
{
  "application": {
    "id": "...",
    "processKey": "...",
    "scenarioKey": "...",
    "status": "InProgress",
    "currentStep": "..."
  },
  "steps": [],
  "data": {},
  "jobs": [],
  "stopProcesses": [],
  "availableActions": []
}
```

## Step 7: REST Controller

Create the first thin REST controller method for `InitApplication`.

Controller responsibilities:

- parse request
- call command handler
- serialize response
- handle structured errors

Controller should not own process decisions.

## Not In First Slice

Do not implement yet:

- full SubmitStep
- Job Engine
- Conversion Engine
- Mapping Engine
- Integration adapters
- complex Rule Engine
- namespace/package creation commands
- Salesforce org deployment

## Success Criteria

The first slice is successful when:

- process definition can be loaded from Custom Metadata
- Application can be initialized
- initial state is persisted
- Snapshot is returned through API-friendly model
- basic events are written
- core remains small and understandable

