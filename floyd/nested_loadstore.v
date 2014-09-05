Require Import floyd.base.
Require Import floyd.assert_lemmas.
Require Import floyd.client_lemmas.
Require Import floyd.nested_field_lemmas.
Require Import floyd.data_at_lemmas.
Require Import floyd.field_mapsto.
Require Import floyd.closed_lemmas.
Require Import floyd.loadstore_lemmas.
Require Import Coq.Logic.JMeq.

Local Open Scope logic.

(**********************************************

nf_sub: substraction in type
PROJ_reptype: big reptype value
proj_reptype: small reptype value
nf_pair_reptype: reversion of proj/PROJ
upd_reptype
data_at_with_exception
data_at_with_exception * field_at = data_at

Comment: for now, ident_eq will be used throughout all these definition
because it is used in field_type and field_offset in compcert. However,
it should be replaced by Pos.eqb here and in compcert.

Further plan: multi substraction, which is useful for definion tree structure

mnf_sub: substraction in type
mPROJ_reptype: big reptype value
mproj_reptype: small reptype value
mnf_pair_reptype: reversion of proj/PROJ
mupd_reptype
data_at_with_mexception
data_at_with_mexception * [field_at] = data_at

**********************************************)

(*** type level ***)

Lemma nested_field_type2_nil: forall t, nested_field_type2 t nil = t.
Proof.
  intros.
  unfold nested_field_type2.
  reflexivity.
Defined.

Definition nested_field_type2_cons: forall t id ids0,
  nested_field_type2 t (id :: ids0) = 
  match nested_field_type2 t ids0 with
  | Tstruct i f a => match field_offset_rec id f 0, field_type id f with
                     | Errors.OK _, Errors.OK t0 => t0
                     | _, _ => Tvoid
                     end
  | Tunion i f a  => match field_type id f with
                     | Errors.OK t0 => t0
                     | _ => Tvoid
                     end
  | _ => Tvoid
  end.
Proof.
  intros.
  unfold nested_field_type2 in *.
  simpl.
  destruct (nested_field_rec t ids0) eqn:HH; try reflexivity.
  destruct p.
  destruct t0; try reflexivity; unfold field_offset;
  destruct (field_offset_rec id f 0), (field_type id f); reflexivity.
Defined.

Fixpoint all_fields_except_one (f: fieldlist) (id: ident) : option fieldlist :=
 match f with
 | Fnil => None
 | Fcons i t f0 =>
   if ident_eq id i
   then Some f0
   else match (all_fields_except_one f0 id) with
        | None => None
        | Some res => Some (Fcons i t res)
        end
 end.

Fixpoint all_fields_except_one2 (f: fieldlist) (id: ident) : fieldlist :=
 match f with
 | Fnil => Fnil
 | Fcons i t f0 =>
   if ident_eq id i
   then f0
   else Fcons i t (all_fields_except_one2 f0 id)
 end.

Fixpoint all_fields_replace_one (f: fieldlist) (id: ident) (t0: type) : option fieldlist :=
 match f with
 | Fnil => None
 | Fcons i t f0 =>
   if ident_eq id i
   then Some (Fcons i t0 f0)
   else match (all_fields_replace_one f0 id t0) with
        | None => None
        | Some res => Some (Fcons i t res)
        end
 end.

Fixpoint all_fields_replace_one2 (f: fieldlist) (id: ident) (t0: type) : fieldlist :=
 match f with
 | Fnil => Fnil
 | Fcons i t f0 =>
   if ident_eq id i
   then Fcons i t0 f0
   else Fcons i t (all_fields_replace_one2 f0 id t0)
 end.

Fixpoint nf_replace t ids t0: option type :=
  match ids with
  | nil => Some t0
  | id :: ids0 => 
    match nested_field_type2 t ids0 with
    | Tstruct i f a =>
      match all_fields_replace_one f id t0 with
      | Some f' => nf_replace t ids0 (Tstruct i f' a)
      | None => None
      end
    | Tunion i f a =>
      match all_fields_replace_one f id t0 with
      | Some f' => nf_replace t ids0 (Tunion i f' a)
      | None => None
      end
    | _ => None
    end
  end.

Fixpoint nf_replace2 t ids t0: type :=
  match ids with
  | nil => t0
  | id :: ids0 => 
    match nested_field_type2 t ids0 with
    | Tstruct i f a => nf_replace2 t ids0 (Tstruct i (all_fields_replace_one2 f id t0) a)
    | Tunion i f a => nf_replace2 t ids0 (Tunion i (all_fields_replace_one2 f id t0) a)
    | _ => t
    end
  end.

Definition nf_sub t id ids: option type :=
  match nested_field_type2 t ids with
  | Tstruct i f a =>
    match all_fields_except_one f id with
    | Some f' => nf_replace t ids (Tstruct i f' a)
    | None => None
    end
  | Tunion i f a =>
    match all_fields_except_one f id with
    | Some f' => nf_replace t ids (Tunion i f' a)
    | None => None
    end
  | _ => None
  end.

Definition nf_sub2 t id ids: type :=
  match nested_field_type2 t ids with
  | Tstruct i f a => nf_replace2 t ids (Tstruct i (all_fields_except_one2 f id) a)
  | Tunion i f a => nf_replace2 t ids (Tunion i (all_fields_except_one2 f id) a)
  | _ => t
  end.

Lemma all_fields_except_one_all_fields_except_one2: forall f id,
  all_fields_except_one f id = Some (all_fields_except_one2 f id) \/
  all_fields_except_one f id = None /\ all_fields_except_one2 f id = f.
Proof.
  intros.
  induction f.
  + auto.
  + simpl; if_tac; [ |destruct IHf].
    - auto.
    - rewrite H0. auto.
    - destruct H0; rewrite H0, H1. auto.
Defined.

Lemma all_fields_replace_one_all_fields_replace_one2: forall f id t,
  all_fields_replace_one f id t = Some (all_fields_replace_one2 f id t) \/
  all_fields_replace_one f id t = None /\ all_fields_replace_one2 f id t = f.
Proof.
  intros.
  induction f.
  + auto.
  + simpl; if_tac; [ |destruct IHf].
    - auto.
    - rewrite H0. auto.
    - destruct H0; rewrite H0, H1. auto.
Defined.

Lemma all_fields_replace_one2_identical: forall f i t,
  (field_type i f = Errors.OK t \/ exists e, field_type i f = Errors.Error e) -> all_fields_replace_one2 f i t = f.
Proof.
  intros.
  induction f.
  + reflexivity.
  + simpl in *.
    if_tac in H.
    - destruct H as [? | [? ?]]; inversion H; reflexivity.
    - rewrite (IHf H). reflexivity.
Defined.

Lemma nf_replace2_identical: forall t ids, t = nf_replace2 t ids (nested_field_type2 t ids).
Proof.
  intros.
  induction ids.
  + reflexivity.
  + simpl.
    destruct (nested_field_type2 t ids) eqn:?; auto.
    - (* Tstruct *)
      rewrite all_fields_replace_one2_identical; auto.
      erewrite nested_field_type2_cons; eauto.
      rewrite Heqt0.
      change (field_offset_rec a f 0) with (field_offset a f).
      solve_field_offset_type a f; eauto.
    - (* Tunion *)
      rewrite all_fields_replace_one2_identical; auto.
      erewrite nested_field_type2_cons; eauto.
      rewrite Heqt0.
      change (field_offset_rec a f 0) with (field_offset a f).
      solve_field_offset_type a f; eauto.
Defined.

Lemma nf_replace_nf_replace2: forall t ids t0,
  nf_replace t ids t0 = Some (nf_replace2 t ids t0) \/
  nf_replace t ids t0 = None /\ nf_replace2 t ids t0 = t.
Proof.
  induction ids; intros.
  + auto.
  + simpl. simpl; destruct (nested_field_type2 t ids) eqn:?; auto.
    - destruct (all_fields_replace_one_all_fields_replace_one2 f a t0) as [H | [H0 H1]].
      * rewrite H; auto.
      * rewrite H0, H1, <- Heqt1.
        rewrite <- nf_replace2_identical.
        auto.
    - destruct (all_fields_replace_one_all_fields_replace_one2 f a t0) as [H | [H0 H1]].
      * rewrite H; auto.
      * rewrite H0, H1, <- Heqt1.
        rewrite <- nf_replace2_identical.
        auto.
Defined.

Lemma nf_sub_nf_sub2: forall t id ids,
  nf_sub t id ids = Some (nf_sub2 t id ids) \/
  nf_sub t id ids = None /\ nf_sub2 t id ids = t.
Proof.
  intros.
  unfold nf_sub2, nf_sub.
  destruct (nested_field_type2 t ids) eqn:?; auto.
  + destruct (all_fields_except_one_all_fields_except_one2 f id) as [H | [H0 H1]].
    - rewrite H; auto.
      apply nf_replace_nf_replace2.
    - rewrite H0, H1, <- Heqt0.
      rewrite <- nf_replace2_identical.
      auto.
  + destruct (all_fields_except_one_all_fields_except_one2 f id) as [H | [H0 H1]].
    - rewrite H; auto.
      apply nf_replace_nf_replace2.
    - rewrite H0, H1, <- Heqt0.
      rewrite <- nf_replace2_identical.
      auto.
