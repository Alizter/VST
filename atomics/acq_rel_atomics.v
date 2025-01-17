Require Import VST.veric.rmaps.
Require Import VST.veric.compcert_rmaps.
Require Import VST.concurrency.conclib.
Require Import VST.concurrency.ghosts.
Require Import VST.floyd.library.
Require Import VST.floyd.sublist.
Require Import VST.concurrency.invariants.
Require Import VST.concurrency.fupd.
Require Import VST.atomics.general_atomics.

Set Bullet Behavior "Strict Subproofs".

(* To avoid carrying views with protocol assertions, we instead forbid them from appearing in invariants. *)
Parameter objective : mpred -> Prop.
Axiom emp_objective : objective emp.
Axiom data_at_objective : forall {cs : compspecs} sh t v p, objective (data_at sh t v p).
Axiom own_objective : forall {RA : Ghost} g (a : G) pp, objective (own g a pp).
Axiom prop_objective : forall P, objective (!!P).
Axiom andp_objective : forall P Q, objective P -> objective Q -> objective (P && Q).
Axiom exp_objective : forall {A} P, (forall x, objective (P x)) -> objective (EX x : A, P x).
Axiom sepcon_objective : forall P Q, objective P -> objective Q -> objective (P * Q).
Lemma sepcon_list_objective : forall {A} f (l : list A), Forall (fun x => objective (f x)) l -> objective (iter_sepcon f l).
Proof.
  induction l; simpl; intros.
  - apply emp_objective.
  - inv H; apply sepcon_objective; auto.
Qed.

Section inv.

Context {inv_names : invG}.

(* unsound without objective, until we redefine protocols to use thread-local info *)
Axiom inv_alloc : forall E P, objective P -> |> P |-- (|={E}=> EX i : _, invariant i P)%I.

Corollary make_inv : forall E P Q, P |-- Q -> objective Q -> P |-- (|={E}=> EX i : _, invariant i Q)%I.
Proof.
  intros.
  eapply derives_trans, inv_alloc; auto.
  eapply derives_trans, now_later; auto.
Qed.

Ltac prove_objective := repeat
  match goal with
  | |-objective(if _ then _ else _) => if_tac
  | |-objective(exp _) => apply exp_objective; intro
  | |-objective(ghost_ref _ _) => apply exp_objective; intro
  | |-objective(_ * _) => apply sepcon_objective
  | |-objective(_ && _) => apply andp_objective
  | |-objective(!!_) => apply prop_objective
  | |-objective(own _ _ _) => apply own_objective
  | |-objective(data_at _ _ _ _) => apply data_at_objective
  | |-objective(data_at_ _ _ _) => rewrite data_at__eq; apply data_at_objective
  | |-objective(iter_sepcon _ _) => apply sepcon_list_objective;
        rewrite -> ?Forall_map, Forall_forall; intros; simpl
  | _ => try apply own_objective
  end.

Hint Resolve emp_objective data_at_objective own_objective prop_objective andp_objective exp_objective
  sepcon_objective sepcon_list_objective : objective.


Section dup.

Definition duplicable P := P |-- (|==> P * P)%I.

Lemma emp_duplicable : duplicable emp.
Proof.
  iIntros "? !>"; iFrame.
Qed.
Hint Resolve emp_duplicable : dup.

Lemma sepcon_duplicable : forall P Q, duplicable P -> duplicable Q -> duplicable (P * Q).
Proof.
  intros; unfold duplicable in *.
  sep_apply H; sep_apply H0.
  iIntros "[>[$ $] >[$ $]]"; auto.
Qed.
Hint Resolve sepcon_duplicable : dup.

Lemma iter_sepcon_duplicable : forall {B} (f : B -> mpred) l, (forall a, duplicable (f a)) -> duplicable (iter_sepcon f l).
Proof.
  induction l; simpl; auto with dup.
Qed.

