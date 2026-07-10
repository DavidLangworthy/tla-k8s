---------------------------- MODULE K8sPodNodeGpu ----------------------------
EXTENDS Naturals, FiniteSets

(*
This is an abstract model of Kubernetes-style Pod scheduling plus enough
node, GPU, and communication lifecycle to make failure behavior explicit.

It is intentionally not a copy of Kubernetes internals.  The abstraction keeps
the identities that matter for scheduler/plugin reasoning:

* a Pod incarnation is scheduled at most once;
* scheduler decisions are made from observed node state, which can be stale;
* actual kubelet admission and runtime health depend on actual node state;
* controller recreation is represented by generation[p].
*)

CONSTANTS
  Pods,
  Nodes,
  GpuPods,
  GatedPods,
  MaxGeneration,
  MaxBackoff,
  NodeCapacity

ASSUME
  /\ Pods # {}
  /\ Nodes # {}
  /\ GpuPods \subseteq Pods
  /\ GatedPods \subseteq Pods
  /\ MaxGeneration \in Nat
  /\ MaxBackoff \in Nat
  /\ NodeCapacity \in Nat \ {0}

NoNode == "NoNode"

PodPhases ==
  {"Gated", "Pending", "Backoff", "Unschedulable",
   "Reserved", "Waiting", "Bound", "Running", "Degraded",
   "Succeeded", "Failed", "Unknown", "Deleting", "Deleted"}

SchedulingPhases == {"Pending", "Backoff", "Unschedulable"}
ReservedPhases == {"Reserved", "Waiting"}
AssignedPhases == {"Bound", "Running", "Degraded", "Succeeded",
                   "Failed", "Unknown", "Deleting"}
RuntimePhases == {"Bound", "Running", "Degraded"}
TerminalPhases == {"Succeeded", "Failed", "Deleted"}

NodeStates == {"Ready", "NotReady", "Unknown", "Failed"}
GpuStates == {"Healthy", "Slow", "Faulty"}
LinkStates == {"Up", "Down"}

NodeOrNone == Nodes \cup {NoNode}
Generations == 0..MaxGeneration
BindTriples ==
  {<<p, g, n>> : p \in Pods, g \in Generations, n \in Nodes}

VARIABLES
  phase,
  nodeOf,
  reservation,
  gate,
  generation,
  backoff,
  bindHistory,
  nodeState,
  cordoned,
  gpuState,
  link,
  seenNodeState,
  seenCordoned,
  seenGpuState

vars ==
  << phase, nodeOf, reservation, gate, generation, backoff, bindHistory,
     nodeState, cordoned, gpuState, link,
     seenNodeState, seenCordoned, seenGpuState >>

NeedsGpu(p) == p \in GpuPods

CurrentBindNodes(p) ==
  {n \in Nodes : <<p, generation[p], n>> \in bindHistory}

HasNoCurrentBind(p) == CurrentBindNodes(p) = {}

AllocatedOn(n) ==
  {p \in Pods : nodeOf[p] = n /\ phase[p] \in AssignedPhases}

ReservedOn(n) ==
  {p \in Pods : reservation[p] = n}

UsedSlots(n) == Cardinality(AllocatedOn(n)) + Cardinality(ReservedOn(n))

HasCapacity(n) == UsedSlots(n) < NodeCapacity