Defined.

Lemma all_fields_replace_one_isSome_lemma: forall f i t0 t1, isSome (all_fields_replace_one f i t0) -> isSome (all_fields_replace_one f i t1).
Proof.
  intros.
  induction f.
  + auto.
  + simpl in *.
    if_tac.
    auto.
    destruct (all_fields_replace_one f i t0), (all_fields_replace_one f i t1); auto.
Defined.

Lemma nf_replace_isSome_lemma: forall t ids t0 t1, isSome (nf_replace t ids t0) -> isSome (nf_replace t ids t1).
Proof.
  induction ids; intros.
  + auto.
  + simpl in *.
    destruct (nested_field_type2 t ids); try inversion H.
    - pose proof all_fields_replace_one_isSome_lemma f a t0 t1.
      pose proof all_fields_replace_one_isSome_lemma f a t1 t0.
      destruct (all_fields_replace_one f a t0), (all_fields_replace_one f a t1).
      * eapply IHids, H.
      * simpl in H0. tauto.
      * simpl in H1. tauto.
      * inversion H.
    - pose proof all_fields_replace_one_isSome_lemma f a t0 t1.
      pose proof all_fields_replace_one_isSome_lemma f a t1 t0.
      destruct (all_fields_replace_one f a t0), (all_fields_replace_one f a t1).
      * eapply IHids, H.
      * simpl in H0. tauto.
      * simpl in H1. tauto.
      * inversion H.
Defined.

Lemma nested_field_type2_nf_replace2_aux:
  forall i f t0 z2,
  isSome (all_fields_replace_one f i t0) ->
  match
    match field_offset i (all_fields_replace_one2 f i t0) with
    | Errors.OK ofs =>
        match field_type i (all_fields_replace_one2 f i t0) with
        | Errors.OK t'' => Some (z2 + ofs, t'')
        | Errors.Error _ => None
        end
    | Errors.Error _ => None
    end
  with
  | Some (_, t1) => t1
  | None => Tvoid
  end = t0.
Proof.
  intros.
  unfold field_offset in *.
  revert H; generalize 0.
  induction f; intros.
  + inversion H.
  + unfold all_fields_replace_one. simpl in *.
    if_tac.
    - simpl; if_tac; [| congruence]; reflexivity.
    - simpl; if_tac; [congruence |].
      apply IHf.
      destruct (all_fields_replace_one f i t0); inversion H; auto.
Defined.

Lemma nested_field_type2_nf_replace2_aux':
  forall i f t0 (z2: Z),
  isSome (all_fields_replace_one f i t0) ->
  match
    match field_type i (all_fields_replace_one2 f i t0) with
    | Errors.OK t'' => Some (z2, t'')
    | Errors.Error _ => None
    end
  with
  | Some (_, t1) => t1
  | None => Tvoid
  end = t0.
Proof.
  intros.
  unfold field_offset in *.
  revert H.
  induction f; intros.
  + inversion H.
  + unfold all_fields_replace_one. simpl in *.
    if_tac.
    - simpl; if_tac; [| congruence]; reflexivity.
    - simpl; if_tac; [congruence |].
      apply IHf.
      destruct (all_fields_replace_one f i t0); inversion H; auto.
Defined.

Lemma nested_field_type2_nf_replace2: forall t ids t0, isSome (nf_replace t ids t0) -> nested_field_type2 (nf_replace2 t ids t0) ids =  t0.
Proof.
  intros.
  revert t0 H; induction ids; intros.
  + reflexivity.
  + simpl.
    simpl in H.
    unfold nested_field_type2 in *.
    destruct (nested_field_rec t ids) as [[z1 t1]|] eqn:?; [| inversion H].
    destruct t1; try inversion H.
    - destruct (all_fields_replace_one f a t0) eqn:?; try inversion H. simpl.
      pose proof (IHids (Tstruct i (all_fields_replace_one2 f a t0) a0)
                  (nf_replace_isSome_lemma _ _ _ _ H)).
      destruct (nested_field_rec
             (nf_replace2 t ids (Tstruct i (all_fields_replace_one2 f a t0) a0))
             ids) as [[z2 t2]|];
      try destruct t2; try inversion H0.
      eapply nested_field_type2_nf_replace2_aux.
      rewrite Heqo0.
      simpl; auto.
    - destruct (all_fields_replace_one f a t0) eqn:?; try inversion H. simpl.
      pose proof (IHids (Tunion i (all_fields_replace_one2 f a t0) a0)
                  (nf_replace_isSome_lemma _ _ _ _ H)).
      destruct (nested_field_rec
             (nf_replace2 t ids (Tunion i (all_fields_replace_one2 f a t0) a0))
             ids) as [[z2 t2]|];
      try destruct t2; try inversion H0.
      eapply nested_field_type2_nf_replace2_aux'.
      rewrite Heqo0.
      simpl; auto.
Defined.

Lemma all_fields_replace_one2_all_fields_replace_one2: forall f i t0 t1, all_fields_replace_one2 (all_fields_replace_one2 f i t0) i t1 = all_fields_replace_one2 f i t1.
Proof.
  intros.
  induction f.
  + reflexivity.
  + simpl.
    if_tac.
    - simpl; if_tac; [| congruence]; reflexivity.
    - simpl; if_tac; [congruence |].
      f_equal. apply IHf.
Defined.

Lemma nf_replace2_nf_replace2: forall t ids t0 t1, nf_replace2 (nf_replace2 t ids t0) ids t1 = nf_replace2 t ids t1.
Proof.
  intros.
  destruct (nf_replace t ids t0) as [tt|] eqn:HE.
  + revert t0 t1 tt HE.
    induction ids; intros.
    - reflexivity.
    - simpl.
      simpl in HE.
      destruct (nested_field_type2 t ids) eqn:HH; try rewrite HH; auto.
      * (* Tstruct *)
        destruct (all_fields_replace_one f a t0); [ |inversion HE].
        assert (isSome (nf_replace t ids (Tstruct i (all_fields_replace_one2 f a t0) a0))).
          apply nf_replace_isSome_lemma with (Tstruct i f0 a0).
          rewrite HE; simpl; auto.
        destruct (nf_replace t ids (Tstruct i (all_fields_replace_one2 f a t0) a0)) eqn:?; inversion H.
        rewrite nested_field_type2_nf_replace2.
        erewrite IHids.
        rewrite all_fields_replace_one2_all_fields_replace_one2.
        reflexivity.
        eauto.
        rewrite Heqo. auto.
      * (* Tunion *)
        destruct (all_fields_replace_one f a t0); [ |inversion HE].
        assert (isSome (nf_replace t ids (Tunion i (all_fields_replace_one2 f a t0) a0))).
          apply nf_replace_isSome_lemma with (Tunion i f0 a0).
          rewrite HE; simpl; auto.
        destruct (nf_replace t ids (Tunion i (all_fields_replace_one2 f a t0) a0)) eqn:?; inversion H.
        rewrite nested_field_type2_nf_replace2.
        erewrite IHids.
        rewrite all_fields_replace_one2_all_fields_replace_one2.
        reflexivity.
        eauto.
        rewrite Heqo. auto.
  + pose proof nf_replace_nf_replace2 t ids t0.
    destruct H as [? | [? ?]]; [congruence |].
    rewrite H0.
    reflexivity.
Defined.

Lemma nf_replace2_identical': forall t id ids, t = nf_replace2 (nf_sub2 t id ids) ids (nested_field_type2 t ids).
Proof.
  intros.
  unfold nf_sub2.
  pattern (nested_field_type2 t ids) at 1.
  destruct (nested_field_type2 t ids); try apply nf_replace2_identical.
  + rewrite nf_replace2_nf_replace2.
    apply nf_replace2_identical.
  + rewrite nf_replace2_nf_replace2.
    apply nf_replace2_identical.
Defined.

(*** reptype level ***)

Lemma proj_reptype_aux: forall t ids,
  nested_field_type2 t ids =
  match ids with
  | nil => t
  | id :: ids0 =>
    match nested_field_type2 t ids0 with
    | Tstruct i f a => match field_offset_rec id f 0, field_type id f with
                       | Errors.OK _, Errors.OK t0 => t0
                       | _, _ => Tvoid
                       end
    | Tunion i f a  => match field_type id f with
                       | Errors.OK t0 => t0
                       | _ => Tvoid
                       end
    | _ => Tvoid
    end
  end.
Proof.
  intros.
  destruct ids; [apply nested_field_type2_nil | apply nested_field_type2_cons].
Defined.