Lemma list_duplicate : forall {B} (f : B -> mpred) l Q, duplicable Q ->
  iter_sepcon f l * Q |-- (|==> iter_sepcon (fun x => Q * f x) l * Q)%I.
Proof.
  induction l; simpl; intros.
  { iIntros "[$ $]"; auto. }
  iIntros "(($ & ?) & Q)".
  iDestruct (H with "Q") as ">[$ Q]".
  iApply IHl; auto; iFrame.
Qed.

(* Should all duplicables be of this form? *)
Lemma invariant_duplicable' : forall N P, duplicable (invariant N P).
Proof.
  unfold duplicable; intros.
  rewrite <- invariant_dup in *; apply bupd_intro.
Qed.
Hint Resolve invariant_duplicable' : dup.

Lemma ghost_snap_duplicable : forall `{_ : PCM_order} (s : G) p, duplicable (ghost_snap s p).
Proof.
  intros; unfold duplicable.
  erewrite ghost_snap_join; [apply bupd_intro|].
  apply join_refl.
Qed.
Hint Resolve ghost_snap_duplicable : dup.

Lemma prop_duplicable : forall P Q, duplicable Q -> duplicable (!!P && Q).
Proof.
  intros; unfold duplicable.
  Intros.
  rewrite prop_true_andp; auto.
Qed.
Hint Resolve prop_duplicable : dup.

Lemma exp_duplicable : forall {A} (P : A -> mpred), (forall x, duplicable (P x)) -> duplicable (exp P).
Proof.
  unfold duplicable; intros.
  Intro x.
  eapply derives_trans; eauto.
  iIntros ">[H ?] !>"; iSplitL "H"; iApply (bi.exist_intro(Ψ := P) with "[$]").
Qed.

Definition weak_dup P := P -* |==> (P * P).

End dup.

End inv.

Hint Resolve emp_duplicable sepcon_duplicable invariant_duplicable' ghost_snap_duplicable prop_duplicable : dup.

Section atomics.

Context {CS : compspecs}.

Section protocols.

Class protocol {state : Type} (Iread Ifull : state -> Z -> mpred) :=
  { full_read s v : Ifull s v |-- |==> Ifull s v * Iread s v; read_dup s v : duplicable (Iread s v) }.

Global Instance dup_protocol {state} (T : state -> Z -> mpred) (Ht : forall s v, duplicable (T s v)) :
  protocol T T.
Proof.
  split; auto.
Qed.

Context {state : Type}.

Parameter protocol_A : val -> state -> (state -> state -> Prop) ->
  ((state -> Z -> mpred) * (state -> Z -> mpred)) -> mpred.

Context (ord : state -> state -> Prop) `{RelationClasses.PreOrder _ ord}
  (Tread Tfull : state -> Z -> mpred).

Axiom protocol_A_nonexpansive : forall l s ord Tread1 Tfull1 Tread2 Tfull2,
  (ALL s : state, ALL v : Z, (Tread1 s v <=> Tread2 s v) && (Tfull1 s v <=> Tfull2 s v)) |--
  protocol_A l s ord (Tread1, Tfull1) <=> protocol_A l s ord (Tread2, Tfull2).

Lemma protocol_A_super_non_expansive : forall n l s ord Tread Tfull,
  approx n (protocol_A l s ord (Tread, Tfull)) =
  approx n (protocol_A l s ord (fun s v => approx n (Tread s v), fun s v => approx n (Tfull s v))).
Proof.
  intros.
  apply approx_eq_i'.
  intros m ?.
  apply protocol_A_nonexpansive.
  intros ??; split; apply fash_equiv_approx; auto.
Qed.

Notation T := (Tread, Tfull).

Axiom protocol_A_duplicable : forall l s, duplicable (protocol_A l s ord T).

Axiom protocol_A_join' : forall l s1 s2,
  protocol_A l s1 ord T * protocol_A l s2 ord T |--
  EX s : _, !!(ord s1 s /\ ord s2 s) && protocol_A l s ord T.

