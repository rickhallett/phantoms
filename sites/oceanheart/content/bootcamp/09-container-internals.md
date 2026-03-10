+++
title = "Container Internals"
date = "2026-03-10"
description = "Namespaces, cgroups, overlayfs. What a container actually is at the kernel level."
tags = ["containers", "docker", "namespaces", "cgroups", "bootcamp"]
step = 9
tier = 3
estimate = "4 hours"
+++

Step 9 of 12 in the Agentic Engineering Bootcamp.

---

Namespaces, cgroups, overlayfs. What a container actually is at the kernel level.

## Key Topics

- Linux namespaces - PID, network, mount, user, UTS, IPC
- cgroups - resource limits and accounting
- overlayfs - layered filesystems and image construction
- Building a container from scratch with unshare
- How Docker and OCI runtimes compose these primitives
- Agent sandboxing - why containers matter for agentic systems
- Debugging container networking and filesystem issues

---

Full content in development. [Step 1: The Unix Process Model](/bootcamp/01-process-model/) is available as a sample.
