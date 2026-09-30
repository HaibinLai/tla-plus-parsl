# Executor and provider model map

The executor abstraction is intentionally split into local execution and provider-backed
execution. The main bounded model is ParslExecutorKinds.tla; focused models refine its
contracts for HTEX, MPI, Work Queue, TaskVine, Flux, Globus Compute, and provider families.

## Source hierarchy

| Source class/path | Model role |
| --- | --- |
| parsl/executors/threads.py::ThreadPoolExecutor | provider-free executor; local worker slots are immediately available |
| parsl/executors/high_throughput/executor.py::HighThroughputExecutor | manager/worker registration, task/result transport, heartbeat, and provider-backed slots |
| parsl/executors/high_throughput/mpi_executor.py::MPIExecutor | HTEX transport plus node/rank allocation and resource release |
| parsl/executors/workqueue/executor.py::WorkQueueExecutor | provider-backed submission and collector result lifecycle |
| parsl/executors/taskvine/executor.py::TaskVineExecutor | provider-backed submission and collector result lifecycle |
| parsl/executors/flux/executor.py::FluxExecutor | provider status and cancellation around a Flux job |
| parsl/executors/globus_compute.py::GlobusComputeExecutor | callback/result propagation without a local worker pool |
| parsl/executors/status_handling.py::BlockProviderExecutor | scale-out, scale-in, job/block ownership, status polling, drain, and bad-state cleanup |

In ParslExecutorKinds.tla, ProviderRequired(e) distinguishes the local path from manager
and provider-backed paths. workerSlots is the bounded resource capacity, resourceRequest
models a provider submission, and managerReady separates a provisioned block from a registered
worker manager. Admission requires a live provider when one is required, a ready manager for
remote executors, and a positive slot count.

## Safety contracts

The unified model checks:

- tasks are rejected when provider/manager/slot admission is not satisfied;
- a provider failure removes worker capacity and drains queued/running work;
- scale-in cannot remove capacity still occupied by a running task;
- local executors do not acquire provider state;
- unsupported resource specifications do not become accepted submissions;
- executor drain leaves no queued or running work.

The focused models then refine implementation-specific boundaries, including HTEX registration
and result frames, MPI rank allocation, Work Queue/TaskVine duplicate reports, Flux cancellation,
callback-based Globus/Radical Pilot results, and provider status/cancel shape validation.
Their current/fixed configurations are included in the TLC sweep and corresponding runtime
probes are listed in the bug ledger.
