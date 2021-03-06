-------------------------------- MODULE rwf_list --------------------------------
EXTENDS Integers, Sequences, TLC, FiniteSets
CONSTANTS N, MaxOps, MaxElmts, Values

Dft_Values == {10, 20}

Procs == 1..N 
Elmts == 1..MaxElmts

(*--algorithm rwf_list

variables
    ops = [j \in Procs |-> {}]; \* to broadcast operations
    opcount = 0;
    elmtcount = 0;
    history = <<>>; \* history variable
    printed = 0;

define
    Dft_eset_content == [p_ini |-> -1, v_inn |-> 0, v_acq |-> [v |-> 0, t |-> -1, id |-> -1]]

    Inverse_leid(l_set, leid) == CHOOSE x \in Elmts : l_set[x] = leid
    E_count(l_set) == Cardinality({x \in Elmts : l_set[x] /= -1})
    Leid_order(l_set) == SortSeq([i \in 1..E_count(l_set) |-> l_set[i]], <)
    E_order(l_set) == [i \in DOMAIN Leid_order(l_set) 
                                |-> Inverse_leid(l_set, Leid_order(l_set)[i])]
    Value(c) == IF c.v_acq = [v |-> 0, t |-> -1, id |-> -1] THEN c.v_inn ELSE c.v_acq.v
    Lt(acq) == IF acq = [v |-> 0, t |-> -1, id |-> -1] THEN "null" ELSE <<acq.t, acq.id - 1>>

    Leid(l_set, e) == IF e = 0 THEN 0 ELSE l_set[e]
    Leid_Gen(p, level, self) == p + self * ((N + 1) ^ level)
    Leid_New(l_set, level, self, prev, e) == IF l_set[e] /= -1 THEN l_set[e]
                                             ELSE Leid_Gen(Leid(l_set, prev), level, self)
    
    Min(a, b) == IF a <= b THEN a ELSE b
    Max(a, b) == IF a <= b THEN b ELSE a
    Max_RH(a, b) == [j \in Procs |-> Max(a[j], b[j])]
    
    \* read operations
    _Lookup(e_set, e) == e_set[e] /= Dft_eset_content

    \* prepare phases
    _Add(e_set, t_set, l_set, level, self, prev, e, x) == 
        IF ~_Lookup(e_set, e) /\ (prev = 0 \/ (_Lookup(e_set, prev) /\ l_set[prev] /= -1))
        THEN
            [key |-> e, val |-> x, p_ini |-> self, rh |-> t_set[e],
             pos |-> Leid_New(l_set, level, self, prev, e), level |-> level - 1]
        ELSE [key |-> -1]
    
    _Update(e_set, t_set, e, i, t, self) == 
        IF _Lookup(e_set, e) THEN [key |-> e, val |-> i, rh |-> t_set[e], lt |-> <<t+1, self>>]
        ELSE [key |-> -1]
    
    _Remove(e_set, t_set, self, e) == 
        IF _Lookup(e_set, e) THEN 
            [key |-> e, rh |-> [j \in Procs |-> IF j = self THEN t_set[e][j] + 1 
                                                           ELSE t_set[e][j]]]
        ELSE [key |-> -1] 
end define;

\* send an operation to all
macro Broadcast(o, params) begin 
    ops := [j \in Procs |-> IF j = self THEN ops[j] 
                            ELSE ops[j] \union {[op |-> o, num |-> opcount, p |-> params]}];
end macro;

\* effect of remove operation
macro Remove(e, rhp) begin
    if \E j \in Procs: t_set[e][j] < rhp[j] then
        t_set[e] := Max_RH(rhp, t_set[e]);
        e_set[e] := Dft_eset_content;
    end if;
end macro;

\* effect of add operation
macro Add(e, x, p_ini, rh, pos, nlevel) begin
    if \E j \in Procs: t_set[e][j] < rh[j] then
        t_set[e] := Max_RH(rh, t_set[e]);
        if rh = t_set[e] then
            e_set[e] := [p_ini |-> p_ini, v_inn |-> x, v_acq |-> [v |-> 0, t |-> -1, id |-> -1]];
        else e_set[e] := Dft_eset_content;
        end if;
    else
        if rh = t_set[e] /\ p_ini > e_set[e].p_ini then
            e_set[e] := [p_ini |-> p_ini, v_inn |-> x, v_acq |-> e_set[e].v_acq];
        end if;
    end if;
    level := Min(level, nlevel);
    l_set[e] := pos;
end macro;

\* effect of update operation
macro Update(e, i, rh, lts) begin
    if \E j \in Procs: t_set[e][j] < rh[j] then
        t_set[e] := Max_RH(rh, t_set[e]);
        if rh = t_set[e] then
            e_set[e] := [p_ini |-> -1, v_inn |-> 0, v_acq |-> [v |-> i, t |-> lts[1], id |-> lts[2]]];
        else e_set[e] := Dft_eset_content;
        end if;
    else
        with old_acq = e_set[e].v_acq do
            if rh = t_set[e] /\ (old_acq.t < lts[1] \/ (old_acq.t = lts[1] /\ old_acq.id < lts[2])) then
                e_set[e] := [p_ini |-> e_set[e].p_ini, v_inn |-> e_set[e].v_inn, v_acq |-> [v |-> i, t |-> lts[1], id |-> lts[2]]];
            end if;
        end with;
    end if;
    lt_set[e] := Max(lt_set[e], lts[1]);
end macro;

\* receive and process operations, one by one
macro Effect() begin 
    if ops[self] /= {} then
        with msg \in ops[self] do
            if msg.op = "A" then
                Add(msg.p.key, msg.p.val, msg.p.p_ini, msg.p.rh, msg.p.pos, msg.p.level);
            elsif msg.op = "R" then
                Remove(msg.p.key, msg.p.rh);
            elsif msg.op = "U" then
                Update(msg.p.key, msg.p.val, msg.p.rh, msg.p.lt);
            end if;
            history := Append(history, <<msg.num, self, "effect">>);
            ops[self] := ops[self] \ {msg}; \* clear processed operation
        end with;
    end if;
end macro;

process Set \in Procs
variables
    e_set = [j \in Elmts |-> Dft_eset_content];
    t_set = [j \in Elmts |-> [k \in Procs |-> 0]];
    l_set = [j \in Elmts |-> -1]; \* local set of leids
    level = MaxElmts;
    lt_set = [j \in Elmts |-> 0]; \* lamport clock
begin Main:
    while TRUE do
        either
            if opcount < MaxOps then
                opcount := opcount + 1;
                either \* Add
                    either
                        \* add a new element
                        if elmtcount < MaxElmts then
                            with e = elmtcount + 1, v \in Values, prev \in {0} \union Elmts,
                                addp = _Add(e_set, t_set, l_set, level, self, prev, e, v) do 
                                \* select a random not new element to add
                                history := Append(history, <<opcount, self, "Add", prev, e, v>>);
                                if addp.key /= -1 then
                                    Broadcast("A", addp);
                                    Add(e, v, self, addp.rh, addp.pos, addp.level);
                                    elmtcount := elmtcount + 1;
                                end if;
                            end with;
                        end if;
                    or
                        \* Select randomly an old but not concurrent-init element to add:
                        \*
                        \* e \in {x \in Elmts : e_set[x] /= Dft_eset_content
                        \*                      \/ t_set[x] /= [k \in Procs |-> 0]
                        \*                      \/ l_set[x] /= -1},
                        \*
                        \* This means that there is not any update of element e executed on x. 
                        \* However this will violate SEC. 
                        \* This is a bug found in implementation. Not a bug of the algorithm, 
                        \* since the algorithm assumes that all newly inserted element are unique. 
                        \* The readd can only be called on the elements whose leid (position id) 
                        \* is fixed, which is:
                        \*
                        \* e \in {x \in Elmts : l_set[x] /= -1}
                        \*
                        \* This has been fixed in the CRDT-Redis list implementations, with a 
                        \* corner case checking.
                        with e \in {x \in Elmts : l_set[x] /= -1},
                             v \in Values, prev \in {0} \union Elmts,
                             addp = _Add(e_set, t_set, l_set, level, self, prev, e, v) do 
                            history := Append(history, <<opcount, self, "Add", prev, e, v>>);
                            if addp.key /= -1 then
                                Broadcast("A", addp);
                                Add(e, v, self, addp.rh, addp.pos, addp.level);
                            end if;
                        end with;
                    end either;
                or \* Remove: select a random element to remove
                    with e \in Elmts, rmvp = _Remove(e_set, t_set, self, e) do 
                        history := Append(history, <<opcount, self, "Rmv", e>>);
                        if rmvp.key /= -1 then
                            Broadcast("R", rmvp);
                            Remove(e, rmvp.rh);
                        end if;
                    end with;
                or \* Update: select a random element-increment to update
                    with e \in Elmts, i \in Values,
                         updp = _Update(e_set, t_set, e, i, lt_set[e], self) do
                        history := Append(history, <<opcount, self, "Upd", e, i>>);
                        if updp.key /= -1 then
                            Broadcast("U", updp);
                            Update(e, i, updp.rh, updp.lt);
                        end if;
                    end with;
                end either;
            end if;
        or 
            Effect();
            if self = 1 /\ printed = 0 /\ opcount = MaxOps /\ ops = [j \in Procs |-> {}] then
                assert E_count(l_set) = elmtcount;
                print history;
                print [i \in DOMAIN E_order(l_set) |-> 
                                <<E_order(l_set)[i],
                                [p_ini |-> e_set[E_order(l_set)[i]].p_ini,
                                v |-> Value(e_set[E_order(l_set)[i]]),
                                lt|-> Lt(e_set[E_order(l_set)[i]].v_acq)],
                                t_set[E_order(l_set)[i]]>>];
                printed := 1;
            end if;
        end either;
    end while;
end process;

end algorithm;*)
\* BEGIN TRANSLATION (chksum(pcal) = "480345d0" /\ chksum(tla) = "a1ac8c8d")
VARIABLES ops, opcount, elmtcount, history, printed

