Require Import Equations Omega.

Inductive term := 
| Var (n : nat)
| Lambda (t : term)
| App (t u : term)
| Pair (t u : term)
| Fst (t : term) | Snd (t : term)
| Tt.


Coercion Var : nat >-> term.

Delimit Scope term_scope with term.
Bind Scope term_scope with term.

Notation " @( f , x ) " := (App (f%term) (x%term)).
Notation " 'λ' t " := (Lambda (t%term)) (at level 0). 
Notation " << t , u >> " := (Pair (t%term) (u%term)).

Parameter atomic_type : Set.
Inductive type :=
| atom (a : atomic_type)
| product (a b : type)
| unit
| arrow (a b : type).

Derive Subterm for type.
(* Equations foo(t : type) (u : nat) (foo : t = t) : { u : type | t = t } := *)
(* foo t u foo with t := { *)
(*   | atom a := exist _ (atom a) _ ; *)
(*   | _ := exist _ unit _ }. *)

Coercion atom : atomic_type >-> type.
Notation " x × y " := (product x y) (at level 90).
Notation " x ---> y " := (arrow x y) (at level 30).

Require Import Arith.

Equations(nocomp) lift (k n : nat) (t : term) : term :=
lift k n (Var i) with nat_compare i k := {
  | Lt := Var i ;
  | _ := Var (i + n) } ;
lift k n (Lambda t) := Lambda (lift (S k) n t) ;
lift k n (App t u) := @(lift k n t, lift k n u) ;
lift k n (Pair t u) := << lift k n t, lift k n u >> ;
lift k n (Fst t) := Fst (lift k n t) ;
lift k n (Snd t) := Snd (lift k n t) ;
lift k n Tt := Tt.

Tactic Notation "absurd"  tactic(tac) := elimtype False; tac.

Ltac term_eq := 
  match goal with
    | |- Var _ = Var _ => f_equal ; omega
    | |- @eq nat _ _ => omega || absurd omega
    | |- lt _ _ => omega || absurd omega
    | |- le _ _ => omega || absurd omega
    | |- gt _ _ => omega || absurd omega
    | |- ge _ _ => omega || absurd omega
  end.

Hint Extern 4 => term_eq : term.

Ltac term := eauto with term.

Lemma lift0 k t : lift k 0 t = t.
Proof. funelim (lift k 0 t) ; try rewrite H ; try rewrite H0; auto. Qed.
Hint Rewrite lift0 : lift.
Require Import Omega.
Lemma lift_k_lift_k k n m t : lift k n (lift k m t) = lift k (n + m) t.
Proof. funelim (lift k m t) ; simp lift; try rewrite H ; try rewrite H0; auto.
  destruct (nat_compare_spec n0 k); try discriminate. subst.
  case_eq (nat_compare (k + n) k); intro H; simp lift; term. 
  rewrite <- nat_compare_lt in H; term.
  rewrite Heq; simp lift; term.

  rewrite Heq. rewrite <- nat_compare_gt in Heq. simp lift.
  destruct (nat_compare_spec (n0 + n) k); try discriminate; simp lift; term. 
Qed.
Hint Rewrite lift_k_lift_k : lift.

Equations(nocomp) subst (k : nat) (t : term) (u : term) : term :=
subst k (Var i) u with nat_compare i k := {
  | Eq := lift 0 k u ;
  | Lt := i ;
  | Gt := Var (pred i) } ;
subst k (Lambda t) u := Lambda (subst (S k) t u) ;
subst k (App a b) u := @(subst k a u, subst k b u) ;
subst k (Pair a b) u := << subst k a u, subst k b u >> ;
subst k (Fst t) u := Fst (subst k t u) ;
subst k (Snd t) u := Snd (subst k t u) ;
subst k Tt _ := Tt.

Lemma substnn n t : subst n n t = lift 0 n t.
Proof. funelim (subst n n t) ; try rewrite H ; try rewrite H0; simp lift; auto. 
  rewrite <- nat_compare_lt in Heq; absurd omega.
  rewrite <- nat_compare_gt in Heq; absurd omega.
Qed.
Hint Rewrite substnn : subst.
Notation ctx := (list type).

Delimit Scope lf with lf.

Reserved Notation " Γ |-- t : A " (at level 70, t, A at next level).
Require Import List.

Inductive types : ctx -> term -> type -> Prop :=
| axiom Γ i : i < length Γ -> (Γ |-- i : nth i Γ unit) 

| abstraction Γ A B t :
  A :: Γ |-- t : B -> Γ |-- λ t : A ---> B

| application Γ A B t u : 
  Γ |-- t : A ---> B -> Γ |-- u : A -> Γ |-- @(t, u) : B

| unit_intro Γ : Γ |-- Tt : unit

| pair_intro Γ A B t u :
  Γ |-- t : A -> Γ |-- u : B -> 
    Γ |-- << t , u >> : (A × B)

| pair_elim_fst Γ A B t : Γ |-- t : (A × B) -> Γ |-- Fst t : A

| pair_elim_snd Γ A B t : Γ |-- t : (A × B) -> Γ |-- Snd t : B

where "Γ |-- i : A " := (types Γ i A).

Notation " [ t ] u " := (subst 0 u t) (at level 10).

Notation " x @ y " := (app x y) (at level 30, right associativity).

Lemma nth_length {A} x t (l l' : list A) : nth (length l) (l @ (t :: l')) x = t.
Proof. induction l; simpl; auto. Qed.

Hint Constructors types : term.

Lemma nat_compare_elim (P : nat -> nat -> comparison -> Prop)
  (PEq : forall i, P i i Eq)
  (PLt : forall i j, i < j -> P i j Lt)
  (PGt : forall i j, i > j -> P i j Gt) :
  forall i j, P i j (nat_compare i j).
Proof. intros. case (nat_compare_spec i j); intros; subst; auto. Qed.