Axiom make_protocol : forall {P : protocol Tread Tfull} sh l v s,
  writable_share sh -> repable_signed v ->
  data_at sh tint (vint v) l * |> Tfull s v |-- (|==> protocol_A l s ord T)%I.

Axiom protocol_A_later : forall l s,
  protocol_A l s ord (|>Tread, |>Tfull) |-- |>protocol_A l s ord T.

Axiom protocol_A_delay : forall l s,
  protocol_A l s ord T |-- protocol_A l s ord (|>Tread, |>Tfull).

End protocols.

Definition OrdType s := ArrowType s (ArrowType s (ConstType Prop)).
Definition PredType s := ArrowType s (ArrowType (ConstType Z) Mpred).

Definition LA_type := ProdType (ProdType (ProdType (ProdType (ProdType (ProdType
  (ConstType val) (DependentType 0)) (OrdType (DependentType 0)))
  (ProdType (PredType (DependentType 0)) (PredType (DependentType 0))))
  (ConstType coPset)) (PredType (DependentType 0))) (ConstType invG).

Program Definition load_acq_spec := TYPE LA_type
  WITH l : val, s : _, st_ord : _ -> _ -> Prop, T : ((_ -> Z -> mpred) * (_ -> Z -> mpred)),
       E : _, Q : _ -> Z -> mpred, inv_names : invG
  PRE [ 1%positive OF tptr tint ]
   PROP ()
   LOCAL (temp 1%positive l)
   SEP ((ALL s' : _, !!(st_ord s s') --> ALL v : _,
          (fst T s' v * protocol_A l s' st_ord T) -* |={E}=> Q s' v);
        protocol_A l s st_ord T)%I
  POST [ tint ]
   EX v : Z, EX s' : _,
   PROP (repable_signed v; st_ord s s')
   LOCAL (temp ret_temp (vint v))
   SEP (Q s' v).
Next Obligation.
Proof.
  repeat intro.
  destruct _f2.
  unfold PROPx, LOCALx, SEPx; simpl; rewrite !approx_andp; f_equal;
    f_equal; rewrite -> !sepcon_emp, ?approx_sepcon, ?approx_idem.
  rewrite protocol_A_super_non_expansive; f_equal.
  rewrite -> !approx_allp by auto; f_equal; extensionality.
  setoid_rewrite approx_imp; f_equal; f_equal.
  rewrite !(approx_allp _ _ _ 0); f_equal; extensionality.
  setoid_rewrite fview_shift_nonexpansive.
  rewrite -> !approx_sepcon, !approx_idem, protocol_A_super_non_expansive; auto.
Qed.
Next Obligation.
Proof.
  repeat intro.
  rewrite !approx_exp; apply f_equal; extensionality.
  rewrite !approx_exp; apply f_equal; extensionality.
  unfold PROPx, LOCALx, SEPx; simpl; rewrite !approx_andp; do 2 apply f_equal;
    rewrite -> !sepcon_emp, ?approx_sepcon, ?approx_idem; auto.
Qed.

(*Definition SR_type := ProdType (ProdType (ProdType (ProdType (ProdType (ProdType (ProdType
  (ConstType (val * Z)) (DependentType 0)) (DependentType 0)) (OrdType (DependentType 0)))
  (ProdType (PredType (DependentType 0)) (PredType (DependentType 0))))
  Mpred) (ConstType (iname -> Prop))) Mpred.

Program Definition store_rel_spec := TYPE SR_type
  WITH l : val, v : Z, s : _, s'' : _, st_ord : _ -> _ -> Prop, T : ((_ -> Z -> mpred) * (_ -> Z -> mpred)),
       P : mpred, II : Z -> mpred, lI : list Z, Q' : mpred, Q : mpred
  PRE [ 1%positive OF tptr tint, 2%positive OF tint ]
   PROP (repable_signed v; forall s', st_ord s' s'';
         view_shift (fold_right sepcon emp (map II lI) * P)
                    (protocol_A l s st_ord T * snd T s'' v * Q')%logic;
         view_shift (protocol_A l s'' st_ord T * Q')
                    (fold_right sepcon emp (map II lI) * Q)%logic)
   LOCAL (temp 1%positive l; temp 2%positive (vint v))
   SEP (fold_right sepcon emp (map (fun p => invariant (II p)) lI); P)
  POST [ tvoid ]
   PROP ()
   LOCAL ()
   SEP (fold_right sepcon emp (map (fun p => invariant (II p)) lI); Q).
Next Obligation.
Proof.
  repeat intro.
  destruct x as ((((((((((?, ?), ?), ?), ?), (?, ?)), ?), ?), ?), ?), ?); simpl.
  unfold PROPx; simpl; rewrite !approx_andp; f_equal.
  - rewrite !prop_and, !approx_andp; f_equal; f_equal; f_equal; [|f_equal].
    + rewrite view_shift_super_non_expansive.
      setoid_rewrite view_shift_super_non_expansive at 2; do 2 apply f_equal; f_equal.
      * rewrite !approx_sepcon, !approx_sepcon_list', approx_idem.
        erewrite !map_map, map_ext; eauto.
        intro; simpl; rewrite approx_idem; auto.
      * rewrite !approx_sepcon, !approx_idem, protocol_A_super_non_expansive; auto.
    + rewrite view_shift_super_non_expansive.
      setoid_rewrite view_shift_super_non_expansive at 2.
      rewrite !approx_sepcon, !approx_sepcon_list', protocol_A_super_non_expansive, !approx_idem.
      erewrite !map_map, map_ext; eauto.
      intro; simpl; rewrite approx_idem; auto.
  - unfold LOCALx; simpl; rewrite !approx_andp; apply f_equal.
    unfold SEPx; simpl; rewrite !sepcon_emp, !approx_sepcon, !approx_idem, !approx_sepcon_list'.
    erewrite !map_map, map_ext; eauto.
    intros; simpl; rewrite invariant_super_non_expansive; auto.
Qed.
Next Obligation.
Proof.
  repeat intro.
  destruct x as ((((((((((?, ?), ?), ?), ?), ?), ?), ?), ?), ?), ?); simpl.
  unfold PROPx, LOCALx, SEPx; simpl; rewrite !approx_andp; do 2 apply f_equal;
    rewrite !sepcon_emp, ?approx_sepcon, ?approx_idem.
  rewrite !approx_sepcon_list'.
  erewrite !map_map, map_ext; eauto.
  intros; simpl; rewrite invariant_super_non_expansive; auto.
Qed.*)

(*Definition SR_type' := ProdType (ProdType (ProdType (ProdType (ProdType (ProdType (ProdType (ProdType
  (ConstType (val * Z)) (DependentType 0)) (OrdType (DependentType 0)))
  (ProdType (PredType (DependentType 0)) (PredType (DependentType 0))))
  Mpred) (ArrowType (ConstType Z) Mpred)) (ConstType (list Z))) (ArrowType (DependentType 0) Mpred))
  (ArrowType (DependentType 0) Mpred).