(* define statement *)
Dft_eset_content == [p_ini |-> -1, v_inn |-> 0, v_acq |-> [v |-> 0, t |-> -1, id |-> -1]]

Inverse_leid(l_set, leid) == CHOOSE x \in Elmts : l_set[x] = leid
E_count(l_set) == Cardinality({x \in Elmts : l_set[x] /= -1})
Leid_order(l_set) == SortSeq([i \in 1..E_count(l_set) |-> l_set[i]], <)
E_order(l_set) == [i \in DOMAIN Leid_order(l_set)
                            |-> Inverse_leid(l_set, Leid_order(l_set)[i])]
Value(c) == IF c.v_acq = [v |-> 0, t |-> -1, id |-> -1] THEN c.v_inn ELSE c.v_acq.v
Lt(acq) == IF acq = [v |-> 0, t |-> -1, id |-> -1] THEN "null" ELSE <<acq.t, acq.id - 1>>

Leid(l_set, e) == IF e = 0 THEN 0 ELSE l_set[e]
Leid_Gen(p, level, self) == p + self * ((N + 1) ^ level)
Leid_New(l_set, level, self, prev, e) == IF l_set[e] /= -1 THEN l_set[e]
                                         ELSE Leid_Gen(Leid(l_set, prev), level, self)