Fixpoint proj_reptype_structlist id f ofs (v: reptype_structlist f) : 
  reptype (match field_offset_rec id f ofs, field_type id f with
           | Errors.OK _, Errors.OK t0 => t0
           | _, _ => Tvoid
           end) :=
  match f as f'
    return reptype_structlist f' -> reptype (match field_offset_rec id f' ofs, field_type id f' with
                                             | Errors.OK _, Errors.OK t0 => t0
                                             | _, _ => Tvoid
                                             end) with
  | Fnil => fun _ => default_val _
  | Fcons i0 t0 flds0 => 
    if is_Fnil flds0 as b
      return ((if b then reptype t0 else reptype t0 * reptype_structlist flds0) ->
              reptype (match (if ident_eq id i0
                             then Errors.OK (align ofs (alignof t0))
                             else field_offset_rec id flds0 (align ofs (alignof t0) + sizeof t0)),
                             (if ident_eq id i0 then Errors.OK t0 else field_type id flds0)
                       with
                       | Errors.OK _, Errors.OK t0 => t0
                       | _, _ => Tvoid
                       end))
    then fun v =>
      if ident_eq id i0 as b0
        return reptype (match (if b0
                             then Errors.OK (align ofs (alignof t0))
                             else field_offset_rec id flds0 (align ofs (alignof t0) + sizeof t0)),
                             (if b0 then Errors.OK t0 else field_type id flds0)
                        with
                       | Errors.OK _, Errors.OK t0 => t0
                       | _, _ => Tvoid
                       end)
      then v
      else default_val _
    else fun v => 
      if ident_eq id i0 as b0
        return reptype (match (if b0
                             then Errors.OK (align ofs (alignof t0))
                             else field_offset_rec id flds0 (align ofs (alignof t0) + sizeof t0)),
                             (if b0 then Errors.OK t0 else field_type id flds0)
                        with
                       | Errors.OK _, Errors.OK t0 => t0
                       | _, _ => Tvoid
                       end)
      then fst v
      else proj_reptype_structlist id flds0 (align ofs (alignof t0) + sizeof t0) (snd v)
  end v.

Fixpoint proj_reptype (t: type) (ids: list ident) (v: reptype t) : reptype (nested_field_type2 t ids) :=
  let res :=
  match ids as ids'
    return reptype (match ids' with
                    | nil => t
                    | id :: ids0 =>
                      match nested_field_type2 t ids0 with
                      | Tstruct i f a => match field_offset_rec id f 0, field_type id f with
                                         | Errors.OK _, Errors.OK t0 => t0
                                         | _, _ => Tvoid
                                         end
                      | Tunion i f a  => match field_type id f with
                                         | Errors.OK t0 => t0
                                         | _ => Tvoid
                                         end
                      | _ => Tvoid
                      end
                    end)
  with
  | nil => v
  | id :: ids0 => 
    match nested_field_type2 t ids0 as T
      return reptype T -> reptype (match T with
                                   | Tstruct i f a => match field_offset_rec id f 0, field_type id f
                                                      with
                                                      | Errors.OK _, Errors.OK t0 => t0
                                                      | _, _ => Tvoid
                                                      end
                                   | Tunion i f a  => match field_type id f with
                                                      | Errors.OK t0 => t0
                                                      | _ => Tvoid
                                                      end
                                   | _ => Tvoid
                                   end)
    with
    | Tstruct i f a => fun v0 => proj_reptype_structlist id f 0 v0
    | _ => fun _ => default_val _
    end (proj_reptype t ids0 v)
  end
  in eq_rect_r reptype res (proj_reptype_aux t ids).

(*
Fixpoint proj_reptype_structlist t id ids f (v: nested_reptype_structlist t ids f) : reptype (nested_field_type2 t (id :: ids)) :=
  match f as f'
    return nested_reptype_structlist t ids f' -> reptype (nested_field_type2 t (id :: ids)) with
  | Fnil => fun _ => default_val _
  | Fcons i0 t0 flds0 => 
    if is_Fnil flds0 as b
      return ((if b 
               then reptype (nested_field_type2 t (i0 :: ids)) 
               else reptype (nested_field_type2 t (i0 :: ids)) * 
                    nested_reptype_structlist t ids flds0) ->
              reptype (nested_field_type2 t (id :: ids)))
    then fun v =>
      match ident_eq id i0 with
      | left H => eq_rect_r (fun i => reptype (nested_field_type2 t (i :: ids))) v H
      | right H => default_val _
      end
    else fun v => 
      match ident_eq id i0 with
      | left H => eq_rect_r (fun i => reptype (nested_field_type2 t (i :: ids))) (fst v) H
      | right _ => proj_reptype_structlist t id ids flds0 (snd v)
      end
  end v.

Lemma proj_reptype_aux: forall t ids, 
  nested_legal_fieldlist t = true ->
  match nested_field_type2 t ids with
  | Tstruct i f a => nested_reptype_structlist t ids f
  | _ => reptype (nested_field_type2 t ids)
  end = reptype (nested_field_type2 t ids).
Proof.
  intros.
  destruct (nested_field_type2 t ids) eqn:HH; auto.
  rewrite <- HH.
  eapply eq_sym, nested_reptype_structlist_lemma2; eauto.
Defined.

Fixpoint proj_reptype_rec (t: type) (ids: list ident) (H: nested_legal_fieldlist t = true) (v: reptype t) : reptype (nested_field_type2 t ids) :=
  match ids as ids' return reptype (nested_field_type2 t ids')
  with
  | nil => eq_rect_r reptype v (nested_field_type2_nil t)
  | id :: ids0 =>
    match nested_field_type2 t ids0 as T
      return match T with
             | Tstruct i f a => nested_reptype_structlist t ids0 f
             | _ => reptype (nested_field_type2 t ids0)
             end -> reptype (nested_field_type2 t (id :: ids0))
    with
    | Tstruct i f a => fun v => proj_reptype_structlist t id ids0 f v
    | _ => fun _ => default_val _
    end (eq_rect_r (fun T => T) (proj_reptype_rec t ids0 H v) (proj_reptype_aux t ids0 H))
  end.

Definition proj_reptype t ids v :=
 (if nested_legal_fieldlist t as b
    return nested_legal_fieldlist t = b -> reptype (nested_field_type2 t ids)
  then fun H => proj_reptype_rec t ids H v
  else fun _ => default_val _) eq_refl.

Arguments proj_reptype / t ids v.
*)
Lemma gupd_reptype_structlist_aux: forall f i0 t0,
  all_fields_replace_one2 f i0 t0 = match f with
                                    | Fnil => Fnil
                                    | Fcons i1 t1 flds0 => 
                                      if ident_eq i0 i1
                                      then Fcons i1 t0 flds0
                                      else Fcons i1 t1 (all_fields_replace_one2 flds0 i0 t0)
                                    end.
Proof.
  intros.
  destruct f; [|simpl; if_tac]; reflexivity.
Defined.

Fixpoint gupd_reptype_structlist f (i0: ident) (t0: type) (v: reptype_structlist f) (v0: reptype t0) : reptype_structlist (all_fields_replace_one2 f i0 t0) :=
  let res :=
  match f as f'
    return reptype_structlist f' -> 
           reptype_structlist (match f' with
                               | Fnil => Fnil
                               | Fcons i1 t1 flds0 => 
                                 if ident_eq i0 i1
                                 then Fcons i1 t0 flds0
                                 else Fcons i1 t1 (all_fields_replace_one2 flds0 i0 t0)
                               end)
  with
  | Fnil => fun _ => struct_default_val _
  | Fcons i1 t1 flds0 => fun v =>
   (if ident_eq i0 i1 as b
      return reptype_structlist (if b
                                 then Fcons i1 t0 flds0
                                 else Fcons i1 t1 (all_fields_replace_one2 flds0 i0 t0))
    then
     (if is_Fnil flds0 as b0
        return (if b0 then reptype t1 else reptype t1 * reptype_structlist flds0) ->
               (if b0 then reptype t0 else reptype t0 * reptype_structlist flds0)
      then fun _ => v0
      else fun v => (v0, snd v)
     ) v
    else
     (if is_Fnil flds0 as b0
        return (if b0 then reptype t1 else reptype t1 * reptype_structlist flds0) ->
               (if is_Fnil (all_fields_replace_one2 flds0 i0 t0) then reptype t1 else reptype t1 * 
                   reptype_structlist (all_fields_replace_one2 flds0 i0 t0))
      then
        if is_Fnil (all_fields_replace_one2 flds0 i0 t0) as b1
          return reptype t1 ->
                 (if b1 then reptype t1 else reptype t1 * 
                     reptype_structlist (all_fields_replace_one2 flds0 i0 t0))
        then fun _ => default_val _
        else fun _ => (default_val _, struct_default_val _)
      else
        if is_Fnil (all_fields_replace_one2 flds0 i0 t0) as b1
          return reptype t1 * reptype_structlist flds0 ->
                 (if b1 then reptype t1 else reptype t1 * 
                     reptype_structlist (all_fields_replace_one2 flds0 i0 t0))
        then fun _ => default_val _
        else fun v => (fst v, gupd_reptype_structlist flds0 i0 t0 (snd v) v0)
      ) v
   )
  end v
  in
  eq_rect_r reptype_structlist res (gupd_reptype_structlist_aux f i0 t0).