(* The GPS/iGPS store_rel rule is only really useful when we have a single writer, only write once
   to a location, only really want to maintain an invariant, or otherwise aren't really doing anything
   with write-write races. The final-state restriction is partially to ensure that the target state is
   reachable, and partly to deal with the fact that the logic doesn't assume mo-coherence
   and thus a write may be placed "before" a write that's already been observed. This more relaxed
   rule is probably unsound. *)
Program Definition store_rel_spec := TYPE SR_type'
  WITH l : val, v : Z, s : _, st_ord : _ -> _ -> Prop, T : ((_ -> Z -> mpred) * (_ -> Z -> mpred)),
       P : mpred, II : Z -> mpred, lI : list Z, Q' : _ -> mpred, Q : _ -> mpred
  PRE [ 1%positive OF tptr tint, 2%positive OF tint ]
   PROP (repable_signed v;
         view_shift (fold_right sepcon emp (map II lI) * P)
                    (protocol_A l s st_ord T * P');
         forall s' v', repable_signed v' -> st_ord s s' ->
         view_shift (P' * snd T s' v')
                    (EX s'' : _, !!(st_ord s' s'') && snd T s'' v * Q' s'')%logic;
         forall s', st_ord s s' ->
         view_shift (protocol_A l s' st_ord T * Q' s')
                    (fold_right sepcon emp (map II lI) * Q s')%logic)
   LOCAL (temp 1%positive l; temp 2%positive (vint v))
   SEP (fold_right sepcon emp (map (fun p => invariant (II p)) lI); P)
  POST [ tvoid ]
   EX s' : _,
   PROP (st_ord s s')
   LOCAL ()
   SEP (fold_right sepcon emp (map (fun p => invariant (II p)) lI); Q s').
Next Obligation.
Proof.
  repeat intro.
  destruct x as (((((((((?, ?), s), ?), (?, ?)), ?), ?), ?), ?), ?); simpl.
  unfold PROPx; simpl; rewrite !approx_andp; f_equal.
  - rewrite !prop_and, !approx_andp; f_equal; f_equal; [|f_equal].
    + rewrite !prop_forall, !(approx_allp _ _ _ s); apply f_equal; extensionality s'.
      rewrite !prop_impl; setoid_rewrite approx_imp; do 2 apply f_equal.
      rewrite view_shift_super_non_expansive.
      setoid_rewrite view_shift_super_non_expansive at 2; do 2 apply f_equal; f_equal.
      * rewrite !approx_sepcon, !approx_sepcon_list', approx_idem.
        erewrite !map_map, map_ext; eauto.
        intro; simpl; rewrite approx_idem; auto.
      * rewrite !approx_sepcon, protocol_A_super_non_expansive; apply f_equal.
        rewrite !approx_exp; apply f_equal; extensionality s''.
        rewrite !approx_sepcon, !approx_andp, !approx_idem; auto.
    + rewrite !prop_forall, !(approx_allp _ _ _ s); apply f_equal; extensionality s'.
      rewrite !prop_impl; setoid_rewrite approx_imp; do 2 apply f_equal.
      rewrite view_shift_super_non_expansive.
      setoid_rewrite view_shift_super_non_expansive at 2.
      do 2 apply f_equal; f_equal.
      * rewrite !approx_sepcon, !approx_idem, protocol_A_super_non_expansive; auto.
      * rewrite !approx_sepcon, !approx_sepcon_list', approx_idem.
        erewrite !map_map, map_ext; eauto.
        intro; simpl; rewrite approx_idem; auto.
  - unfold LOCALx; simpl; rewrite !approx_andp; apply f_equal.
    unfold SEPx; simpl; rewrite !sepcon_emp, !approx_sepcon, !approx_idem, !approx_sepcon_list'.
    erewrite !map_map, map_ext; eauto.
    intros; simpl; rewrite invariant_super_non_expansive; auto.
Qed.
Next Obligation.
Proof.
  repeat intro.
  destruct x as (((((((((?, ?), ?), ?), ?), ?), ?), ?), ?), ?); simpl.
  rewrite !approx_exp; apply f_equal; extensionality s'.
  unfold PROPx, LOCALx, SEPx; simpl; rewrite !approx_andp; do 2 apply f_equal;
    rewrite !sepcon_emp, ?approx_sepcon, ?approx_idem.
  rewrite !approx_sepcon_list'.
  erewrite !map_map, map_ext; eauto.
  intros; simpl; rewrite invariant_super_non_expansive; auto.
Qed.*)

Definition CRA_type := ProdType (ProdType (ProdType (ProdType (ProdType
  (ProdType (ProdType (ConstType (val * Z * Z)) (DependentType 0)) (OrdType (DependentType 0)))
  (ProdType (PredType (DependentType 0)) (PredType (DependentType 0))))
  (ConstType coPset)) (ArrowType (DependentType 0) Mpred))
  (PredType (DependentType 0))) (ConstType invG).

Program Definition CAS_RA_spec := TYPE CRA_type
  WITH l : val, c : Z, v : Z, s : _, st_ord : _ -> _ -> Prop, T : ((_ -> Z -> mpred) * (_ -> Z -> mpred)),
       E : _, Q : _ -> mpred, R : _ -> Z -> mpred, inv_names : invG
  PRE [ 1%positive OF tptr tint, 2%positive OF tint, 3%positive OF tint ]
   PROP (repable_signed c; repable_signed v)
   LOCAL (temp 1%positive l; temp 2%positive (vint c); temp 3%positive (vint v))
   SEP ((ALL s' : _, !!(st_ord s s') --> (snd T s' c -* |={E}=>
          (EX s'' : _, (!!(st_ord s' s'')) && ((protocol_A l s'' st_ord T) -* |={E}=> |> snd T s'' v *
           Q s'')))) && (* is this right? *)
        (ALL s' : _, ALL v' : _, !!(st_ord s s' /\ repable_signed v' /\ v' <> c) -->
          ((|> fst T s' v' * protocol_A l s' st_ord T) -* |={E}=> (R s' v')));
        protocol_A l s st_ord T)%I
  POST [ tint ]
   EX v' : Z, EX s' : _,
   PROP (repable_signed v'; st_ord s s')
   LOCAL (temp ret_temp (Val.of_bool (if eq_dec v' c then true else false)))
   SEP (if eq_dec v' c then Q s' else R s' v').
Next Obligation.
Proof.
  repeat intro.
  destruct _f3.
  unfold PROPx, LOCALx, SEPx; simpl; rewrite !approx_andp; f_equal;
    f_equal; rewrite -> !sepcon_emp, ?approx_sepcon, ?approx_idem.
  f_equal; [|rewrite protocol_A_super_non_expansive; f_equal].
  rewrite !approx_andp; f_equal.
  - rewrite -> !approx_allp by auto; f_equal; extensionality.
    setoid_rewrite approx_imp; f_equal; f_equal.
    setoid_rewrite fview_shift_nonexpansive.
    rewrite !approx_idem; f_equal; f_equal; f_equal.
    rewrite !approx_exp; f_equal; extensionality.
    rewrite !approx_andp; f_equal.
    rewrite wand_nonexpansive; setoid_rewrite wand_nonexpansive at 3; f_equal; f_equal.
    + rewrite protocol_A_super_non_expansive; reflexivity.
    + rewrite fupd_nonexpansive; setoid_rewrite fupd_nonexpansive at 2; f_equal; f_equal.
      rewrite -> !approx_sepcon, approx_idem; f_equal.
      rewrite later_nonexpansive; auto.
  - rewrite -> !approx_allp by auto; f_equal; extensionality.
    rewrite -> !approx_allp by auto; f_equal; extensionality.
    setoid_rewrite approx_imp; f_equal; f_equal.
    setoid_rewrite fview_shift_nonexpansive.
    rewrite -> !approx_sepcon, !approx_idem; f_equal; f_equal.
    rewrite protocol_A_super_non_expansive; f_equal.
    rewrite later_nonexpansive; auto.
Qed.
Next Obligation.
Proof.
  repeat intro.
  rewrite !approx_exp; apply f_equal; extensionality.
  rewrite !approx_exp; apply f_equal; extensionality.
  unfold PROPx, LOCALx, SEPx; simpl; rewrite !approx_andp; do 2 apply f_equal;
    rewrite -> !sepcon_emp, ?approx_sepcon, ?approx_idem; auto.
  if_tac; rewrite approx_idem; auto.
Qed.

End atomics.