Min(a, b) == IF a <= b THEN a ELSE b
Max(a, b) == IF a <= b THEN b ELSE a
Max_RH(a, b) == [j \in Procs |-> Max(a[j], b[j])]


_Lookup(e_set, e) == e_set[e] /= Dft_eset_content


_Add(e_set, t_set, l_set, level, self, prev, e, x) ==
    IF ~_Lookup(e_set, e) /\ (prev = 0 \/ (_Lookup(e_set, prev) /\ l_set[prev] /= -1))
    THEN
        [key |-> e, val |-> x, p_ini |-> self, rh |-> t_set[e],
         pos |-> Leid_New(l_set, level, self, prev, e), level |-> level - 1]
    ELSE [key |-> -1]

_Update(e_set, t_set, e, i, t, self) ==
    IF _Lookup(e_set, e) THEN [key |-> e, val |-> i, rh |-> t_set[e], lt |-> <<t+1, self>>]
    ELSE [key |-> -1]

_Remove(e_set, t_set, self, e) ==
    IF _Lookup(e_set, e) THEN
        [key |-> e, rh |-> [j \in Procs |-> IF j = self THEN t_set[e][j] + 1
                                                       ELSE t_set[e][j]]]
    ELSE [key |-> -1]

VARIABLES e_set, t_set, l_set, level, lt_set