Fixpoint gupd_reptype (t: type) (ids: list ident) (t0: type) (v: reptype t) (v0: reptype t0): reptype (nf_replace2 t ids t0) := 
  match ids as ids' return reptype (nf_replace2 t ids' t0) with
  | nil => v0
  | id :: ids0 => 
    match (nested_field_type2 t ids0) as T 
      return reptype T -> reptype (match T with
                                   | Tstruct i f a => nf_replace2 t ids0 
                                     (Tstruct i (all_fields_replace_one2 f id t0) a)
                                   | Tunion i f a => nf_replace2 t ids0 
                                     (Tunion i (all_fields_replace_one2 f id t0) a)
                                   | _ => t
                                   end)
    with
    | Tstruct i f a => fun v' => gupd_reptype t ids0 (Tstruct i (all_fields_replace_one2 f id t0) a) v 
                                 (gupd_reptype_structlist f id t0 v' v0)
    | _ => fun _ => default_val _
    end (proj_reptype t ids0 v)
  end.

Fixpoint upd_reptype (t: type) (ids: list ident) (v: reptype t) (v0: reptype (nested_field_type2 t ids)): reptype t :=
  eq_rect_r reptype (gupd_reptype t ids (nested_field_type2 t ids) v v0) (nf_replace2_identical t ids).
  (* It is indeed not a fixpoint. But this definition style *)
  (* enables it to get unfolded directly by simpl tactic.   *)

Fixpoint proj_except_reptype_structlist (f: fieldlist) (id: ident) (v: reptype_structlist f): reptype_structlist (all_fields_except_one2 f id) :=
  let res :=
  match f as f'
    return reptype_structlist f' -> 
           reptype_structlist (match f' with
                               | Fnil => Fnil
                               | Fcons i t f0 =>
                                   if ident_eq id i
                                   then f0
                                   else Fcons i t (all_fields_except_one2 f0 id)
                               end)
  with
  | Fnil => fun v => v
  | Fcons i t f0 => fun v => 
     if ident_eq id i as b
       return reptype_structlist (if b
                                  then f0
                                  else Fcons i t (all_fields_except_one2 f0 id))
     then
      (if (is_Fnil f0) as b0
         return (if b0 then reptype t else reptype t * reptype_structlist f0) -> reptype_structlist f0
       then fun _ => struct_default_val _
       else fun v => snd v) v
     else
      (if (is_Fnil f0) as b0
         return (if b0 then reptype t else reptype t * reptype_structlist f0) -> 
                (if is_Fnil (all_fields_except_one2 f0 id) then reptype t else 
                 reptype t * reptype_structlist (all_fields_except_one2 f0 id))
       then fun v => 
         if is_Fnil (all_fields_except_one2 f0 id) as b1
           return if b1 then reptype t else 
                  reptype t * reptype_structlist (all_fields_except_one2 f0 id)
         then v
         else (v, struct_default_val _)
       else fun v =>
         if is_Fnil (all_fields_except_one2 f0 id) as b1
           return if b1 then reptype t else 
                  reptype t * reptype_structlist (all_fields_except_one2 f0 id)
         then fst v
         else (fst v, proj_except_reptype_structlist f0 id (snd v))
      ) v
  end v
  in
  match f as f'
    return reptype_structlist (match f' with
                               | Fnil => Fnil
                               | Fcons i t f0 =>
                                   if ident_eq id i
                                   then f0
                                   else Fcons i t (all_fields_except_one2 f0 id)
                               end) ->
           reptype_structlist (all_fields_except_one2 f' id)
  with
  | Fnil => fun v => v
  | _ => fun v => v
  end res.

Fixpoint proj_except_reptype (t: type) (id: ident) (ids: list ident) (v: reptype t) : reptype (nf_sub2 t id ids) :=
  match nested_field_type2 t ids as T 
    return reptype T ->
           reptype match T with
                   | Tstruct i f a => nf_replace2 t ids (Tstruct i (all_fields_except_one2 f id) a)
                   | Tunion i f a => nf_replace2 t ids (Tunion i (all_fields_except_one2 f id) a)
                   | _ => t
                   end
  with
  | Tstruct i f a => fun v0 => gupd_reptype t ids (Tstruct i (all_fields_except_one2 f id) a) v 
                     (proj_except_reptype_structlist f id v0)
  | Tunion i f a => fun _ => default_val _
  | _ => fun _ => v
  end (proj_reptype t ids v).

Fixpoint pair_reptype_structlist (id: ident) (f: fieldlist) (ofs: Z)
  (v: reptype_structlist (all_fields_except_one2 f id)) 
  (v0: reptype match field_offset_rec id f ofs, field_type id f with
               | Errors.OK _, Errors.OK t0 => t0
               | _, _ => Tvoid
               end): reptype_structlist f :=
  match f as f'
    return reptype_structlist (all_fields_except_one2 f' id) ->
           reptype match field_offset_rec id f' ofs, field_type id f' with
                   | Errors.OK _, Errors.OK t0 => t0
                   | _, _ => Tvoid
                   end ->
           reptype_structlist f'
  with
  | Fnil => fun v _ => v
  | Fcons i t flds0 => 
    if ident_eq id i as b
      return reptype_structlist (if b then flds0 else Fcons i t (all_fields_except_one2 flds0 id)) ->
             reptype match (if b
                            then Errors.OK (align ofs (alignof t))
                            else field_offset_rec id flds0 (align ofs (alignof t) + sizeof t)),
                           (if b then Errors.OK t else field_type id flds0)
                     with
                     | Errors.OK _, Errors.OK t0 => t0
                     | _, _ => Tvoid
                     end ->
             if is_Fnil flds0 then reptype t else reptype t * reptype_structlist flds0
    then 
      if is_Fnil flds0 as b0
        return reptype_structlist flds0 -> reptype t ->
               (if b0 then reptype t else reptype t * reptype_structlist flds0)
      then fun _ v0 => v0
      else fun v v0 => (v0, v)
    else
      if is_Fnil flds0 as b0
        return (if is_Fnil (all_fields_except_one2 flds0 id)
                then reptype t else reptype t * 
                  reptype_structlist (all_fields_except_one2 flds0 id)) ->
               reptype match field_offset_rec id flds0 (align ofs (alignof t) + sizeof t),
                             field_type id flds0 with
                       | Errors.OK _, Errors.OK t0 => t0
                       | _, _ => Tvoid
                       end ->
               (if b0 then reptype t else reptype t * reptype_structlist flds0)
      then
        if is_Fnil (all_fields_except_one2 flds0 id) as b1
          return (if b1 then reptype t else reptype t * 
                  reptype_structlist (all_fields_except_one2 flds0 id)) ->
                  reptype match field_offset_rec id flds0 (align ofs (alignof t) + sizeof t),
                             field_type id flds0 with
                          | Errors.OK _, Errors.OK t0 => t0
                          | _, _ => Tvoid
                          end -> reptype t
        then fun v v0 => v
        else fun v v0 => fst v
      else
        if is_Fnil (all_fields_except_one2 flds0 id) as b1
          return (if b1 then reptype t else reptype t * 
                  reptype_structlist (all_fields_except_one2 flds0 id)) ->
                  reptype match field_offset_rec id flds0 (align ofs (alignof t) + sizeof t),
                             field_type id flds0 with
                          | Errors.OK _, Errors.OK t0 => t0
                          | _, _ => Tvoid
                          end -> reptype t * reptype_structlist flds0
        then fun v v0 => (v, pair_reptype_structlist id flds0 (align ofs (alignof t) + sizeof t) 
                             (struct_default_val _) v0)
        else fun v v0 => (fst v, pair_reptype_structlist id flds0 (align ofs (alignof t) + sizeof t) 
                                (snd v) v0)
  end v v0.

Lemma all_fields_replace_one_field_type_isSome_lemma: forall i f t0,
  match field_type i f with
  | Errors.OK _ => isSome (all_fields_replace_one f i t0)
  | _ => all_fields_replace_one f i t0 = None
  end.
Proof.
  intros.
  induction f.
  + simpl. auto.
  + simpl.
    destruct (ident_eq i i0); [simpl; auto |].
    destruct (all_fields_replace_one f i t0), (field_type i f); simpl in *; congruence.
Defined.

Lemma nf_replace_nested_field_type_isSome_lemma: forall t ids t0, isSome (nf_replace t ids t0) <-> isSome (nested_field_type t ids).
Proof.
  intros.
  unfold nested_field_type.
  induction ids.
  + simpl. tauto.
  + simpl.
    unfold nested_field_type2.
    destruct (nested_field_rec t ids) as [[z1 t1] |]; [destruct t1|]; try solve[(simpl; tauto)].
    - (* Tstruct *)
      pose proof all_fields_replace_one_field_type_isSome_lemma a f t0.
      destruct (all_fields_replace_one f a t0);
      solve_field_offset_type a f; auto.
      * simpl in *.
        apply iff_trans with (B := isSome (nf_replace t ids t0)); auto.
        split; apply nf_replace_isSome_lemma.
      * inversion H.
      * inversion H.
      * tauto.
    - (* Tstruct *)
      pose proof all_fields_replace_one_field_type_isSome_lemma a f t0.
      destruct (all_fields_replace_one f a t0);
      solve_field_offset_type a f; auto.
      * simpl in *.
        apply iff_trans with (B := isSome (nf_replace t ids t0)); auto.
        split; apply nf_replace_isSome_lemma.
      * inversion H.
      * inversion H.
      * tauto.
Defined.

Lemma pair_reptype_aux: forall t id ids,
  match nested_field_type2 t ids with
  | Tstruct i f a => Tstruct i (all_fields_except_one2 f id) a
  | Tunion i f a => Tunion i (all_fields_except_one2 f id) a
  | _ => nested_field_type2 t ids
  end = nested_field_type2 (nf_sub2 t id ids) ids.
Proof.
  intros.
  unfold nf_sub2.
  destruct (nested_field_type2 t ids) eqn:?; auto.
  + (* Tstruct *)
    apply eq_sym, nested_field_type2_nf_replace2.
    apply nf_replace_nested_field_type_isSome_lemma.
    unfold nested_field_type, nested_field_type2 in *.
    destruct (nested_field_rec t ids) as [[? ?]|]; simpl in *.
    auto.
    inversion Heqt0.
  + (* Tunion *)
    apply eq_sym, nested_field_type2_nf_replace2.
    apply nf_replace_nested_field_type_isSome_lemma.
    unfold nested_field_type, nested_field_type2 in *.
    destruct (nested_field_rec t ids) as [[? ?]|]; simpl in *.
    auto.
    inversion Heqt0.
Defined.

Fixpoint pair_reptype (t: type) (id: ident) (ids: list ident) (v: reptype (nf_sub2 t id ids)) (v0: reptype (nested_field_type2 t (id :: ids))) : reptype t :=
  match nested_field_type2 t ids as T
    return reptype match T with
                   | Tstruct i f a => Tstruct i (all_fields_except_one2 f id) a
                   | Tunion i f a => Tunion i (all_fields_except_one2 f id) a
                   | _ => nested_field_type2 t ids
                   end ->
           reptype match T with
                   | Tstruct i f a => match field_offset_rec id f 0, field_type id f with
                                      | Errors.OK _, Errors.OK t0 => t0
                                      | _, _ => Tvoid
                                      end
                   | Tunion i f a  => match field_type id f with
                                      | Errors.OK t0 => t0
                                      | _ => Tvoid
                                      end
                   | _ => Tvoid
                   end ->
           t = nf_replace2 (nf_sub2 t id ids) ids T ->
           reptype t
  with
  | Tstruct i f a => fun v1 v0 H => eq_rect_r reptype 
                       (gupd_reptype _ ids (Tstruct i f a) v (pair_reptype_structlist id f 0 v1 v0)) H
  | _ => fun _ _ _ => default_val _
  end
  (eq_rect_r reptype (proj_reptype _ ids v) (pair_reptype_aux t id ids))
  (eq_rect_r reptype v0 (eq_sym (nested_field_type2_cons t id ids)))
  (nf_replace2_identical' t id ids).

Lemma eq_rect_JMeq: forall (A:Type) (x y: A) F (v: F x) (H: x = y), JMeq (eq_rect x F v y H) v.
Proof.
  intros.
  subst.
  rewrite <- eq_rect_eq.
  reflexivity.
Qed.

Lemma eq_rect_r_JMeq: forall (A:Type) (x y: A) F (v: F x) (H: y = x), JMeq (eq_rect_r F v H) v.
Proof.
  intros.
  subst.
  unfold eq_rect_r; rewrite <- eq_rect_eq.
  reflexivity.
Qed.

Lemma proj_reptype_nil: forall t v, nested_legal_fieldlist t = true -> JMeq (proj_reptype t nil v) v.
Proof.
  intros.
  simpl.
  rewrite eq_rect_r_JMeq.
  reflexivity.
Qed.

Lemma proj_reptype_cons_Tstruct: forall t id ids i f a v v0,
  nested_legal_fieldlist t = true ->
  nested_field_type2 t ids = Tstruct i f a ->
  JMeq (proj_reptype t ids v) v0 ->
  JMeq (proj_reptype t (id :: ids) v) (proj_reptype_structlist id f 0 v0).
Proof.
  intros.
  simpl in *.
  revert H1.
  generalize (proj_reptype t ids v) as v1.
  generalize (nested_field_type2_cons t id ids) as HH.
  rewrite H0.
  intros; clear v.
  rewrite eq_rect_r_JMeq.
  rewrite H1.
  reflexivity.
Qed.

(*
Lemma proj_reptype_nil: forall t v, nested_legal_fieldlist t = true -> JMeq (proj_reptype t nil v) v.
Proof.
  intros.
  simpl.
  generalize (@eq_refl bool (nested_legal_fieldlist t)).
  pattern (nested_legal_fieldlist t) at 2 3.
  rewrite H; intros.
  rewrite eq_rect_r_JMeq.
  reflexivity.
Qed.

Lemma proj_reptype_cons_Tstruct: forall t id ids i f a v v0,
  nested_legal_fieldlist t = true ->
  nested_field_type2 t ids = Tstruct i f a ->
  JMeq (proj_reptype t ids v) v0 ->
  JMeq (proj_reptype t (id :: ids) v) (proj_reptype_structlist t id ids f v0).
Proof.
  intros.
  simpl in *.
  revert H1.
  generalize (@eq_refl bool (nested_legal_fieldlist t)) as HH.
  pattern (nested_legal_fieldlist t) at 2 3 7.
  rewrite H.
  intros.
  match goal with
  | |- JMeq (_ ?T) _ =>
    assert (JMeq T (proj_reptype_rec t ids HH v)) as H2
      by apply eq_rect_r_JMeq with (F := fun T => T);
    revert H2;
    generalize T
  end.
  pattern (nested_field_type2 t ids) at 1 11 22.
  rewrite H0.
  intros.
  rewrite H1 in H2.
  rewrite H2.
  reflexivity.
Qed.
*)

Module Test.
  Definition T1 := Tstruct 1%positive (Fcons 101%positive tint (Fcons 102%positive tint Fnil)) noattr.
  Definition T2 := Tstruct 2%positive (Fcons 201%positive T1 (Fcons 202%positive T1 Fnil)) noattr.
  Definition T3 := Tstruct 3%positive (Fcons 301%positive T2 (Fcons 302%positive T2 Fnil)) noattr.

  Definition v : reptype T3 :=
   (((Vint (Int.repr 1), Vint (Int.repr 2)), (Vint (Int.repr 3), Vint (Int.repr 4))), 
    ((Vint (Int.repr 5), Vint (Int.repr 6)), (Vint (Int.repr 7), Vint (Int.repr 8)))).

  Arguments eq_rect_r / {A} {x} P H {y} H0.

  Lemma Test1: 
    JMeq (proj_reptype T3 (201%positive :: 302%positive :: nil) v) (Vint (Int.repr 5), Vint (Int.repr 6)).
  Proof.
    simpl.
    reflexivity.
  Qed.

  Lemma Test2:
    JMeq (upd_reptype T3 (201%positive :: 302%positive :: nil) v 
    (Vint (Int.repr 15), Vint (Int.repr 16))) 
    (((Vint (Int.repr 1), Vint (Int.repr 2)), (Vint (Int.repr 3), Vint (Int.repr 4))), 
    ((Vint (Int.repr 15), Vint (Int.repr 16)), (Vint (Int.repr 7), Vint (Int.repr 8)))).
  Proof.
    simpl.
    reflexivity.
  Qed.

  Lemma Test3:
    JMeq (proj_except_reptype T3 201%positive (302%positive :: nil) v) 
    (((Vint (Int.repr 1), Vint (Int.repr 2)), (Vint (Int.repr 3), Vint (Int.repr 4))), 
    ((Vint (Int.repr 7), Vint (Int.repr 8)))).
  Proof.
    simpl.
    reflexivity.
  Qed.

  Lemma Test4:
    JMeq (pair_reptype T3 201%positive (302%positive :: nil)
    (((Vint (Int.repr 1), Vint (Int.repr 2)), (Vint (Int.repr 3), Vint (Int.repr 4))), 
    ((Vint (Int.repr 7), Vint (Int.repr 8))))
    ((Vint (Int.repr 5), Vint (Int.repr 6)))) v.
  Proof.
    simpl.
    reflexivity.
  Qed.
End Test.

Definition precise : mpred -> Prop := msl.predicates_sl.precise.

Lemma mapsto_precise: forall sh t v p, precise (mapsto sh t p v).
Proof.
Admitted.

Lemma emp_precise: precise emp.
Proof.
Admitted.

Lemma precise_sepcon: forall P Q, precise P -> precise Q -> precise (P * Q).
Proof.
Admitted.

Lemma precise_andp: forall P Q, precise P -> precise Q -> precise (P && Q).
Proof.
Admitted.

Lemma precise_prop_andp: forall P Q, precise Q -> precise (!! P && Q).
Proof.
Admitted.

Lemma precise_wand_sepcon: forall P Q, precise P -> P -* (P * Q) = Q.
Proof.
Admitted.

Lemma precise_sepcon_cancel: forall P Q R, precise P -> P * Q = P * R -> Q = R.
Proof.
  intros.
  rewrite <- precise_wand_sepcon with (P:= P) (Q := Q) by auto.
  rewrite <- precise_wand_sepcon with (P:= P) (Q := R) by auto.
  rewrite H0.
  reflexivity.
Qed.

(* Here, this precise can be set to be more stronger property, such as splittable precise. *)
Lemma mapsto__precise: forall sh t p, precise (mapsto_ sh t p).
Proof.
  intros.
  unfold mapsto_.
  apply mapsto_precise.
Qed.

Lemma FF_precise: precise (FF).
Proof.
  replace (@FF mpred Nveric) with (mapsto Tsh tint Vundef Vundef).
  apply mapsto_precise.
  unfold mapsto.
  reflexivity.
Qed.

Lemma memory_block_precise: forall sh n p, precise (memory_block sh n p).
Proof.
  intros.
Transparent memory_block.
  unfold memory_block.
Opaque memory_block.
  destruct p; try apply FF_precise.
  apply precise_prop_andp.
  forget (nat_of_Z (Int.unsigned n)) as nn; clear n.
  forget (Int.unsigned i) as ii; clear i.
  generalize ii.
  induction nn; intros.
  + apply emp_precise.
  + simpl. 
    apply precise_sepcon.
    apply mapsto_precise.
    apply IHnn.
Qed.

Lemma at_offset'_preserve_precise: forall P, (forall p, precise (P p)) -> 
  forall be p, P (offset_val (Int.repr 0) p) = P p -> precise (at_offset' P be p).
Proof.
  intros.
  rewrite at_offset'_eq by auto.
  apply H.
Qed.

Lemma spacer_precise: forall sh be ed p, precise (spacer sh be ed p).
Proof.
  intros.
  unfold spacer.
  if_tac.
  apply emp_precise.
  apply at_offset'_preserve_precise; [intros; apply memory_block_precise |].
  apply memory_block_offset_zero.
Qed.

Lemma withspacer_preserve_precise: forall sh be ed P p,
  precise (P p) -> precise (withspacer sh be ed P p).
Proof.
  intros.
  rewrite withspacer_spacer.
Opaque spacer.
  simpl.
Transparent spacer.
  apply precise_sepcon.
  apply spacer_precise.
  exact H.
Qed.

Lemma array_at'_preserve_precise: forall t sh P v lo hi p,
  (forall v p, precise (P v p)) -> precise (array_at' t sh P v lo hi p).
Proof.
  intros.
  unfold array_at'.
  apply precise_prop_andp.
  unfold rangespec.
  forget (nat_of_Z (hi - lo)) as nn; clear hi.
  generalize lo.
  induction nn; intros; simpl.
  + apply emp_precise.
  + apply precise_sepcon.
    apply H.
    apply IHnn.
Qed.

Lemma data_at'_precise: forall sh env t ofs v p, precise (data_at' sh env t ofs v p).
Proof.
  intros.
  apply (type_mut (fun t => forall ofs v p, precise (data_at' sh env t ofs v p))
                  (fun tl => True)
                  (fun fld => (forall al ofs v p, precise (sfieldlist_at' sh env fld al ofs v p)) /\
                              (forall al ofs v p, precise (ufieldlist_at' sh env fld al ofs v p))));
  intros; auto; try simpl;
  try (unfold at_offset2; apply at_offset'_preserve_precise;
       [| try (apply memory_block_offset_zero);
          try (apply mapsto_offset_zero);
          try (symmetry; apply array_at'_offset_zero)]).
  + apply memory_block_precise.
  + apply mapsto_precise.
  + apply mapsto_precise.
  + apply mapsto_precise.
  + apply mapsto_precise.
  + intros; apply array_at'_preserve_precise.
    apply H.
  + apply memory_block_precise.
  + destruct H as [H _]; apply H.
  + destruct H as [_ H]; apply H.
  + apply mapsto_precise.
  + simpl; split; intros; apply precise_prop_andp, emp_precise.
  + destruct H0.
    split; intros; destruct (is_Fnil f).
    - apply withspacer_preserve_precise, H.
    - apply precise_sepcon.
      apply withspacer_preserve_precise, H.
      apply H0.
    - apply withspacer_preserve_precise, H.
    - destruct v0.
      apply withspacer_preserve_precise, H.
      apply H1.
Qed.

Lemma data_at_precise: forall sh t v p, precise (data_at sh t v p).
Proof.
  intros; unfold data_at.
  simpl.
  apply precise_prop_andp, data_at'_precise.
Qed.

Lemma field_at_precise: forall sh t ids v p, precise (field_at sh t ids v p).
Proof.
  intros; unfold field_at.
  simpl.
  apply precise_prop_andp, data_at'_precise.
Qed.

Lemma is_Fnil_fieldlist_app:
  forall f1 f2, is_Fnil (fieldlist_app f1 f2) = true -> is_Fnil f1 = true /\ is_Fnil f2 = true.
Proof.
  intros.
  destruct f1, f2; simpl in *; auto.
Qed.

Fixpoint reptype_suf {fp fs: fieldlist} (v: reptype_structlist (fieldlist_app fp fs)) (vs: reptype_structlist fs) :=
  match fp as fp'
    return reptype_structlist (fieldlist_app fp' fs) -> Prop
  with
  | Fnil => fun v => v = vs
  | Fcons i0 t0 fp0 => 
    if (is_Fnil (fieldlist_app fp0 fs)) as b
      return (if b then reptype t0 else reptype t0 * reptype_structlist (fieldlist_app fp0 fs)) -> Prop
    then fun _ => True
    else fun v => reptype_suf (snd v) vs
  end v.

Lemma reptype_suf_Fnil: forall {f} (v: reptype_structlist f), exists v0, @reptype_suf Fnil f v0 v /\ JMeq v0 v.
Proof.
  intros.
  simpl in v |- *.
  eauto.
Qed.

Lemma reptype_suf_Fcons: forall f0 i0 t1 i1 t2 f v v0, @reptype_suf f0 (Fcons i0 t1 (Fcons i1 t2 f)) v v0 -> exists v1, JMeq v v1 /\ @reptype_suf (fieldlist_app f0 (Fcons i0 t1 Fnil)) (Fcons i1 t2 f) v1 (snd v0).
Proof.
  intros.
  induction f0.
  + simpl in *.
    exists v.
    rewrite H; auto.
  + simpl in v, H |- *.
    revert v H.
    destruct (is_Fnil (fieldlist_app f0 (Fcons i0 t1 (Fcons i1 t2 f)))) eqn:?.
    Focus 1. {
      apply is_Fnil_fieldlist_app in Heqb.
      destruct Heqb as [_ H].
      inversion H.
    } Unfocus.
    destruct (is_Fnil (fieldlist_app (fieldlist_app f0 (Fcons i0 t1 Fnil))
                  (Fcons i1 t2 f))) eqn:?.
    Focus 1. {
      apply is_Fnil_fieldlist_app in Heqb0.
      destruct Heqb0 as [_ H0].
      inversion H0.
    } Unfocus.
    intros.
    destruct (IHf0 (snd v) H) as [v2 [? ?]].
    exists (fst v, v2).
    split.
    - clear H1; revert v2 H0.
      rewrite <- fieldlist_app_Fcons.
      intros.
      rewrite <- H0.
      destruct v; reflexivity.
    - simpl.
      exact H1.
Qed.

Lemma fieldlist_no_replicate_fact2:
  forall f1 f2, fieldlist_no_replicate (fieldlist_app f1 f2) = true ->
  forall i t1 t2, field_type i f1 = Errors.OK t1 -> field_type i f2 = Errors.OK t2 -> False.
Proof.
  intros.
  induction f1.
  + inversion H0.
  + simpl in H0, H.
    apply andb_true_iff in H.
    if_tac in H0.
    - destruct H as [? _].
      rewrite fieldlist_app_in in H.
      rewrite negb_true_iff, orb_false_iff in H.
      destruct H as [_ ?].
      subst.
      clear IHf1 H0.
      induction f2; [inversion H1|].
      simpl in H1.
      if_tac in H1.
      * subst; simpl in H.
        rewrite Pos.eqb_refl in H.
        inversion H.
      * simpl in H.
        apply Pos.eqb_neq in H0.
        rewrite H0 in H.
        apply IHf2; auto.
    - destruct H as [_ ?].
      apply IHf1; auto.
Qed.

Lemma proj_reptype_structlist_ofs: forall i f ofs ofs0 v,
  JMeq (proj_reptype_structlist i f ofs v) (proj_reptype_structlist i f ofs0 v).
Proof.
  intros.
  revert ofs ofs0.
  induction f; intros.
  + reflexivity.
  + simpl.
    if_tac.
    - revert v; simpl; if_tac; reflexivity.
    - revert v; simpl; destruct (is_Fnil f) eqn:?; intros.
      * destruct f; inversion Heqb; reflexivity.
      * apply IHf.
Qed.

Lemma proj_reptype_structlist_fieldlist_app: forall f0 f id t v v0,
  fieldlist_no_replicate (fieldlist_app f0 f) = true ->
  field_type id f = Errors.OK t ->
  @reptype_suf f0 f v v0 ->
  JMeq (proj_reptype_structlist id (fieldlist_app f0 f) 0 v) (proj_reptype_structlist id f 0 v0).
Proof.
  intros.
  generalize 0 at 1 2.
  generalize 0.
  induction f0; intros.
  + simpl in v, H1 |- *.
    rewrite H1.
    apply proj_reptype_structlist_ofs.
  + simpl in H1 |- *.
    if_tac. (* whether id = i *)
    - pose proof (fieldlist_no_replicate_fact2 _ _ H id t0 t).
      simpl in H3.
      if_tac in H3; [| congruence].
      pose proof H3 eq_refl H0.
      inversion H5.
    - revert v H1; simpl.
      destruct (is_Fnil (fieldlist_app f0 f)) eqn:?; intros. (* whether fieldlist f0 f is Fnil *)
      * destruct (is_Fnil_fieldlist_app _ _ Heqb) as [_ ?].
        destruct f; [inversion H0 | inversion H3].
      * simpl in H.
        rewrite andb_true_iff in H.
        destruct H.
        apply IHf0; auto.
Qed.

Lemma proj_reptype_cons_hd_Fnil: forall i f0 i0 t0 a t id ids v vs v0,
  nested_legal_fieldlist t = true ->
  id = i0 ->
  nested_field_type2 t ids = Tstruct i (fieldlist_app f0 (Fcons i0 t0 Fnil)) a ->
  JMeq (proj_reptype t ids v) vs ->
  @reptype_suf f0 (Fcons i0 t0 Fnil) vs v0 ->
  JMeq (proj_reptype t (id :: ids) v) v0.
Proof.
  intros.
  simpl.
  rewrite nested_field_type2_cons.
  revert H2.
  generalize (proj_reptype t ids v) as v2.
  rewrite H1.
  intros.
  clear v.
  rewrite <- eq_rect_eq.
  pose proof nested_field_type2_nest_pred (eq_refl) _ ids H.
  rewrite H1 in H4.
  simpl in H4.
  apply andb_true_iff in H4; destruct H4 as [? _].
  simpl in v2, H2.
  apply JMeq_eq in H2.
  subst.
  erewrite proj_reptype_structlist_fieldlist_app; eauto.
  + simpl.
    if_tac; [reflexivity | congruence].
  + simpl;
    if_tac; [reflexivity | congruence].
Qed.

Lemma JMeq_fst: forall A B C D (x: A*B) (y: C*D), A = C -> B = D -> JMeq x y -> JMeq (fst x) (fst y).
Proof.
  intros.
  subst.
  apply JMeq_eq in H1.
  subst.
  reflexivity.
Qed.

Lemma JMeq_snd: forall A B C D (x: A*B) (y: C*D), A = C -> B = D -> JMeq x y -> JMeq (snd x) (snd y).
Proof.
  intros.
  subst.
  apply JMeq_eq in H1.
  subst.
  reflexivity.
Qed.

Lemma proj_reptype_cons_hd_Fcons: forall i f0 i0 t0 i1 t1 f a t id ids v vs v0,
  nested_legal_fieldlist t = true ->
  id = i0 ->
  nested_field_type2 t ids = Tstruct i (fieldlist_app f0 (Fcons i0 t0 (Fcons i1 t1 f))) a ->
  JMeq (proj_reptype t ids v) vs ->
  @reptype_suf f0 (Fcons i0 t0 (Fcons i1 t1 f)) vs v0 ->
  JMeq (proj_reptype t (id :: ids) v) (fst v0).
Proof.
  intros.
  simpl.
  rewrite nested_field_type2_cons.
  revert H2.
  generalize (proj_reptype t ids v) as v2.
  rewrite H1.
  intros.
  clear v.
  rewrite <- eq_rect_eq.
  pose proof nested_field_type2_nest_pred (eq_refl) _ ids H.
  rewrite H1 in H4.
  simpl in H4.
  apply andb_true_iff in H4; destruct H4 as [? _].
  simpl in v2, H2.
  apply JMeq_eq in H2.
  subst.
  erewrite proj_reptype_structlist_fieldlist_app; eauto.
  + simpl.
    if_tac; [reflexivity | congruence].
  + simpl;
    if_tac; [reflexivity | congruence].
Qed.

Definition nested_sfieldlist_at_sub: forall sh t id ids i f a0 p t0,
  nested_legal_fieldlist t = true ->
  nested_field_type2 t ids = Tstruct i f a0 ->
  field_type id f = Errors.OK t0 ->
  exists P, forall v v0 v1,  
  JMeq (proj_reptype t ids v) v1 ->
  JMeq v0 v1 ->
  nested_sfieldlist_at sh t ids f v0 p = 
  field_at sh t (id :: ids) (proj_reptype t (id :: ids) v) p * P (proj_except_reptype_structlist f id v1).
Proof.
  intros.
  change f with (fieldlist_app Fnil f) in H0.
  cut (exists P : reptype_structlist (all_fields_except_one2 f id) -> mpred,
     forall (v : reptype t) (v0 : nested_reptype_structlist t ids f)
       (v1 : reptype_structlist f) (vs: reptype_structlist (fieldlist_app Fnil f)),
     JMeq (proj_reptype t ids v) vs ->
     reptype_suf vs v1 ->
     JMeq v0 v1 ->
     nested_sfieldlist_at sh t ids f v0 p =
     field_at sh t (id :: ids) (proj_reptype t (id :: ids) v) p *
     P (proj_except_reptype_structlist f id v1)).
  Focus 1. {
    intros.
    destruct H2 as [P ?]; exists P.
    intros.
    destruct (reptype_suf_Fnil v1).
    destruct H5.
    eapply H2 with (vs := x); eauto.
    rewrite H6.
    exact H3.
  } Unfocus.
  revert H0.
  generalize Fnil.
  induction f; intros.
  + inversion H1.
  + assert (fieldlist_no_replicate (fieldlist_app f0 (Fcons i0 t1 f)) = true).
    Focus 1. {
      pose proof nested_field_type2_nest_pred eq_refl _ ids H.
      rewrite H0 in H2.
      simpl in H2.
      apply andb_true_iff in H2.
      tauto.
    } Unfocus.
    assert (reptype (nested_field_type2 t (i0 :: ids)) = reptype t1)
      by (erewrite nested_field_type2_mid; eauto).
    assert (nested_reptype_structlist t ids f = reptype_structlist f).
    Focus 1. {
      unfold nested_field_type2 in H0.
      destruct (nested_field_rec t ids) as [[? t3]|] eqn:Heqo; try inversion H0.
      subst t3.
      rewrite fieldlist_app_Fcons in Heqo.
      eapply eq_sym, nested_reptype_structlist_lemma; eauto.
    } Unfocus.
    simpl in H1.
    if_tac in H1. (* whether id = the ident of head field *)
    - clear IHf. 
      simpl nested_sfieldlist_at.
Opaque field_at proj_reptype spacer nested_sfieldlist_at.
      destruct f; simpl;
      (if_tac; [| congruence]);
      eexists; intros;
      rewrite withspacer_spacer; simpl.
Transparent field_at proj_reptype spacer nested_sfieldlist_at.
      * pose proof proj_reptype_cons_hd_Fnil i f0 i0 t1 a0 t id ids v vs v1 H H5 H0 H7 H8.
        subst.
        simpl in H10, H9.
        rewrite <- H10 in H9.
        apply JMeq_eq in H9.
        rewrite H9.
        rewrite sepcon_comm.
        match goal with
        | |- _ * ?T = _ => instantiate (1:= fun _ => T)
        end.
        eauto.
      * rewrite sepcon_comm with (Q := field_at sh t (i0 :: ids) (fst v0) p).
        rewrite sepcon_assoc.
        
        f_equal.
        Focus 1. {
          pose proof proj_reptype_cons_hd_Fcons i f0 i0 t1 i1 t2 f a0 t id ids v vs v1 H H5 H0 H7 H8.
          subst; f_equal.
          apply JMeq_eq.
          rewrite H10.
          apply JMeq_fst; eauto.
        } Unfocus.
        Focus 1. {
          match goal with
          | |- ?T * (?R _ _) = _ => instantiate (1:= fun v => T * R (eq_rect_r (fun T => T) v H4) p)
          end.
          simpl.
          f_equal. f_equal.
          apply JMeq_snd in H9; eauto.
          apply eq_sym, JMeq_eq.
          simpl in *; rewrite H9.
          apply (eq_rect_JMeq _ _ _ (fun y => y) (snd v1) (eq_sym H4)).
        } Unfocus.
    - destruct f; try (solve [inversion H1]).
      rewrite fieldlist_app_Fcons in H0.
      destruct (IHf H1 (fieldlist_app f0 (Fcons i0 t1 Fnil)) H0) as [PH IH]; clear IHf.
      cut (exists P : 
            (if is_Fnil (all_fields_except_one2 (Fcons i1 t2 f) id) 
             then reptype t1
             else reptype t1 * reptype_structlist (all_fields_except_one2 (Fcons i1 t2 f) id))
             -> mpred,
             forall (v : reptype t)
             (v0 : nested_reptype_structlist t ids (Fcons i0 t1 (Fcons i1 t2 f)))
             (v1 : reptype_structlist (Fcons i0 t1 (Fcons i1 t2 f)))
             (vs : reptype_structlist
                     (fieldlist_app f0 (Fcons i0 t1 (Fcons i1 t2 f)))),
             JMeq (proj_reptype t ids v) vs ->
             reptype_suf vs v1 ->
             JMeq v0 v1 ->
             nested_sfieldlist_at sh t ids (Fcons i0 t1 (Fcons i1 t2 f)) v0 p =
             field_at sh t (id :: ids) (proj_reptype t (id :: ids) v) p *
             P (if is_Fnil (all_fields_except_one2 (Fcons i1 t2 f) id) as b
                  return if b 
                         then reptype t1
                         else reptype t1 * reptype_structlist 
                              (all_fields_except_one2 (Fcons i1 t2 f) id)
                then fst v1
                else (fst v1, proj_except_reptype_structlist (Fcons i1 t2 f) id (snd v1)))).
      Focus 1. {
        intros.
        destruct H6 as [P ?]. 
        simpl (all_fields_except_one2 (Fcons i0 t1 (Fcons i1 t2 f)) id).
        simpl proj_except_reptype_structlist.
        if_tac; [congruence | exists P; intros].
        eapply H6; eauto.
      } Unfocus.
      assert (forall (v0 : nested_reptype_structlist t ids (Fcons i0 t1 (Fcons i1 t2 f)))
       (v1 : reptype_structlist (Fcons i0 t1 (Fcons i1 t2 f))),
        JMeq v0 v1 -> (JMeq (fst v0) (fst v1) /\ JMeq (snd v0) (snd v1))) by
        (intros; split; [apply JMeq_fst | apply JMeq_snd]; eauto).
      
Opaque field_at proj_reptype spacer nested_sfieldlist_at proj_except_reptype_structlist.
      destruct (is_Fnil (all_fields_except_one2 (Fcons i1 t2 f) id)) eqn:HH; eexists; intros;
      replace (nested_sfieldlist_at sh t ids (Fcons i0 t1 (Fcons i1 t2 f)) v0 p) with
             ((withspacer sh
          (nested_field_offset2 t (i0 :: ids) +
           sizeof (nested_field_type2 t (i0 :: ids)))
          (align
             (nested_field_offset2 t (i0 :: ids) +
              sizeof (nested_field_type2 t (i0 :: ids))) 
             (alignof_hd (Fcons i1 t2 f))) (field_at sh t (i0 :: ids) (fst v0)) p *
          nested_sfieldlist_at sh t ids (Fcons i1 t2 f) (snd v0) p)) by reflexivity;
      rewrite withspacer_spacer; simpl.
Transparent field_at proj_reptype spacer nested_sfieldlist_at proj_except_reptype_structlist.
      * destruct (reptype_suf_Fcons f0 i0 t1 i1 t2 f vs v1 H8) as [v2 [? ?]].
        assert (nested_sfieldlist_at sh t ids (Fcons i1 t2 f) (snd v0) p =
                field_at sh t (id :: ids) (proj_reptype t (id :: ids) v) p *
                PH (proj_except_reptype_structlist (Fcons i1 t2 f) id (snd v1))).
        Focus 1. {
          apply (IH v (snd v0) (snd v1) v2); eauto.
          + rewrite <- H10. exact H7.
          + apply JMeq_snd; eauto.
        } Unfocus.
        rewrite H12; clear H12 IH.
        destruct (H6 v0 v1 H9).
        match goal with
        | |- ?A2 * (?A1 _ _) * (_ * _) = _ => 
          instantiate (1:= fun v => A2 * A1 (eq_rect_r (fun T => T) v H3) p * (PH (struct_default_val _)))
        end.
        assert (all_fields_except_one2 (Fcons i1 t2 f) id = Fnil) by
          (destruct (all_fields_except_one2 (Fcons i1 t2 f) id); [trivial | inversion HH]).
        forget (proj_except_reptype_structlist (Fcons i1 t2 f) id (snd v1)) as tt'.
        forget (struct_default_val (all_fields_except_one2 (Fcons i1 t2 f) id)) as tt''.
        revert tt' tt'' PH.
        rewrite H14; intros.
        normalize.
        destruct tt', tt''.
        f_equal.
        rewrite sepcon_comm, <- sepcon_assoc.
        f_equal.
        f_equal.
        apply eq_sym, JMeq_eq.
        simpl in *; rewrite H12.
        erewrite eq_rect_JMeq with (F := fun T => T).
        reflexivity.
      * destruct (reptype_suf_Fcons f0 i0 t1 i1 t2 f vs v1 H8) as [v2 [? ?]].
        assert (nested_sfieldlist_at sh t ids (Fcons i1 t2 f) (snd v0) p =
                field_at sh t (id :: ids) (proj_reptype t (id :: ids) v) p *
                PH (proj_except_reptype_structlist (Fcons i1 t2 f) id (snd v1))).
        Focus 1. {
          apply (IH v (snd v0) (snd v1) v2); eauto.
          + rewrite <- H10. exact H7.
          + apply JMeq_snd; eauto.
        } Unfocus.
        rewrite H12; clear H12 IH.
        destruct (H6 v0 v1 H9).
        match goal with
        | |- ?A2 * (?A1 _ _) * (_ * _) = _ => 
          instantiate (1:= fun v => A2 * A1 (eq_rect_r (fun T => T) (fst v) H3) p * PH (snd v))
        end.
        normalize.
        f_equal.
        rewrite sepcon_comm, <- sepcon_assoc.
        f_equal.
        f_equal.
        apply eq_sym, JMeq_eq.
        simpl in *; rewrite H12.
        erewrite eq_rect_JMeq with (F := fun T => T).
        reflexivity.
Qed.

(*
Definition nested_field_sub_aux: forall sh t id ids p, 
  nested_legal_fieldlist t = true ->
  legal_alignas_type t = true ->
  isSome (nested_field_type t (id :: ids)) ->
  exists P, forall v, data_at sh t v p = field_at sh t (id :: ids) (proj_reptype t (id :: ids) v) p *
    P (proj_except_reptype t id ids v).
Proof.
  intros.
  induction ids.
  + destruct t; try inversion H1.
    - (* Tstruct *)
Opaque proj_reptype.
      simpl.
Transparent proj_reptype.
      unfold nested_field_type in H1; simpl in H1.
      solve_field_offset_type id f; [clear H1 | inversion H1].
      destruct (nested_sfieldlist_at_sub sh (Tstruct i f a) id nil i f a p t H eq_refl H3) as [P0 ?].
      exists P0; intros.
      rewrite data_at_field_at.
      erewrite field_at_Tstruct with (f := f); [| destruct f; [inversion H3 | reflexivity] | reflexivity | exact H |  | exact H0].
      SearchAbout field_at nested_sfieldlist_at.
    rewrite sepcon_emp.
    rewrite data_at_field_at.
    simpl.
    unfold eq_rect_r.
    rewrite <- eq_rect_eq.
    reflexivity.
  + unfold nested_field_type in *; simpl in H1.
    destruct (nested_field_rec t ids) as [[ofs0 t0] |] eqn:?; try inversion H1.
    destruct t0; try inversion H1.
    - solve_field_offset_type a f; inversion H1.
      destruct (IHids I) as [P ?].
      rewrite H2.
      assert (nested_field_type2 t ids = Tstruct i f a0) 
        by (unfold nested_field_type2; rewrite Heqo; reflexivity).

      erewrite field_at_Tstruct with (ids := ids); eauto.
  

      simpl proj_reptype.
      generalize (@eq_refl type (nested_field_type2 t ids)) as EQ.
Set Printing All.
      pattern (nested_field_type2 t ids) at 2 3.
      rewrite H5 at 1.
Check nested_sfieldlist_at.
SearchAbout nested_reptype_structlist.



Lemma semax_nested_efield_load_37':
  forall {Espec: OracleKind},
    forall Delta sh e id P Q R (e1: expr)
      (t : type) (ids: list ident) (tts: list type)
      (v : val) (v' : reptype (nested_field_type2 (typeof e1) ids)),
      typeof_temp Delta id = Some t ->
      uncompomize e (nested_field_type2 (typeof e1) ids) = typeof (nested_efield e1 ids tts) ->
      is_neutral_cast (typeof (nested_efield e1 ids tts)) t = true ->
      legal_alignas_type (typeof e1) = true ->
      legal_nested_efield e (typeof e1) ids tts = true ->
      JMeq v' v ->
      PROPx P (LOCALx (tc_environ Delta :: Q) (SEPx R)) |--
        local (tc_lvalue Delta (nested_efield e1 ids tts)) &&
        local `(tc_val (typeof (nested_efield e1 ids tts)) v) &&
        (`(field_at sh (typeof e1) ids v') (eval_lvalue e1) * TT) ->
      semax Delta (|>PROPx P (LOCALx Q (SEPx R))) 
        (Sset id (nested_efield e1 ids tts))
          (normal_ret_assert
            (EX old : val,
              PROPx P
                (LOCALx (`(eq v) (eval_id id) :: map (subst id `old) Q)
                  (SEPx (map (subst id `old) R))))).
Proof.
*)



















































