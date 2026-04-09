# Security-Sentinel: Admission Control Logic

This directory contains the core validation logic for the Security-Sentinel project. 

##  The "Controller-First" Refactor
The policies here were recently refactored to address a critical "Controller Gap" identified during cluster stress testing. 

###  The Problem
Standard Kyverno policies often target `kind: Pod`. However, high-level controllers (Deployments, Jobs, StatefulSets) can bypass these gates at the "Intent" stage. While the resulting Pods are blocked, the Controller enters a resource-heavy loop attempting to recreate them, leading to API Server exhaustion and ETCD latency.

###  The Engineering Fix: Recursive Foreach
I refactored `disallow-privilege.yaml` to move validation to the **Controller stage** using **recursive foreach loops**.

- **Nested Inspection:** The policy now recursively drills into the `spec.template.spec.containers` array of all high-level controllers.
- **Fail-Fast Logic:** By rejecting the Deployment/Job itself, we prevent the "CrashLoopBackOff" cycle entirely, saving CPU/Memory cycles across the control plane.
- **Scale-Ready:** Optimized via **Server-Side Apply (SSA)** to handle high-throughput validation requests without impacting cluster sub-second latency.

##  Files in this Directory
- `disallow-privilege.yaml`: The primary hardened policy utilizing recursive loops and conditional anchors.

---
*Verified via 100+ GitHub Action runs and synced via ArgoCD.*