vars == << ops, opcount, elmtcount, history, printed, e_set, t_set, l_set, 
           level, lt_set >>

ProcSet == (Procs)

Init == (* Global variables *)
        /\ ops = [j \in Procs |-> {}]
        /\ opcount = 0
        /\ elmtcount = 0
        /\ history = <<>>
        /\ printed = 0
        (* Process Set *)
        /\ e_set = [self \in Procs |-> [j \in Elmts |-> Dft_eset_content]]
        /\ t_set = [self \in Procs |-> [j \in Elmts |-> [k \in Procs |-> 0]]]
        /\ l_set = [self \in Procs |-> [j \in Elmts |-> -1]]
        /\ level = [self \in Procs |-> MaxElmts]
        /\ lt_set = [self \in Procs |-> [j \in Elmts |-> 0]]

Set(self) == \/ /\ IF opcount < MaxOps
                      THEN /\ opcount' = opcount + 1
                           /\ \/ /\ \/ /\ IF elmtcount < MaxElmts
                                             THEN /\ LET e == elmtcount + 1 IN
                                                       \E v \in Values:
                                                         \E prev \in {0} \union Elmts:
                                                           LET addp == _Add(e_set[self], t_set[self], l_set[self], level[self], self, prev, e, v) IN
                                                             /\ history' = Append(history, <<opcount', self, "Add", prev, e, v>>)
                                                             /\ IF addp.key /= -1
                                                                   THEN /\ ops' = [j \in Procs |-> IF j = self THEN ops[j]
                                                                                                   ELSE ops[j] \union {[op |-> "A", num |-> opcount', p |-> addp]}]
                                                                        /\ IF \E j \in Procs: t_set[self][e][j] < (addp.rh)[j]
                                                                              THEN /\ t_set' = [t_set EXCEPT ![self][e] = Max_RH((addp.rh), t_set[self][e])]
                                                                                   /\ IF (addp.rh) = t_set'[self][e]
                                                                                         THEN /\ e_set' = [e_set EXCEPT ![self][e] = [p_ini |-> self, v_inn |-> v, v_acq |-> [v |-> 0, t |-> -1, id |-> -1]]]
                                                                                         ELSE /\ e_set' = [e_set EXCEPT ![self][e] = Dft_eset_content]
                                                                              ELSE /\ IF (addp.rh) = t_set[self][e] /\ self > e_set[self][e].p_ini
                                                                                         THEN /\ e_set' = [e_set EXCEPT ![self][e] = [p_ini |-> self, v_inn |-> v, v_acq |-> e_set[self][e].v_acq]]
                                                                                         ELSE /\ TRUE
                                                                                              /\ e_set' = e_set
                                                                                   /\ t_set' = t_set
                                                                        /\ level' = [level EXCEPT ![self] = Min(level[self], (addp.level))]
                                                                        /\ l_set' = [l_set EXCEPT ![self][e] = addp.pos]
                                                                        /\ elmtcount' = elmtcount + 1
                                                                   ELSE /\ TRUE
                                                                        /\ UNCHANGED << ops, 
                                                                                        elmtcount, 
                                                                                        e_set, 
                                                                                        t_set, 
                                                                                        l_set, 
                                                                                        level >>
                                             ELSE /\ TRUE
                                                  /\ UNCHANGED << ops, 
                                                                  elmtcount, 
                                                                  history, 
                                                                  e_set, 
                                                                  t_set, 
                                                                  l_set, 
                                                                  level >>
                                    \/ /\ \E e \in {x \in Elmts : l_set[self][x] /= -1}:
                                            \E v \in Values:
                                              \E prev \in {0} \union Elmts:
                                                LET addp == _Add(e_set[self], t_set[self], l_set[self], level[self], self, prev, e, v) IN
                                                  /\ history' = Append(history, <<opcount', self, "Add", prev, e, v>>)
                                                  /\ IF addp.key /= -1
                                                        THEN /\ ops' = [j \in Procs |-> IF j = self THEN ops[j]
                                                                                        ELSE ops[j] \union {[op |-> "A", num |-> opcount', p |-> addp]}]
                                                             /\ IF \E j \in Procs: t_set[self][e][j] < (addp.rh)[j]
                                                                   THEN /\ t_set' = [t_set EXCEPT ![self][e] = Max_RH((addp.rh), t_set[self][e])]
                                                                        /\ IF (addp.rh) = t_set'[self][e]
                                                                              THEN /\ e_set' = [e_set EXCEPT ![self][e] = [p_ini |-> self, v_inn |-> v, v_acq |-> [v |-> 0, t |-> -1, id |-> -1]]]
                                                                              ELSE /\ e_set' = [e_set EXCEPT ![self][e] = Dft_eset_content]
                                                                   ELSE /\ IF (addp.rh) = t_set[self][e] /\ self > e_set[self][e].p_ini
                                                                              THEN /\ e_set' = [e_set EXCEPT ![self][e] = [p_ini |-> self, v_inn |-> v, v_acq |-> e_set[self][e].v_acq]]
                                                                              ELSE /\ TRUE
                                                                                   /\ e_set' = e_set
                                                                        /\ t_set' = t_set
                                                             /\ level' = [level EXCEPT ![self] = Min(level[self], (addp.level))]
                                                             /\ l_set' = [l_set EXCEPT ![self][e] = addp.pos]
                                                        ELSE /\ TRUE
                                                             /\ UNCHANGED << ops, 
                                                                             e_set, 
                                                                             t_set, 
                                                                             l_set, 
                                                                             level >>
                                       /\ UNCHANGED elmtcount
                                 /\ UNCHANGED lt_set
                              \/ /\ \E e \in Elmts:
                                      LET rmvp == _Remove(e_set[self], t_set[self], self, e) IN
                                        /\ history' = Append(history, <<opcount', self, "Rmv", e>>)
                                        /\ IF rmvp.key /= -1
                                              THEN /\ ops' = [j \in Procs |-> IF j = self THEN ops[j]
                                                                              ELSE ops[j] \union {[op |-> "R", num |-> opcount', p |-> rmvp]}]
                                                   /\ IF \E j \in Procs: t_set[self][e][j] < (rmvp.rh)[j]
                                                         THEN /\ t_set' = [t_set EXCEPT ![self][e] = Max_RH((rmvp.rh), t_set[self][e])]
                                                              /\ e_set' = [e_set EXCEPT ![self][e] = Dft_eset_content]
                                                         ELSE /\ TRUE
                                                              /\ UNCHANGED << e_set, 
                                                                              t_set >>
                                              ELSE /\ TRUE
                                                   /\ UNCHANGED << ops, 
                                                                   e_set, 
                                                                   t_set >>
                                 /\ UNCHANGED <<elmtcount, l_set, level, lt_set>>
                              \/ /\ \E e \in Elmts:
                                      \E i \in Values:
                                        LET updp == _Update(e_set[self], t_set[self], e, i, lt_set[self][e], self) IN
                                          /\ history' = Append(history, <<opcount', self, "Upd", e, i>>)
                                          /\ IF updp.key /= -1
                                                THEN /\ ops' = [j \in Procs |-> IF j = self THEN ops[j]
                                                                                ELSE ops[j] \union {[op |-> "U", num |-> opcount', p |-> updp]}]
                                                     /\ IF \E j \in Procs: t_set[self][e][j] < (updp.rh)[j]
                                                           THEN /\ t_set' = [t_set EXCEPT ![self][e] = Max_RH((updp.rh), t_set[self][e])]
                                                                /\ IF (updp.rh) = t_set'[self][e]
                                                                      THEN /\ e_set' = [e_set EXCEPT ![self][e] = [p_ini |-> -1, v_inn |-> 0, v_acq |-> [v |-> i, t |-> (updp.lt)[1], id |-> (updp.lt)[2]]]]
                                                                      ELSE /\ e_set' = [e_set EXCEPT ![self][e] = Dft_eset_content]
                                                           ELSE /\ LET old_acq == e_set[self][e].v_acq IN
                                                                     IF (updp.rh) = t_set[self][e] /\ (old_acq.t < (updp.lt)[1] \/ (old_acq.t = (updp.lt)[1] /\ old_acq.id < (updp.lt)[2]))
                                                                        THEN /\ e_set' = [e_set EXCEPT ![self][e] = [p_ini |-> e_set[self][e].p_ini, v_inn |-> e_set[self][e].v_inn, v_acq |-> [v |-> i, t |-> (updp.lt)[1], id |-> (updp.lt)[2]]]]
                                                                        ELSE /\ TRUE
                                                                             /\ e_set' = e_set
                                                                /\ t_set' = t_set
                                                     /\ lt_set' = [lt_set EXCEPT ![self][e] = Max(lt_set[self][e], (updp.lt)[1])]
                                                ELSE /\ TRUE
                                                     /\ UNCHANGED << ops, 
                                                                     e_set, 
                                                                     t_set, 
                                                                     lt_set >>
                                 /\ UNCHANGED <<elmtcount, l_set, level>>
                      ELSE /\ TRUE
                           /\ UNCHANGED << ops, opcount, elmtcount, history, 
                                           e_set, t_set, l_set, level, 
                                           lt_set >>
                /\ UNCHANGED printed
             \/ /\ IF ops[self] /= {}
                      THEN /\ \E msg \in ops[self]:
                                /\ IF msg.op = "A"
                                      THEN /\ IF \E j \in Procs: t_set[self][(msg.p.key)][j] < (msg.p.rh)[j]
                                                 THEN /\ t_set' = [t_set EXCEPT ![self][(msg.p.key)] = Max_RH((msg.p.rh), t_set[self][(msg.p.key)])]
                                                      /\ IF (msg.p.rh) = t_set'[self][(msg.p.key)]
                                                            THEN /\ e_set' = [e_set EXCEPT ![self][(msg.p.key)] = [p_ini |-> (msg.p.p_ini), v_inn |-> (msg.p.val), v_acq |-> [v |-> 0, t |-> -1, id |-> -1]]]
                                                            ELSE /\ e_set' = [e_set EXCEPT ![self][(msg.p.key)] = Dft_eset_content]
                                                 ELSE /\ IF (msg.p.rh) = t_set[self][(msg.p.key)] /\ (msg.p.p_ini) > e_set[self][(msg.p.key)].p_ini
                                                            THEN /\ e_set' = [e_set EXCEPT ![self][(msg.p.key)] = [p_ini |-> (msg.p.p_ini), v_inn |-> (msg.p.val), v_acq |-> e_set[self][(msg.p.key)].v_acq]]
                                                            ELSE /\ TRUE
                                                                 /\ e_set' = e_set
                                                      /\ t_set' = t_set
                                           /\ level' = [level EXCEPT ![self] = Min(level[self], (msg.p.level))]
                                           /\ l_set' = [l_set EXCEPT ![self][(msg.p.key)] = msg.p.pos]
                                           /\ UNCHANGED lt_set
                                      ELSE /\ IF msg.op = "R"
                                                 THEN /\ IF \E j \in Procs: t_set[self][(msg.p.key)][j] < (msg.p.rh)[j]
                                                            THEN /\ t_set' = [t_set EXCEPT ![self][(msg.p.key)] = Max_RH((msg.p.rh), t_set[self][(msg.p.key)])]
                                                                 /\ e_set' = [e_set EXCEPT ![self][(msg.p.key)] = Dft_eset_content]
                                                            ELSE /\ TRUE
                                                                 /\ UNCHANGED << e_set, 
                                                                                 t_set >>
                                                      /\ UNCHANGED lt_set
                                                 ELSE /\ IF msg.op = "U"
                                                            THEN /\ IF \E j \in Procs: t_set[self][(msg.p.key)][j] < (msg.p.rh)[j]
                                                                       THEN /\ t_set' = [t_set EXCEPT ![self][(msg.p.key)] = Max_RH((msg.p.rh), t_set[self][(msg.p.key)])]
                                                                            /\ IF (msg.p.rh) = t_set'[self][(msg.p.key)]
                                                                                  THEN /\ e_set' = [e_set EXCEPT ![self][(msg.p.key)] = [p_ini |-> -1, v_inn |-> 0, v_acq |-> [v |-> (msg.p.val), t |-> (msg.p.lt)[1], id |-> (msg.p.lt)[2]]]]
                                                                                  ELSE /\ e_set' = [e_set EXCEPT ![self][(msg.p.key)] = Dft_eset_content]
                                                                       ELSE /\ LET old_acq == e_set[self][(msg.p.key)].v_acq IN
                                                                                 IF (msg.p.rh) = t_set[self][(msg.p.key)] /\ (old_acq.t < (msg.p.lt)[1] \/ (old_acq.t = (msg.p.lt)[1] /\ old_acq.id < (msg.p.lt)[2]))
                                                                                    THEN /\ e_set' = [e_set EXCEPT ![self][(msg.p.key)] = [p_ini |-> e_set[self][(msg.p.key)].p_ini, v_inn |-> e_set[self][(msg.p.key)].v_inn, v_acq |-> [v |-> (msg.p.val), t |-> (msg.p.lt)[1], id |-> (msg.p.lt)[2]]]]
                                                                                    ELSE /\ TRUE
                                                                                         /\ e_set' = e_set
                                                                            /\ t_set' = t_set
                                                                 /\ lt_set' = [lt_set EXCEPT ![self][(msg.p.key)] = Max(lt_set[self][(msg.p.key)], (msg.p.lt)[1])]
                                                            ELSE /\ TRUE
                                                                 /\ UNCHANGED << e_set, 
                                                                                 t_set, 
                                                                                 lt_set >>
                                           /\ UNCHANGED << l_set, level >>
                                /\ history' = Append(history, <<msg.num, self, "effect">>)
                                /\ ops' = [ops EXCEPT ![self] = ops[self] \ {msg}]
                      ELSE /\ TRUE
                           /\ UNCHANGED << ops, history, e_set, t_set, 
                                           l_set, level, lt_set >>
                /\ IF self = 1 /\ printed = 0 /\ opcount = MaxOps /\ ops' = [j \in Procs |-> {}]
                      THEN /\ Assert(E_count(l_set'[self]) = elmtcount, 
                                     "Failure of assertion at line 204, column 17.")
                           /\ PrintT(history')
                           /\ PrintT([i \in DOMAIN E_order(l_set'[self]) |->
                                               <<E_order(l_set'[self])[i],
                                               [p_ini |-> e_set'[self][E_order(l_set'[self])[i]].p_ini,
                                               v |-> Value(e_set'[self][E_order(l_set'[self])[i]]),
                                               lt|-> Lt(e_set'[self][E_order(l_set'[self])[i]].v_acq)],
                                               t_set'[self][E_order(l_set'[self])[i]]>>])
                           /\ printed' = 1
                      ELSE /\ TRUE
                           /\ UNCHANGED printed
                /\ UNCHANGED <<opcount, elmtcount>>

Next == (\E self \in Procs: Set(self))

Spec == Init /\ [][Next]_vars

\* END TRANSLATION 

\* ops[p1] = ops[p2] => op_exed[p1] = op_exed[p2]
SEC == \A p1, p2 \in Procs: (p1 /= p2 /\ ops[p1] = ops[p2]) => (e_set[p1] = e_set[p2] 
                                                               /\ t_set[p1] = t_set[p2] 
                                                               /\ level[p1] = level[p2]
                                                               /\ l_set[p1] = l_set[p2]
                                                               /\ lt_set[p1] = lt_set[p2])

Leid_TO == \A p \in Procs: \A i, j \in Elmts: (i /= j) => (l_set[p][i] = -1 
                                                          \/ l_set[p][j] = -1 
                                                          \/ l_set[p][i] /= l_set[p][j])


================================================================================