ObservedSchedulable(p, n) ==
  /\ seenNodeState[n] = "Ready"
  /\ ~seenCordoned[n]
  /\ (~NeedsGpu(p) \/ seenGpuState[n] # "Faulty")

ActualStartable(p, n) ==
  /\ nodeState[n] = "Ready"
  /\ link[n] = "Up"
  /\ (~NeedsGpu(p) \/ gpuState[n] # "Faulty")

CanReserve(p) ==
  \E n \in Nodes:
    /\ ObservedSchedulable(p, n)
    /\ HasCapacity(n)

CanTryScheduling(p) ==
  /\ phase[p] \in SchedulingPhases
  /\ ~gate[p]
  /\ nodeOf[p] = NoNode
  /\ reservation[p] = NoNode
  /\ HasNoCurrentBind(p)
  /\ (phase[p] # "Backoff" \/ backoff[p] = 0)

ObservedFresh(n) ==
  /\ seenNodeState[n] = nodeState[n]
  /\ seenCordoned[n] = cordoned[n]
  /\ seenGpuState[n] = gpuState[n]

Init ==
  /\ phase = [p \in Pods |-> IF p \in GatedPods THEN "Gated" ELSE "Pending"]
  /\ nodeOf = [p \in Pods |-> NoNode]
  /\ reservation = [p \in Pods |-> NoNode]
  /\ gate = [p \in Pods |-> p \in GatedPods]
  /\ generation = [p \in Pods |-> 0]
  /\ backoff = [p \in Pods |-> 0]
  /\ bindHistory = {}
  /\ nodeState = [n \in Nodes |-> "Ready"]
  /\ cordoned = [n \in Nodes |-> FALSE]
  /\ gpuState = [n \in Nodes |-> "Healthy"]
  /\ link = [n \in Nodes |-> "Up"]
  /\ seenNodeState = [n \in Nodes |-> "Ready"]
  /\ seenCordoned = [n \in Nodes |-> FALSE]
  /\ seenGpuState = [n \in Nodes |-> "Healthy"]

RemoveGate(p) ==
  /\ gate[p]
  /\ phase[p] = "Gated"
  /\ gate' = [gate EXCEPT ![p] = FALSE]
  /\ phase' = [phase EXCEPT ![p] = "Pending"]
  /\ UNCHANGED << nodeOf, reservation, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

Reserve(p, n) ==
  /\ CanTryScheduling(p)
  /\ ObservedSchedulable(p, n)
  /\ HasCapacity(n)
  /\ reservation' = [reservation EXCEPT ![p] = n]
  /\ phase' = [phase EXCEPT ![p] = "Reserved"]
  /\ backoff' = [backoff EXCEPT ![p] = 0]
  /\ UNCHANGED << nodeOf, gate, generation, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

NoFit(p) ==
  /\ CanTryScheduling(p)
  /\ ~CanReserve(p)
  /\ phase' = [phase EXCEPT ![p] = "Unschedulable"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

RequeueIfFit(p) ==
  /\ phase[p] = "Unschedulable"
  /\ ~gate[p]
  /\ CanReserve(p)
  /\ phase' = [phase EXCEPT ![p] = "Pending"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

BackoffTick(p) ==
  /\ phase[p] = "Backoff"
  /\ backoff[p] > 0
  /\ backoff' = [backoff EXCEPT ![p] = backoff[p] - 1]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

BackoffReady(p) ==
  /\ phase[p] = "Backoff"
  /\ backoff[p] = 0
  /\ phase' = [phase EXCEPT ![p] = "Pending"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

PermitWait(p) ==
  /\ phase[p] = "Reserved"
  /\ reservation[p] # NoNode
  /\ phase' = [phase EXCEPT ![p] = "Waiting"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

PermitApprove(p) ==
  /\ phase[p] = "Waiting"
  /\ reservation[p] # NoNode
  /\ phase' = [phase EXCEPT ![p] = "Reserved"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

PermitDenyOrTimeout(p) ==
  /\ phase[p] \in ReservedPhases
  /\ reservation[p] # NoNode
  /\ reservation' = [reservation EXCEPT ![p] = NoNode]
  /\ phase' = [phase EXCEPT ![p] = "Backoff"]
  /\ backoff' = [backoff EXCEPT ![p] = MaxBackoff]
  /\ UNCHANGED << nodeOf, gate, generation, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

Bind(p) ==
  /\ phase[p] = "Reserved"
  /\ reservation[p] # NoNode
  /\ HasNoCurrentBind(p)
  /\ nodeOf' = [nodeOf EXCEPT ![p] = reservation[p]]
  /\ bindHistory' =
       bindHistory \cup {<<p, generation[p], reservation[p]>>}
  /\ reservation' = [reservation EXCEPT ![p] = NoNode]
  /\ phase' = [phase EXCEPT ![p] = "Bound"]
  /\ UNCHANGED << gate, generation, backoff,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

KubeletStart(p) ==
  /\ phase[p] = "Bound"
  /\ nodeOf[p] \in Nodes
  /\ ActualStartable(p, nodeOf[p])
  /\ phase' =
       [phase EXCEPT ![p] =
          IF NeedsGpu(p) /\ gpuState[nodeOf[p]] = "Slow"
          THEN "Degraded"
          ELSE "Running"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

DetectLostContact(p) ==
  /\ phase[p] \in RuntimePhases
  /\ nodeOf[p] \in Nodes
  /\ (link[nodeOf[p]] = "Down"
      \/ nodeState[nodeOf[p]] \in {"NotReady", "Unknown", "Failed"})
  /\ phase' = [phase EXCEPT ![p] = "Unknown"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

MarkGpuSlow(p) ==
  /\ phase[p] = "Running"
  /\ nodeOf[p] \in Nodes
  /\ NeedsGpu(p)
  /\ gpuState[nodeOf[p]] = "Slow"
  /\ phase' = [phase EXCEPT ![p] = "Degraded"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

GpuFaultFailsPod(p) ==
  /\ phase[p] \in RuntimePhases
  /\ nodeOf[p] \in Nodes
  /\ NeedsGpu(p)
  /\ gpuState[nodeOf[p]] = "Faulty"
  /\ phase' = [phase EXCEPT ![p] = "Failed"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

EvictSlowPod(p) ==
  /\ phase[p] = "Degraded"
  /\ nodeOf[p] \in Nodes
  /\ NeedsGpu(p)
  /\ gpuState[nodeOf[p]] = "Slow"
  /\ phase' = [phase EXCEPT ![p] = "Failed"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

PodCompletes(p) ==
  /\ phase[p] \in {"Running", "Degraded"}
  /\ phase' = [phase EXCEPT ![p] = "Succeeded"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

PodCrashes(p) ==
  /\ phase[p] \in {"Running", "Degraded"}
  /\ phase' = [phase EXCEPT ![p] = "Failed"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

DeleteFinishedPod(p) ==
  /\ phase[p] \in {"Succeeded", "Failed", "Unknown"}
  /\ phase' = [phase EXCEPT ![p] = "Deleting"]
  /\ UNCHANGED << nodeOf, reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

FinishDeletion(p) ==
  /\ phase[p] = "Deleting"
  /\ phase' = [phase EXCEPT ![p] = "Deleted"]
  /\ nodeOf' = [nodeOf EXCEPT ![p] = NoNode]
  /\ UNCHANGED << reservation, gate, generation, backoff, bindHistory,
                  nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

RecreatePod(p) ==
  /\ phase[p] = "Deleted"
  /\ generation[p] < MaxGeneration
  /\ generation' = [generation EXCEPT ![p] = generation[p] + 1]
  /\ phase' = [phase EXCEPT ![p] = "Pending"]
  /\ nodeOf' = [nodeOf EXCEPT ![p] = NoNode]
  /\ reservation' = [reservation EXCEPT ![p] = NoNode]
  /\ gate' = [gate EXCEPT ![p] = FALSE]
  /\ backoff' = [backoff EXCEPT ![p] = 0]
  /\ UNCHANGED << bindHistory, nodeState, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

CordonNode(n) ==
  /\ ~cordoned[n]
  /\ cordoned' = [cordoned EXCEPT ![n] = TRUE]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, nodeState, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

UncordonNode(n) ==
  /\ cordoned[n]
  /\ cordoned' = [cordoned EXCEPT ![n] = FALSE]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, nodeState, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

NodeNotReady(n) ==
  /\ nodeState[n] = "Ready"
  /\ nodeState' = [nodeState EXCEPT ![n] = "NotReady"]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

NodeUnknown(n) ==
  /\ nodeState[n] \in {"Ready", "NotReady"}
  /\ nodeState' = [nodeState EXCEPT ![n] = "Unknown"]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

NodeFails(n) ==
  /\ nodeState[n] # "Failed"
  /\ nodeState' = [nodeState EXCEPT ![n] = "Failed"]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

NodeRecovers(n) ==
  /\ nodeState[n] # "Ready"
  /\ nodeState' = [nodeState EXCEPT ![n] = "Ready"]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, cordoned, gpuState, link,
                  seenNodeState, seenCordoned, seenGpuState >>

GpuSlows(n) ==
  /\ gpuState[n] = "Healthy"
  /\ gpuState' = [gpuState EXCEPT ![n] = "Slow"]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, nodeState, cordoned, link,
                  seenNodeState, seenCordoned, seenGpuState >>

GpuFaults(n) ==
  /\ gpuState[n] # "Faulty"
  /\ gpuState' = [gpuState EXCEPT ![n] = "Faulty"]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, nodeState, cordoned, link,
                  seenNodeState, seenCordoned, seenGpuState >>

GpuHeals(n) ==
  /\ gpuState[n] # "Healthy"
  /\ gpuState' = [gpuState EXCEPT ![n] = "Healthy"]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, nodeState, cordoned, link,
                  seenNodeState, seenCordoned, seenGpuState >>

LinkDown(n) ==
  /\ link[n] = "Up"
  /\ link' = [link EXCEPT ![n] = "Down"]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, nodeState, cordoned, gpuState,
                  seenNodeState, seenCordoned, seenGpuState >>

LinkUp(n) ==
  /\ link[n] = "Down"
  /\ link' = [link EXCEPT ![n] = "Up"]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, nodeState, cordoned, gpuState,
                  seenNodeState, seenCordoned, seenGpuState >>

RefreshObservation(n) ==
  /\ link[n] = "Up"
  /\ seenNodeState' = [seenNodeState EXCEPT ![n] = nodeState[n]]
  /\ seenCordoned' = [seenCordoned EXCEPT ![n] = cordoned[n]]
  /\ seenGpuState' = [seenGpuState EXCEPT ![n] = gpuState[n]]
  /\ UNCHANGED << phase, nodeOf, reservation, gate, generation, backoff,
                  bindHistory, nodeState, cordoned, gpuState, link >>

SchedulerNext ==
  \/ \E p \in Pods: RemoveGate(p)
  \/ \E p \in Pods, n \in Nodes: Reserve(p, n)
  \/ \E p \in Pods: NoFit(p)
  \/ \E p \in Pods: RequeueIfFit(p)
  \/ \E p \in Pods: BackoffTick(p)
  \/ \E p \in Pods: BackoffReady(p)
  \/ \E p \in Pods: PermitWait(p)
  \/ \E p \in Pods: PermitApprove(p)
  \/ \E p \in Pods: PermitDenyOrTimeout(p)
  \/ \E p \in Pods: Bind(p)

RuntimeNext ==
  \/ \E p \in Pods: KubeletStart(p)
  \/ \E p \in Pods: DetectLostContact(p)
  \/ \E p \in Pods: MarkGpuSlow(p)
  \/ \E p \in Pods: GpuFaultFailsPod(p)
  \/ \E p \in Pods: EvictSlowPod(p)
  \/ \E p \in Pods: PodCompletes(p)
  \/ \E p \in Pods: PodCrashes(p)

ControllerNext ==
  \/ \E p \in Pods: DeleteFinishedPod(p)
  \/ \E p \in Pods: FinishDeletion(p)
  \/ \E p \in Pods: RecreatePod(p)

EnvironmentNext ==
  \/ \E n \in Nodes: CordonNode(n)
  \/ \E n \in Nodes: UncordonNode(n)
  \/ \E n \in Nodes: NodeNotReady(n)
  \/ \E n \in Nodes: NodeUnknown(n)
  \/ \E n \in Nodes: NodeFails(n)
  \/ \E n \in Nodes: NodeRecovers(n)
  \/ \E n \in Nodes: GpuSlows(n)
  \/ \E n \in Nodes: GpuFaults(n)
  \/ \E n \in Nodes: GpuHeals(n)
  \/ \E n \in Nodes: LinkDown(n)
  \/ \E n \in Nodes: LinkUp(n)
  \/ \E n \in Nodes: RefreshObservation(n)

Next == SchedulerNext \/ RuntimeNext \/ ControllerNext \/ EnvironmentNext

StableNext ==
  \/ \E p \in Pods: RemoveGate(p)
  \/ \E p \in Pods, n \in Nodes: Reserve(p, n)
  \/ \E p \in Pods: Bind(p)
  \/ \E p \in Pods: KubeletStart(p)
  \/ \E p \in Pods: PodCompletes(p)
  \/ \E n \in Nodes: RefreshObservation(n)

FairStableProgress ==
  /\ \A p \in Pods: WF_vars(RemoveGate(p))
  /\ \A p \in Pods, n \in Nodes: WF_vars(Reserve(p, n))
  /\ \A p \in Pods: WF_vars(Bind(p))
  /\ \A p \in Pods: WF_vars(KubeletStart(p))

FairFailureDetection ==
  /\ \A p \in Pods: WF_vars(DetectLostContact(p))
  /\ \A p \in Pods: WF_vars(MarkGpuSlow(p))
  /\ \A p \in Pods: WF_vars(GpuFaultFailsPod(p))
  /\ \A p \in Pods: WF_vars(EvictSlowPod(p))
  /\ \A n \in Nodes: WF_vars(RefreshObservation(n))

SafetySpec == Init /\ [][Next]_vars

StableSpec == Init /\ [][StableNext]_vars /\ FairStableProgress

FailureManifestSpec == Init /\ [][Next]_vars /\ FairFailureDetection

TypeOK ==
  /\ phase \in [Pods -> PodPhases]
  /\ nodeOf \in [Pods -> NodeOrNone]
  /\ reservation \in [Pods -> NodeOrNone]
  /\ gate \in [Pods -> BOOLEAN]
  /\ generation \in [Pods -> Generations]
  /\ backoff \in [Pods -> 0..MaxBackoff]
  /\ bindHistory \subseteq BindTriples
  /\ nodeState \in [Nodes -> NodeStates]
  /\ cordoned \in [Nodes -> BOOLEAN]
  /\ gpuState \in [Nodes -> GpuStates]
  /\ link \in [Nodes -> LinkStates]
  /\ seenNodeState \in [Nodes -> NodeStates]
  /\ seenCordoned \in [Nodes -> BOOLEAN]
  /\ seenGpuState \in [Nodes -> GpuStates]

NoLeakedReservations ==
  \A p \in Pods:
    /\ (reservation[p] # NoNode => phase[p] \in ReservedPhases)
    /\ (phase[p] \in ReservedPhases => reservation[p] \in Nodes)
    /\ (reservation[p] # NoNode => nodeOf[p] = NoNode)

SingleBinding ==
  \A p \in Pods, g \in Generations:
    Cardinality({n \in Nodes : <<p, g, n>> \in bindHistory}) <= 1

AssignedImpliesBindHistory ==
  \A p \in Pods:
    (nodeOf[p] # NoNode => <<p, generation[p], nodeOf[p]>> \in bindHistory)

UnassignedPhasesHaveNoNode ==
  \A p \in Pods:
    (phase[p] \in {"Gated", "Pending", "Backoff", "Unschedulable",
                   "Reserved", "Waiting", "Deleted"}
      => nodeOf[p] = NoNode)

NonReservedPhasesHaveNoReservation ==
  \A p \in Pods:
    (phase[p] \notin ReservedPhases => reservation[p] = NoNode)

GateConsistency ==
  \A p \in Pods: (gate[p] <=> phase[p] = "Gated")

NoCapacityOvercommit ==
  \A n \in Nodes: UsedSlots(n) <= NodeCapacity

SafetyInvariants ==
  /\ TypeOK
  /\ NoLeakedReservations
  /\ SingleBinding
  /\ AssignedImpliesBindHistory
  /\ UnassignedPhasesHaveNoNode
  /\ NonReservedPhasesHaveNoReservation
  /\ GateConsistency
  /\ NoCapacityOvercommit

StableEventuallyServed ==
  \A p \in Pods:
    <> (phase[p] \in {"Running", "Degraded", "Succeeded"})

PersistentContactLossManifests ==
  \A p \in Pods, n \in Nodes:
    (<>[] (nodeOf[p] = n /\ phase[p] \in RuntimePhases /\ link[n] = "Down"))
      => <> (phase[p] \in {"Unknown", "Failed", "Deleting", "Deleted"})

PersistentNodeFailureManifests ==
  \A p \in Pods, n \in Nodes:
    (<>[] (nodeOf[p] = n /\ phase[p] \in RuntimePhases
           /\ nodeState[n] \in {"NotReady", "Unknown", "Failed"}))
      => <> (phase[p] \in {"Unknown", "Failed", "Deleting", "Deleted"})

PersistentSlowGpuHandled ==
  \A p \in Pods, n \in Nodes:
    (<>[] (nodeOf[p] = n /\ phase[p] = "Degraded"
           /\ NeedsGpu(p) /\ gpuState[n] = "Slow"))
      => <> (phase[p] \in {"Succeeded", "Failed", "Deleting", "Deleted"})

PersistentReachabilityRefreshesObservation ==
  \A n \in Nodes:
    (<>[] (link[n] = "Up")) => []<>(ObservedFresh(n))

THEOREM SafetyTheorem ==
  SafetySpec => []SafetyInvariants

=============================================================================
