+++
title = "The Agentic Engineering Bootcamp"
date = "2026-03-18"
description = "A first-principles curriculum for SWEs who steer AI agents. The subject matter is the execution stack itself: Linux, bash, Python, composable tools. Ordered by what you cannot delegate."
tags = ["bootcamp", "agentic-engineering", "linux", "learning"]
draft = true
+++

{{< draft-notice >}}

## The observation

I spent a month building software with AI agents and tracking where things went wrong. The taxonomy of agent-native software that came out of it showed something I should have expected: 75% of software categories reduce to CLI and API operations. Pipes, text streams, file descriptors, process management. The agent-native stack is Linux.

This matters because agents already operate at this level. They generate shell scripts, construct pipelines, manage processes, write Makefiles, and manipulate filesystems. They do it constantly, and they do it with confidence regardless of whether the output is correct.

## The problem

When an agent constructs a pipeline that silently drops data on a broken pipe, or generates a shell script with a quoting bug that only surfaces on filenames containing spaces, or claims a process is healthy when it's a zombie - the human operator has to catch it. That's the job now. You steer and verify.

If you don't understand what a file descriptor is, you can't diagnose why an agent's redirection is wrong. If you don't understand process groups and signals, you can't tell whether an agent's cleanup logic actually works. If you don't understand how `set -euo pipefail` interacts with subshells, you can't evaluate whether an agent's error handling is real or cosmetic.

This creates what I've been calling an oracle problem. The human is supposed to be the final verification layer. But if the human doesn't understand the substrate, errors pass through every layer uncaught. The verifier becomes the vulnerability.

## What I built

A structured self-study curriculum. Twelve steps, ordered by a dependency graph, starting from the process model and building up through shell, filesystems, text processing, Python CLI tools, Make, git internals, process observation, containers, networking, and process supervision.

The ordering is not arbitrary. Step 1 is the Unix process model - fork, exec, file descriptors, pipes, signals - because everything else composes on top of it. Shell is step 2 because shell is the language that orchestrates processes. Filesystems are step 3 because state lives on disk. Each step uses the primitives from the steps below it.

The dependency graph looks like this:

```
Process model
  -> Shell language
     -> Text pipelines (grep/sed/awk/jq)
     -> Make/Just (orchestrates shell recipes)
     -> Python CLI tools (when shell hits its ceiling)
  -> Filesystem as state
     -> Git internals (versioned filesystem)
  -> Process observation (strace/lsof/ss)
     -> Container internals (namespaced processes)
  -> Networking
  -> Process supervision
  -> Advanced bash
```

If you understand the bottom, the top is tractable. If you skip the bottom, you memorise commands without understanding what they do.

## How I ranked it

Three criteria for ordering:

**Compositional leverage.** Does understanding this concept make everything above it easier? The process model scores highest because file descriptors, pipes, and signals appear in every subsequent step. Shell scores second because it's the composition language for everything else.

**Return per hour.** How much capability does each hour of study produce? Text pipelines score well here - a few hours with grep, sed, awk, and jq opens up a large surface area of practical work.

**Irreplaceability.** This is the one that matters for agentic engineering specifically. The question is: can an agent compensate for the operator's ignorance, or must the operator know this? If an agent generates a shell script and you don't understand process substitution, the agent can't help you verify its own output. You either understand it or you don't, and the agent's confidence is uninformative either way.

The third criterion is what determines the tier structure. Tier 1 (process model, shell, filesystems) contains the knowledge that is hardest to delegate. Tier 4 (networking, process supervision, advanced bash) contains material you can often look up or ask an agent about when you need it, because you have the foundational model to evaluate the answer.

## What it is not

This is self-study material I wrote for myself and am publishing because it might be useful to others. It is not a certified programme. There is no credential at the end. The only test is whether you can read agent-generated system-level code and tell when it's wrong.

Each step has interactive challenges you run in the same environment you're learning about. There are no separate lab setups. The terminal you're reading in is the terminal you practice in.

Where a concept has a good origin story - Ken Thompson's fork, Doug McIlroy's pipes, Linus Torvalds's git object model - I include it. Not for decoration. Historical context creates memory anchors that make the mental model stick.

Every section connects explicitly to agentic engineering. The question "why does this matter when agents write code?" gets a concrete answer for every topic. The process model section, for instance, covers how agents mishandle zombie processes and why `wait` matters in generated cleanup scripts. The shell section covers the quoting bugs that agents produce most frequently and what makes them hard to spot in review.

## Who this is for

Software engineers who work with AI agents and want to be competent at governing the system-level output. You probably already write code daily. You might use agents for development. You may have noticed that you sometimes can't tell whether an agent's shell script is correct, and that bothers you.

The estimated time is 50 to 65 hours of focused study. That's roughly a week and a half if you're doing it full-time, or a few weeks of evenings. The first three steps (process model, shell, filesystem) are the critical ones - maybe 20 hours - and they change how you read everything an agent produces at the system level.

## Source

- Curriculum: `docs/bootcamp/README.md`
- Step files: `docs/bootcamp/01-process-model.md` through `12-advanced-bash.md`
- Derived from: `docs/research/agent-native-software-taxonomy.md`
- Conventions: no emojis, no em-dashes, all examples runnable on Arch/Debian/Ubuntu