Lemma nth_extend_left {A} (a : A) n (l l' : list A) : nth n l a = nth (length l' + n) (l' @ l) a.
Proof. induction l'; auto. Qed.

Lemma nth_extend_middle {A} (a : A) n (l l' l'' : list A) : 
  match nat_compare n (length l') with
    | Lt => nth n (l' @ l) a = nth n (l' @ l'' @ l) a
    | _ => nth n (l' @ l) a = nth (n + length l'') (l' @ l'' @ l) a
  end.
Proof. 
  assert (foo:=nat_compare_spec n (length l')).
  depelim foo; try rewrite <- H; try rewrite <- H0; subst. rewrite <- nth_extend_left. 
  replace (length l'') with (length l'' + 0) by auto with arith. rewrite <- nth_extend_left. 
  replace (length l') with (length l' + 0) by auto with arith. now rewrite <- nth_extend_left.

  clear H0. revert l' H l''; induction n; intros; simpl; auto. destruct l'; now try solve [ inversion H ].
  destruct l'; try solve [ inversion H ]. simpl. rewrite <- (IHn l'); auto. simpl in H. omega.

  clear H0. revert l' H l''; induction n; intros; simpl; auto. inversion H.
  destruct l'; simpl. 
  replace (S (n + length l'')) with (length l'' + S n) by omega. now rewrite <- nth_extend_left.
  rewrite <- IHn; auto. simpl in H; omega.
Qed. 
  
Print Rewrite HintDb list.
Hint Rewrite <- app_assoc in_app_iff in_inv : list.


Lemma type_lift Γ t T Γ' : Γ' @ Γ |-- t : T -> forall Γ'', Γ' @ Γ'' @ Γ |-- lift (length Γ') (length Γ'') t : T.
Proof. intros H. depind H; intros; simp lift; eauto with term.

  generalize (nth_extend_middle unit i Γ0 Γ' Γ'').
  destruct nat_compare; intros H'; rewrite H'; simp lift; apply axiom; autorewrite with list in H |- *; omega.
  
  apply abstraction. change (S (length Γ')) with (length (A :: Γ')). 
  rewrite app_comm_cons. apply IHtypes. reflexivity.
Qed.

Lemma type_lift1 Γ t T A : Γ |-- t : T -> A :: Γ |-- lift 0 1 t : T.
Proof. intros. apply (type_lift Γ t T [] H [A]). Qed.

Lemma type_liftn Γ Γ' t T : Γ |-- t : T -> Γ' @ Γ |-- lift 0 (length Γ') t : T.
Proof. intros. apply (type_lift Γ t T [] H Γ'). Qed.
Hint Resolve type_lift1 type_lift type_liftn : term.

Lemma app_cons_snoc_app {A} l (a : A) l' : l ++ (a :: l') = (l ++ a :: nil) ++ l'.
Proof. induction l; simpl; auto. now rewrite IHl. Qed.

Hint Extern 5 => progress (simpl ; autorewrite with list) : term.
Ltac term ::= simp lift subst; eauto with term.


Lemma substitutive Γ t T Γ' u U : (Γ' @ (U :: Γ)) |-- t : T -> Γ |-- u : U -> Γ' @ Γ |-- subst (length Γ') t u : T.
Proof with term.
  intros H. depind H; term. intros.
  
  (* Var *)
  assert (spec:=nat_compare_spec i (length Γ')). depelim spec; try rewrite <- H1; try rewrite <- H2 ; simp subst.

  (* Eq *)
  generalize (type_lift Γ0 u U [] H0 Γ'); simpl; intros. 
  rewrite app_cons_snoc_app, app_nth1, app_nth2; try (simpl; omega).
  now rewrite <- minus_n_n. autorewrite with list; simpl. omega.

  (* Lt *)
  rewrite app_nth1; try omega. rewrite <- (app_nth1 _ Γ0); term. 

  (* Gt *)
  rewrite app_nth2; term. 
  change (U :: Γ0) with ((cons U nil) @ Γ0). rewrite app_nth2; term.
  simpl. rewrite (nth_extend_left unit _ Γ0 Γ').
  replace (length Γ' + (i - length Γ' - 1)) with (pred i); term.
  apply axiom. autorewrite with list in H |- *. simpl in H. omega.

  (* Abstraction *)
  intros. apply abstraction. now apply (IHtypes Γ0 (A :: Γ') U).
Qed.

Lemma subst1 Γ t T u U : U :: Γ |-- t : T -> Γ |-- u : U -> Γ |-- subst 0 t u : T.
Proof. intros; now apply (substitutive Γ t T [] u U). Qed.
  
Reserved Notation " t --> u " (at level 55, right associativity).

Inductive reduce : term -> term -> Prop :=
| red_beta t u : @((Lambda t) , u) --> subst 0 t u
| red_fst t u : Fst << t , u >> --> t
| red_snd t u : Snd << t , u >> --> u

where " t --> u " := (reduce t u). 

Require Import Relations.

Definition reduces := clos_refl_trans term reduce.
Notation " t -->* u " := (reduces t u) (at level 55).

Require Import Setoid.

Instance: Transitive reduces.
Proof. red; intros. econstructor 3; eauto. Qed.

Instance: Reflexive reduces.
Proof. red; intros. econstructor 2; eauto. Qed.

Inductive value : term -> Prop :=
| val_var (i : nat) : value i
| val_unit : value Tt
| val_pair a b : value a -> value b -> value << a, b >>
| val_lambda t : value λ t.

Hint Constructors value : term.

Inductive eval_context : Set :=
| eval_hole
| eval_app_left : term -> eval_context -> eval_context
| eval_app_right (c : eval_context) (u : term) : value u -> eval_context
| eval_fst (t : eval_context) : eval_context
| eval_snd (t : eval_context) : eval_context.

Equations apply_context (e : eval_context) (t : term) : term :=
apply_context eval_hole t := t ;
apply_context (eval_app_left t c) u := @(t, apply_context c u) ;
apply_context (eval_app_right c t _) u := @(apply_context c t, u) ;
apply_context (eval_fst c) t := Fst (apply_context c t) ;
apply_context (eval_snd c) t := Snd (apply_context c t).

Inductive reduce_congr : relation term :=
| reduce1 t u : reduce t u -> reduce_congr t u
| reduce_app t t' u u' : reduce_congr t t' -> reduce_congr u u' ->
  reduce_congr (@(t, u)) (@(t', u'))
| reduce_pair t t' u u' : reduce_congr t t' -> reduce_congr u u' ->
  reduce_congr (<< t, u >>) (<< t', u' >>)
| reduce_fst t t' : reduce_congr t t' -> reduce_congr (Fst t) (Fst t')
| reduce_snd t t' : reduce_congr t t' -> reduce_congr (Snd t) (Snd t')
.

(*
Obligation Tactic := auto with term.

Equations find_redex (t : term) : (eval_context * term) + { value t } :=
find_redex (Var i) := inright _ ;
find_redex (App t u) with find_redex u := {
  | inright vu with find_redex t := {
    | inright (val_lambda t') := inleft (eval_hole, @(Lambda t', u)) ;
    | inright vt := inright _ ;
    | inleft (pair c t') := inleft (eval_app_right c u vu, t') } ;
  | inleft (pair c u') := inleft (eval_app_left t c, u') } ;
find_redex (Lambda t) := inright _ ;
find_redex (Pair t u) := inright _ ;
find_redex (Fst t) with find_redex t := {
  | inleft (pair c t') := inleft (eval_fst c, t') ;
  | inright vt := inleft (eval_hole, Fst t) } ;
find_redex (Snd t) with find_redex t := {
  | inleft (pair c t') := inleft (eval_snd c, t') ;
  | inright vt := inleft (eval_hole, Snd t) } ;
find_redex Tt := inright _.

*)

Derive NoConfusion for term type.

(* Remark *)
Instance: Irreflexive reduce.
Proof. intros x H. depind H.
  induction t; simp subst in H; try discriminate.
  destruct (nat_compare_spec n 0). subst.
  simp subst lift in H.  admit.
  absurd omega. simp subst in H. destruct n; discriminate.
  noconf H. admit.
  admit. admit.
Qed.

Lemma preserves_red1 Γ t τ : Γ |-- t : τ → forall u, t --> u → Γ |-- u : τ.
Proof. induction 1; intros; term. inversion H0. inversion H0. inversion H1. subst.
  apply subst1 with A. now inversion H. apply H0.

  inversion H.
  inversion H1.

  inversion H0. subst.  inversion H. subst. assumption.
  inversion H0. subst.  inversion H. subst. assumption.
Qed.

Lemma preserves_redpar Γ t τ : Γ |-- t : τ → forall u, reduce_congr t u → Γ |-- u : τ.
Proof. induction 1; intros; term. depelim H0. depelim H0. 

  depelim H0. depelim H0.

  depelim H1. depelim H1. depelim H. eapply subst1; eauto.

  econstructor; eauto.

  depelim H. depelim H.

  depelim H1. depelim H1.
  eauto with term.

  depelim H0. depelim H0. now depelim H.
  eauto with term.

  depelim H0. depelim H0. now depelim H.
  eauto with term.
Qed.

Lemma subject_reduction Γ t τ : Γ |-- t : τ → forall u, t -->* u → Γ |-- u : τ.
Proof. induction 2; eauto using preserves_red1. Qed.

(* Lemma inv_abs A B t : nil |-- t : A ---> B -> ∃ u, (t = λ u /\ (A :: nil) |-- u : B). *)
(* Proof. intros H; depind H. inversion H. exists t; auto. *)

(*   destruct IHtypes1 as [t' [tt' Htt']]. *)
(*   subst t.  *)
  
(*   induction  *)

(* Lemma red_progress Γ t τ : Γ |-- t : τ → *)
(*   (exists u, reduce t u) \/ value t. *)
(* Proof. *)
(*   induction 1. right; term. *)
(*   right; term. *)
  
(*   destruct IHtypes1 as [[t' tt']|vt]. *)
(*   left; exists (@(t', u)).   *)
  


(* Lemma red_progress  t τ : nil |-- t : τ → *)
(*   exists u, t -->* u ∧ value u. *)
(* Proof. intros H. depind H; term. *)

(*   inversion H. *)

(*   exists λ t; term. split; now term. *)
(*   destruct IHtypes1 as [t' [tt' vt']]. *)
(*   destruct IHtypes2 as [u' [uu' vu']]. *)
(*   pose (subject_reduction _ _ _ H _ tt'). *)
(*   depelim vt'. depelim t0. depelim t0. *)
(*   depelim t1.  *)

(*   exists (@(t', u')). *)

(*   depelim H. *)
(*   inversion H. *)

Reserved Notation " Γ |-- t => A " (at level 70, t, A at next level).
Reserved Notation " Γ |-- t <= A " (at level 70, t, A at next level).

Inductive atomic : type -> Prop :=
| atomic_atom a : atomic (atom a).
Hint Constructors atomic : term.

Equations(nocomp) atomic_dec (t : type) : { atomic t } + { ~ atomic t } :=
atomic_dec (atom a) := left (atomic_atom a) ;
atomic_dec _ := right _.

  Solve Obligations using intros; intro H; inversion H. 
  Solve All Obligations.

Inductive check : ctx -> term -> type -> Prop :=
| abstraction_check Γ A B t :
  A :: Γ |-- t <= B -> 
  Γ |-- λ t <= A ---> B

| pair_intro_check Γ A B t u :
  Γ |-- t <= A -> Γ |-- u <= B -> 
    Γ |-- << t , u >> <= (A × B)

| unit_intro_check Γ : Γ |-- Tt <= unit

| check_synth Γ t T : atomic T -> Γ |-- t => T -> Γ |-- t <= T

with synthetize : ctx -> term -> type -> Prop :=

| axiom_synth Γ i : i < length Γ -> 
  Γ |-- i => nth i Γ unit
 
| application_synth {Γ A B t u} : 
  Γ |-- t => A ---> B -> Γ |-- u <= A -> Γ |-- @(t, u) => B

| pair_elim_fst_synth {Γ A B t} : Γ |-- t => (A × B) -> Γ |-- Fst t => A

| pair_elim_snd_synth {Γ A B t} : Γ |-- t => (A × B) -> Γ |-- Snd t => B

where "Γ |-- i => A " := (synthetize Γ i A)
and  "Γ |-- i <= A " := (check Γ i A).

Hint Constructors synthetize check : term.

Scheme check_mut_ind := Elimination for check Sort Prop
  with synthetize_mut_ind := Elimination for synthetize Sort Prop.

Combined Scheme check_synthetize from check_mut_ind, synthetize_mut_ind.

Lemma synth_arrow {Γ t T} : forall A : Prop, Γ |-- λ (t) => T -> A.
Proof. intros A H. depelim H. Qed.

Lemma synth_pair {Γ t u T} : forall A : Prop, Γ |-- << t, u >> => T -> A.
Proof. intros A H. depelim H. Qed.

Lemma synth_unit {Γ T} : forall A : Prop, Γ |-- Tt => T -> A.
Proof. intros A H. depelim H. Qed.

Hint Extern 3 => 
  match goal with
    | H : ?Γ |-- ?t => ?T |- _ => apply (synth_arrow _ H) || apply (synth_pair _ H) || apply (synth_unit _ H)
  end : term.

Lemma check_types : (forall Γ t T, Γ |-- t <= T -> Γ |-- t : T)
with synthetizes_types : (forall Γ t T, Γ |-- t => T -> Γ |-- t : T).
Proof. intros. destruct H. apply abstraction. auto.
  apply pair_intro. auto. auto.
  apply unit_intro.
  apply synthetizes_types. apply H0.

  intros. destruct H. now apply axiom.
  apply application with A; auto.
  apply pair_elim_fst with B; auto.
  apply pair_elim_snd with A; auto.
Qed.

Hint Resolve check_types synthetizes_types : term.

Inductive normal : term -> Prop :=
| normal_unit : normal Tt
| normal_pair a b : normal a -> normal b -> normal << a, b >>
| normal_abs t : normal t -> normal λ t
| normal_neutral r : neutral r -> normal r

with neutral : term -> Prop :=
| neutral_var i : neutral (Var i)
| neutral_fst t : neutral t -> neutral (Fst t)
| neutral_snd t : neutral t -> neutral (Snd t)
| neutral_app t n : neutral t -> normal n -> neutral (@(t, n)).

Hint Constructors normal neutral : term.

Lemma check_lift Γ t T Γ' : Γ' @ Γ |-- t <= T -> 
  forall Γ'', Γ' @ Γ'' @ Γ |-- lift (length Γ') (length Γ'') t <= T
with synthetize_lift Γ t T Γ' : Γ' @ Γ |-- t => T -> 
  forall Γ'', Γ' @ Γ'' @ Γ |-- lift (length Γ') (length Γ'') t => T.
Proof. intros H. depelim H; intros; simp lift.

  constructor.
  change (S (length Γ')) with (length (A :: Γ')). rewrite app_comm_cons. now apply check_lift. 

  constructor; apply check_lift; assumption.
  constructor. constructor. auto. now apply synthetize_lift.

  intros H. depelim H; intros; simp lift; try (constructor; eauto with term).
  generalize (nth_extend_middle unit i Γ Γ' Γ'').
  destruct nat_compare; intros H'; rewrite H'; simp lift; apply axiom_synth; autorewrite with list in H |- *; omega.

  econstructor. apply synthetize_lift. apply H. apply check_lift. apply H0.
  econstructor. apply synthetize_lift. apply H.
  econstructor. apply synthetize_lift. apply H.
Qed.

Lemma check_lift1 {Γ t T A} : Γ |-- t <= T -> A :: Γ |-- lift 0 1 t <= T.
Proof. intros. apply (check_lift Γ t T [] H [A]). Qed.

Lemma synth_lift1 {Γ t T A} : Γ |-- t => T -> A :: Γ |-- lift 0 1 t => T.
Proof. intros. apply (synthetize_lift Γ t T [] H [A]). Qed.
Hint Resolve @check_lift1 @synth_lift1 : term.

Lemma check_lift_ctx {Γ t T Γ'} : Γ |-- t <= T -> Γ' @ Γ |-- lift 0 (length Γ') t <= T.
Proof. intros. apply (check_lift Γ t T [] H Γ'). Qed.

Lemma synth_lift_ctx {Γ t T Γ'} : Γ |-- t => T -> Γ' @ Γ |-- lift 0 (length Γ') t => T.
Proof. intros. apply (synthetize_lift Γ t T [] H Γ'). Qed.
Hint Resolve @check_lift_ctx @synth_lift_ctx : term.


Equations(nocomp) η (a : type) (t : term) : term :=
η (atom _) t := t ;
η (product a b) t := << η a (Fst t), η b (Snd t) >> ;
η (arrow a b) t := (Lambda (η b @(lift 0 1 t, η a 0)))%term ;
η unit t := Tt.

(* Lemma η_normal : forall Γ A t, neutral t -> Γ |-- t => A -> normal (η A t). *)
(* Proof. induction 2; term. induction i; term. Qed. *)

Lemma checks_arrow Γ t A B : Γ |-- t <= A ---> B → ∃ t', t = λ t' ∧ A :: Γ |-- t' <= B.
Proof. intros H; inversion H; subst.
  exists t0; term.
  inversion H0.
Qed.

Lemma normal_lift {t k n} : normal t → normal (lift k n t) 
  with neutral_lift {t k n} : neutral t -> neutral (lift k n t).
Proof. destruct 1; simp lift; constructor; term. 
  destruct 1; simp lift; try (constructor; term). 
  destruct nat_compare; term. 
Qed.
Hint Resolve @normal_lift @neutral_lift : term.


Lemma check_normal {Γ t T} : Γ |-- t <= T -> normal t
 with synth_neutral {Γ t T} : Γ |-- t => T -> neutral t.
Proof. destruct 1; constructor; term. destruct 1; constructor; term. Qed.
Hint Resolve @check_normal @synth_neutral : term.

Lemma eta_expand Γ t A : neutral t → Γ |-- t => A -> Γ |-- η A t <= A.
Proof. revert Γ t; induction A; intros; simp η; constructor; term.

  assert(0 < length (A1 :: Γ)) by (simpl; omega).
  specialize (IHA1 (A1 :: Γ) 0 (neutral_var _) (axiom_synth (A1 :: Γ) 0 H1)). 
  apply (IHA2 (A1 :: Γ) @(lift 0 1 t, η A1 0)); term.
Qed.

Ltac rec ::= rec_wf_eqns.
Require Import Arith Wf_nat.
Instance wf_nat : WellFounded lt := lt_wf.

Derive Subterm for term.

Ltac solve_rec ::= idtac.

Require Import Lexicographic_Product.

Implicit Arguments lexprod [A B].

Definition lexicographic {A B} (R : relation A) (S : relation B) : relation (A * B) :=
  fun x y => 
    let (x1, x2) := x in 
    let (y1, y2) := y in
      lexprod R (const S) (existS _ x1 x2) (existS _ y1 y2).

Instance lexicographic_wellfounded {A R B S} `{WellFounded A R} `{WellFounded B S} : WellFounded (lexicographic R S).
Proof. red in H, H0. red. unfold lexicographic. 
  assert(wfS:forall x : A, well_founded (const S x)) by auto.
  assert(wfprod:=wf_lexprod A (fun _ => B) R (const S) H wfS).
  red in wfprod.
  intro. specialize (wfprod (existT (const B) (fst a) (snd a))).
  clear wfS H H0. depind wfprod. constructor; intros.
  destruct y; destruct a; simpl in *. apply H0 with (existT (const B) a0 b).
  assumption.
  simpl. reflexivity.
Qed.

Definition her_order : relation (type * term * term) :=
  lexicographic (lexicographic type_subterm term_subterm) term_subterm.

(* Instance: WellFounded her_order. *)
(* Proof. unfold her_order. intro.  *)
(*   induction (lexicographic_wellfounded (A:=type*term) (R:=lexicographic type_subterm term_subterm) (B:=term) a). *)
(*   constructor. intros. *)
(*   apply H0. destruct y. destruct p; auto. destruct x. destruct p. auto. *)
  

Obligation Tactic := program_simpl.
Set Printing All.

Obligation Tactic := idtac.
Implicit Arguments exist [[A] [P]].

Definition hereditary_type (t : type * term * term) :=
  (term * option { u : type | u = (fst (fst t)) \/ type_subterm u (fst (fst t)) })%type.

Inductive IsLambda {t} : hereditary_type t -> Set :=
| isLambda abs a b prf : IsLambda (Lambda abs, Some (exist (arrow a b) prf)).

Equations(nocomp) is_lambda {t} (h : hereditary_type t) : IsLambda h + term :=
is_lambda t (pair (Lambda abs) (Some (exist (arrow a b) prf))) := inl (isLambda abs a b prf) ;
is_lambda t (pair t' _) := inr t'.
Unset Printing All.


Inductive IsPair {t} : hereditary_type t -> Set :=
| isPair u v a b prf : IsPair (Pair u v, Some (exist (product a b) prf)).

Equations(nocomp) is_pair {t} (h : hereditary_type t) : IsPair h + term :=
is_pair t (pair (Pair u v) (Some (exist (product a b) prf))) := inl (isPair u v a b prf) ;
is_pair t (pair t' _) := inr t'.

Unset Printing All.
(*
Equations hereditary_subst (t : type * term * term) (k : nat) :
  term * option { u : type | u = (fst (fst t)) \/ type_subterm u (fst (fst t)) }  :=
hereditary_subst t k by rec t her_order :=

hereditary_subst (pair (pair A a) t) k with t := {
  | App f arg with hereditary_subst (A, a, f) k := {
    | p with is_lambda p := {
      hereditary_subst (pair (pair A a) ?(App f arg)) k (App f arg) (inl (is_beta_lambda f' A' B' prf)) ?(p) :=
        let (f'', y) := hereditary_subst (A', fst (hereditary_subst (A, a, arg) k), f') 0 in
          (f'', Some (exist B' _)) ;
      hereditary_subst (pair (pair A a) ?(App f arg)) k (App f arg) (inr f') ?(p) := 
        (@(f', fst (hereditary_subst (A, a, arg) k)), None) } } ;
  | _ := (Tt, None) } ;

hereditary_subst _ _ := (Tt, None).

Solve Obligations using intros; apply hereditary_subst; constructor 2; constructor.

Next Obligation. intros. apply hereditary_subst.
  destruct prf. simpl in *. subst.  repeat constructor.
  simpl in t. do 2 constructor 1. apply type_direct_subterm_0_0 with (A' ---> B'); auto.
  eauto using type_direct_subterm.
Defined.


Next Obligation. intros. simpl. simpl in prf.
  destruct prf. subst A. right; constructor. right.
  apply type_direct_subterm_0_0 with (A' ---> B'); eauto using type_direct_subterm.
Defined.
    
Next Obligation.
Proof. intros.
  admit.
Defined.
*)

Lemma nth_extend_right {A} (a : A) n (l l' : list A) : n < length l -> 
  nth n l a = nth n (l @ l') a.
Proof. revert n l'. induction l; simpl; intros; auto. depelim H. destruct n; auto.  
  apply IHl. auto with arith.
Qed.
  
Lemma is_lambda_inr {t} (h : hereditary_type t) : forall t', is_lambda h = inr t' -> fst h = t'.
Proof.
  destruct h. funelim (is_lambda (t0, o)); intros; try congruence.
Qed.

About hereditary_subst_elim.

Equations hereditary_subst (t : type * term * term) (k : nat) :
  term * option { u : type | u = (fst (fst t)) \/ type_subterm u (fst (fst t)) }  :=
hereditary_subst t k by rec t her_order :=

hereditary_subst (pair (pair A a) t) k with t := {
  | Var i with nat_compare i k := {
    | Eq := (lift 0 k a, Some (exist A _)) ;
    | Lt := (Var i, None) ;
    | Gt := (Var (pred i), None) } ;

  | Lambda t := (Lambda (fst (hereditary_subst (A, a, t) (S k))), None) ;

  | App f arg with hereditary_subst (A, a, f) k := {
    | p with is_lambda p := {
      hereditary_subst (pair (pair A a) ?(App f arg)) k (App f arg) (inl (isLambda f' A' B' prf)) ?(p) :=
(*       | inl (is_beta_lambda f' A' B' prf) := *)
        let (f'', y) := hereditary_subst (A', fst (hereditary_subst (A, a, arg) k), f') 0 in
          (f'', Some (exist B' _)) ;
      hereditary_subst (pair (pair A a) ?(App f arg)) k (App f arg) (inr f') ?(p) :=
(*       | inr f' :=  *)
        (@(f', fst (hereditary_subst (A, a, arg) k)), None) } } ;

  | Pair i j :=
    (<< fst (hereditary_subst (A, a, i) k), fst (hereditary_subst (A, a, j) k) >>, None) ;

  | Fst t with hereditary_subst (A, a, t) k := {
    | p with is_pair p := {
      hereditary_subst (pair (pair A a) ?(Fst t)) k (Fst t) (inl (isPair u v a b prf)) ?(p) := (u, Some (exist a _)) ;
      hereditary_subst (pair (pair A a) ?(Fst t)) k (Fst t) (inr p) ?(p) := (Fst p, None) }
  } ;

(* FIXME: Warn of unused clauses !     | pair (Pair i j) (Some (product A' B')) := (i, Some (exist _ A' _)) ; *)
(*     | pair (Pair i j) (Some (exist (product A' B') prf)) := (i, Some (exist A' _)) ; *)
(*     | pair p _ := (Fst p, None) } ; *)

  | Snd t with hereditary_subst (A, a, t) k := {
    | p with is_pair p := {
      hereditary_subst (pair (pair A a) ?(Snd t)) k (Snd t) (inl (isPair u v a b prf)) ?(p) := (v, Some (exist b _)) ;
      hereditary_subst (pair (pair A a) ?(Snd t)) k (Snd t) (inr p) ?(p) := (Snd p, None) }
  } ;

(*   | Snd t with hereditary_subst (A, a, t) k := { *)
(*     | pair (Pair i j) (Some (exist (product A' B') prf)) := (j, Some (exist B' _)) ; *)
(*     | pair p _ := (Snd p, None) } ; *)

  | Tt := (Tt, None) }.

Next Obligation. intros. simpl. auto. Defined. 
Solve Obligations using intros; apply hereditary_subst; constructor 2; constructor.

Next Obligation. intros. apply hereditary_subst.  
  destruct prf. simpl in *. subst. repeat constructor.
  simpl in t0. do 2 constructor 1. apply type_direct_subterm_0_0 with (A' ---> B'); eauto using type_direct_subterm.
Defined.

Next Obligation. simpl; intros. 
  destruct prf. subst. right. constructor. 
  right. apply type_direct_subterm_0_0 with (A' ---> B'); eauto using type_direct_subterm.
Defined.

(* Next Obligation. intros. apply hereditary_subst.   *)
(*   destruct prf. simpl in H. subst. repeat constructor. *)
(*   simpl in H. do 2 constructor 1. apply type_direct_subterm_0_0 with (A' ---> B'); eauto using type_direct_subterm. *)
(* Defined. *)

Next Obligation. simpl; intros. 
  destruct prf. subst. right. constructor. 
  right. apply type_direct_subterm_0_0 with (a0 × b); eauto using type_direct_subterm.
Defined.

Next Obligation. simpl; intros. 
  destruct prf. subst. right. constructor. 
  right. apply type_direct_subterm_0_0 with (a0 × b); eauto using type_direct_subterm.
Defined.

Next Obligation. simpl; intros. admit. Defined. 
Next Obligation. intros. admit. Defined.

Ltac invert_term := 
  match goal with
    | [ H : check _ (Lambda _) _ |- _ ] => depelim H
    | [ H : check _ (Pair _ _) _ |- _ ] => depelim H
    | [ H : check _ Tt _ |- _ ] => depelim H
    | [ H : types _ ?t _ |- _ ] => 
      match t with
        | Var _ => depelim H
        | Lambda _ => depelim H
        | App _ _ => depelim H
        | Pair _ _ => depelim H
        | (Fst _ | Snd _) => depelim H
        | Tt => depelim H
      end
  end.


Ltac simp_hsubst := try (rewrite_strat (bottomup (hints hereditary_subst))); 
  rewrite <- ?hereditary_subst_equation_1.



Lemma hereditary_subst_type Γ Γ' t T u U : Γ |-- u : U -> Γ' @ (U :: Γ) |-- t : T ->
  forall t' o, hereditary_subst (U, u, t) (length Γ') = (t', o) ->
    (Γ' @ Γ |-- t' : T /\ (forall ty prf, o = Some (exist ty prf) -> ty = T)). 
Proof. intros. revert H1. funelim (hereditary_subst (U, u, t) (length Γ')); 
    simpl_dep_elim; subst; try (split; [ (intros; try discriminate) | solve [ intros; discriminate ] ]).
  
  invert_term. apply abstraction. 
  specialize (H (A :: Γ')). simplify_IH_hyps. 
  simpl in H.
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *).
  apply H with o; auto. 

  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *).
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *).
  depelim H2. constructor. now apply H. now apply H0.

  depelim H0; term.

  depelim H2.
  (* Var *)
  apply nat_compare_eq in Heq; subst n.
  rewrite !nth_length. split. term. intros. 
  noconf H3.
 
  (* Lt *)
  apply nat_compare_lt in Heq. depelim H0.
  replace (nth n (Γ' @ (U :: Γ)) unit) with (nth n (Γ' @ Γ) unit).
  constructor. rewrite app_length. auto with arith. 

  now do 2 rewrite <- nth_extend_right by auto. 
  
  (* Gt *)
  pose (substitutive _ _ _ _ _ _ H0 H).
  simp subst in t. rewrite Heq in t. simp subst in t.

  (* App *)
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *).
  depelim H2.
  noconf H3.
  specialize (H0 [] eq_refl). simpl in H0; rewrite <- Heqhsubst in H0.
  simplify_IH_hyps. simpl in H0. specialize (H _ _ H1 H2_0).
  specialize (Hind _ _ H1 H2_). rewrite Heq0 in Hind.
  simplify_IH_hyps. depelim Hind. 
  noconf H2.
  split; [|intros ty prf0 Heq'; noconf Heq'; auto].
  depelim H1; eauto. apply H0.
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *).
simplify_IH_hyps. apply H. trivial. 

  (* App no redex *)
  apply is_lambda_inr in Heq. revert Heq. 
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *). intros.
  subst t3. 
  depelim H1.
  apply application with A; eauto. 
  eapply Hind; eauto.
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *). 
  eapply H; eauto.

  simpl in *.
  (* Fst redex *) clear Heq.
  clear H H0. depelim H2. specialize (Hind _ _ H1 H2).
  rewrite Heq0 in Hind. simplify_IH_hyps.
  destruct Hind. depelim H. intuition auto. noconf H4. simplify_IH_hyps. noconf H1.

  (* Fst no redex *)

Lemma is_pair_inr {t} (h : hereditary_type t) : forall t', is_pair h = inr t' -> fst h = t'.
Proof.
  destruct h. funelim (is_pair (t0, o)); intros; try congruence.
Qed.

  apply is_pair_inr in Heq. 
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *). 
  subst t3. simplify_IH_hyps. simpl in *. depelim H0.
  specialize (Hind _ _ H H0); eauto. now apply pair_elim_fst with B.

  (* Snd redex *) clear Heq.
  clear H H0. depelim H2. specialize (Hind _ _ H1 H2).
  rewrite Heq0 in Hind. simplify_IH_hyps.
  destruct Hind. depelim H. intuition auto. noconf H4. simplify_IH_hyps. noconf H1.

  (* Snd no redex *)
  apply is_pair_inr in Heq. 
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *). 
  subst t3. simplify_IH_hyps. simpl in *. depelim H0.
  specialize (Hind _ _ H H0); eauto. now apply pair_elim_snd with A.
Qed.

Instance: subrelation eq (flip impl).
Proof. reduce. subst; auto. Qed.
Ltac simp_hsubst ::= try (rewrite_strat (bottomup (hints hereditary_subst))); rewrite <- ?hereditary_subst_equation_1.

Lemma hereditary_subst_subst U u t Γ' :
  (forall Γ T, Γ |-- u <= U ->
    match hereditary_subst (U, u, t) (length Γ') with
      | (t', Some (exist ty _)) => 
         ((Γ' @ (U :: Γ) |-- t <= T -> Γ' @ Γ |-- t' <= T /\ ty = T) /\
          (Γ' @ (U :: Γ) |-- t => T -> Γ' @ Γ |-- t' <= T /\ ty = T))
      | (t', None) => 
        (Γ' @ (U :: Γ) |-- t <= T -> Γ' @ Γ |-- t' <= T) /\
        (Γ' @ (U :: Γ) |-- t => T -> Γ' @ Γ |-- t' => T)
    end).
Proof. 
  funelim (hereditary_subst (U, u, t) (length Γ')); 
    simpl_dep_elim; subst; intros. 

  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *).
  split; intros Hsyn; [| elim (synth_arrow False Hsyn)].

  invert_term. constructor. 
  specialize (H (A :: Γ')). simplify_IH_hyps. simpl in H; rewrite <- Heqhsubst in H.
  simplify_IH_hyps. specialize (H _ B H0).
  destruct o as [[ty prf]|], H. apply H; eauto. eauto.
  elim (synth_arrow False H2).

  (** Pairs *)
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *).
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *).
  split; intros Hsyn; [|elim (synth_pair False Hsyn)].
  invert_term.
  specialize (H _ A H1). specialize (H0 _ B H1). 
  destruct o as [[ty prf]|], o0 as [[ty' prf']|], H, H0 ; destruct_conjs; constructor; eauto.
  now apply H. now apply H0. now apply H. now apply H0.

  elim (synth_pair False H3).

  (* Unit *)
  split; intros Hsyn; [|elim (synth_unit False Hsyn)].
  depelim Hsyn. term.
  elim (synth_unit False H1).

  clear H H0.
  (* Var *)
  apply nat_compare_eq in Heq; subst n.
  split; intros Hsyn; depelim Hsyn; rewrite ?nth_length. 
  depelim H0; rewrite !nth_length. 
  now split; term. split; term.
 
  (* Lt *)
  apply nat_compare_lt in Heq.
  split; intros Hsyn; depelim Hsyn.
  depelim H1. constructor. auto. 
  replace (nth n (Γ' @ (U :: Γ)) unit) with (nth n (Γ' @ Γ) unit).
  constructor. rewrite app_length. auto with arith. 

  now do 2 rewrite <- nth_extend_right by auto. 

  replace (nth n (Γ' @ (U :: Γ)) unit) with (nth n (Γ' @ Γ) unit).
  constructor. rewrite app_length. auto with arith. 

  now do 2 rewrite <- nth_extend_right by auto. 
  
  (* Gt *)
  apply nat_compare_gt in Heq.
  split; intros Hsyn; depelim Hsyn.
  depelim H1. constructor. auto. 
  replace (nth n (Γ' @ (U :: Γ)) unit) with (nth (pred n) (Γ' @ Γ) unit).
  constructor. rewrite app_length in *. simpl in H1. omega.

  Lemma nth_pred Γ' Γ U n : n > length Γ' -> nth (pred n) (Γ' @ Γ) unit = nth n (Γ' @ (U :: Γ)) unit.
  Proof. revert_until Γ'. induction Γ'; intros.

    destruct n; auto. depelim H.
    destruct n; auto. simpl pred. simpl.
    rewrite <- IHΓ'. destruct n; auto. simpl in H. depelim H. depelim H.
    simpl in *; omega.
  Qed.
  now apply nth_pred.

  replace (nth n (Γ' @ (U :: Γ)) unit) with (nth (pred n) (Γ' @ Γ) unit).
  constructor. rewrite app_length in *. simpl in H0. omega.
  now apply nth_pred.

  (* App *)
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *).
  specialize (H0 [] eq_refl). simpl in H0; rewrite <- Heqhsubst in H0.
  simplify_IH_hyps. simpl in H0. 
  rewrite Heq0 in Hind. 
  revert H.
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *).
  intros. 

  (* Redex *)
  assert((Γ' @ (U :: Γ) |-- @( t2, u) => T → Γ' @ Γ |-- t <= T ∧ b = T)).
  intros Ht; depelim Ht.
  specialize (H _ A H1).
  destruct (Hind Γ (A ---> B) H1). 
  destruct (H4 Ht). noconf H6.
  depelim H5. split; auto.

  destruct o0. destruct s. destruct H.
  specialize (H H2). destruct H. subst x. 
  specialize (H0 _ B H). destruct o. destruct s. 
  destruct H0; now apply H0.
  destruct H0; now apply H0.
  destruct H. 
  specialize (H0 _ B (H H2)). destruct o. destruct s. 
  destruct H0; now apply H0.
  destruct H0; now apply H0.

  split; auto.
  depelim H5.

  split; auto.
  intros.
  apply H2.
  depelim H3. auto.

  (* No redex *)
  assert(Γ' @ (U :: Γ) |-- @( t2, u) => T
      → Γ' @ Γ |-- @( t3, fst (hereditary_subst (U, u0, u) (length Γ'))) => T).
  intros Ht; depelim Ht.
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *).
  revert Heq. 
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *). intros.
  specialize (Hind _ (A ---> B) H0). destruct o0. destruct s. destruct_conjs.
  specialize (H3 Ht). destruct H3; subst x.
  specialize (H _ A H0).

  destruct o. destruct s. destruct_conjs. 
  specialize (H H1). destruct H. subst x.
  eapply application_synth; eauto.
  depelim H3. simp is_lambda in Heq. discriminate.

  depelim H0.
  
  destruct H. specialize (H H1).
  eapply application_synth; eauto.
  depelim H3. simp is_lambda in Heq. noconf Heq.
  depelim H0.

  apply is_lambda_inr in Heq. simpl in Heq. subst t3.
  destruct Hind. specialize (H3 Ht).
  eapply application_synth; eauto.
  specialize (H _ A H0).
  destruct o. destruct s. destruct H. now apply H.
  destruct H. now apply H.

  split; auto. intros.
  depelim H2.
  specialize (H1 H3).
  now constructor.

  (* Pair *)
  clear H H0.
  
  assert( (Γ' @ (U :: Γ) |-- Fst t2 => T → Γ' @ Γ |-- u <= T ∧ a = T)).

  intros Ht; depelim Ht. specialize (Hind _ (A × B) H1). 
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *). 
  noconf Heq0.
  destruct Hind. specialize (H0 Ht). destruct H0. noconf H2. depelim H0. split; auto. depelim H0.
  split; auto.
  intros. depelim H0. intuition.

  assert (Γ' @ (U :: Γ) |-- Fst t2 => T → Γ' @ Γ |-- Fst t3 => T).
  intros Ht; depelim Ht.
  specialize (Hind _ (A × B) H). 
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *). 
  destruct o. destruct s. destruct Hind. 
  specialize (H1 Ht). destruct H1.
  subst x. depelim H1. simp is_pair in Heq. discriminate.
  depelim H.

  apply is_pair_inr in Heq. simpl in Heq ; subst t3.
  eapply pair_elim_fst_synth. now apply Hind.
  split; auto. intros. depelim H1. intuition.

  (* Snd *)
  clear H H0.
  
  assert((Γ' @ (U :: Γ) |-- Snd t2 => T → Γ' @ Γ |-- v <= T ∧ b = T)).

  intros Ht; depelim Ht. specialize (Hind _ (A × B) H1). 
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *). 
  noconf Heq0.
  destruct Hind. specialize (H0 Ht). destruct H0. noconf H2. depelim H0. split; auto. depelim H0.
  split; auto.
  intros. depelim H0. intuition.

  assert (Γ' @ (U :: Γ) |-- Snd t2 => T → Γ' @ Γ |-- Snd t3 => T).
  intros Ht; depelim Ht.
  specialize (Hind _ (A × B) H). 
  on_call hereditary_subst ltac:(fun c => remember c as hsubst; destruct hsubst; simpl in *). 
  destruct o. destruct s. destruct Hind. 
  specialize (H1 Ht). destruct H1.
  subst x. depelim H1. simp is_pair in Heq. discriminate.
  depelim H.

  apply is_pair_inr in Heq. simpl in Heq ; subst t3.
  eapply pair_elim_snd_synth. now apply Hind.
  split; auto. intros. depelim H1. intuition.
Qed.

Lemma check_liftn {Γ Γ' t T} : Γ |-- t <= T -> Γ' @ Γ |-- lift 0 (length Γ') t <= T.
Proof. intros. apply (check_lift Γ t T [] H Γ'). Qed.

Lemma synth_liftn {Γ Γ' t T} : Γ |-- t => T -> Γ' @ Γ |-- lift 0 (length Γ') t => T.
Proof. intros. apply (synthetize_lift Γ t T [] H Γ'). Qed.
Hint Resolve @check_liftn @synth_liftn : term.

Lemma types_normalizes Γ t T : Γ |-- t : T → ∃ u, Γ |-- u <= T.
Proof. induction 1. (* eta-exp *)

  exists (η (nth i Γ unit) i).
  apply (eta_expand Γ i (nth i Γ unit) (neutral_var _)); term.

  destruct IHtypes as [t' tt'].
  exists λ t'; term.

  destruct IHtypes1 as [t' tt'].
  destruct IHtypes2 as [u' uu'].

  (* Hereditary substitution *)
  apply checks_arrow in tt'. destruct tt' as [t'' [t't'' t'B]]. subst.

  generalize (hereditary_subst_subst _ _ t'' [] Γ B uu').
  destruct_call hereditary_subst. destruct o. destruct s.
  simpl in *. intros. destruct H1. exists t0; intuition.
  simpl in *. intros. destruct H1. exists t0; intuition.

  (* Unit *)
  exists Tt; term.

  (* Pair *)
  destruct IHtypes1 as [t' tt'].
  destruct IHtypes2 as [u' uu'].
  exists << t' , u' >>. term.

  (* Fst *)
  destruct IHtypes as [t' tt'].
  depelim tt'. exists t0; term. 

  depelim H0.

  (* Snd *)
  destruct IHtypes as [t' tt'].
  depelim tt'. exists u; term. 

  depelim H0.
Qed.