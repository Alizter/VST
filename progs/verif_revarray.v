Require Import floyd.proofauto.
Require Import progs.revarray.
Require Import floyd.sublist.

Local Open Scope logic.

Instance CompSpecs : compspecs := compspecs_program prog.
Instance CS_legal : compspecs_legal CompSpecs.
Proof. prove_CS_legal. Qed.

Definition reverse_spec :=
 DECLARE _reverse
  WITH a0: val, sh : share, contents : list int, size: Z
  PRE [ _a OF (tptr tint), _n OF tint ]
          PROP (0 <= size <= Int.max_signed; writable_share sh)
          LOCAL (temp _a a0; temp _n (Vint (Int.repr size)))
          SEP (`(data_at sh (tarray tint size) (map Vint contents) a0))
  POST [ tvoid ]
     PROP() LOCAL()
     SEP(`(data_at sh (tarray tint size) (map Vint (rev contents)) a0)).

Definition main_spec :=
 DECLARE _main
  WITH u : unit
  PRE  [] main_pre prog u
  POST [ tint ] main_post prog u.

Definition Vprog : varspecs := (_four, Tarray tint 4 noattr)::nil.

Definition Gprog : funspecs := 
    reverse_spec :: main_spec::nil.

Definition flip_between {A} lo hi (contents: list A) :=
  firstn (Z.to_nat lo) (rev contents) 
  ++ firstn (Z.to_nat (hi-lo)) (skipn (Z.to_nat lo) contents)
  ++ skipn (Z.to_nat hi) (rev contents).

Definition reverse_Inv a0 sh contents size := 
 EX j:Z,
  (PROP  (0 <= j; j <= size-j)
   LOCAL  (temp _a a0; temp _lo (Vint (Int.repr j)); temp _hi (Vint (Int.repr (size-j))))
   SEP (`(data_at sh (tarray tint size) (flip_between j (size-j) contents) a0))).

Lemma flip_fact_0: forall A size (contents: list A),
  Zlength contents = size ->
  contents = flip_between 0 (size - 0) contents.
Proof.
  intros.
  assert (length contents = Z.to_nat size).
    apply Nat2Z.inj. rewrite <- Zlength_correct, Z2Nat.id; auto.
    subst; rewrite Zlength_correct; omega.
  unfold flip_between.
  rewrite !Z.sub_0_r. change (Z.to_nat 0) with O; simpl. rewrite <- H0.
  rewrite skipn_short.
  rewrite <- app_nil_end.
  rewrite firstn_exact_length. auto.
  rewrite rev_length. omega.
Qed.

Lemma flip_fact_1: forall A size (contents: list A) j,
  Zlength contents = size ->
  0 <= j ->
  size - j - 1 <= j <= size - j ->
  flip_between j (size - j) contents = rev contents.
Proof.
  intros.
  assert (length contents = Z.to_nat size).
    apply Nat2Z.inj. rewrite <- Zlength_correct, Z2Nat.id; auto.
    subst; rewrite Zlength_correct; omega.
  unfold flip_between.
  symmetry.
  rewrite <- (firstn_skipn (Z.to_nat j)) at 1.
  f_equal.
  replace (Z.to_nat (size-j)) with (Z.to_nat j + Z.to_nat (size-j-j))%nat
    by (rewrite <- Z2Nat.inj_add by omega; f_equal; omega).
  rewrite <- skipn_skipn.
  rewrite <- (firstn_skipn (Z.to_nat (size-j-j)) (skipn (Z.to_nat j) (rev contents))) at 1.
  f_equal.
  rewrite firstn_skipn_rev.
Focus 2.
rewrite H2.
apply Nat2Z.inj_le.
rewrite Nat2Z.inj_add by omega.
rewrite !Z2Nat.id by omega.
omega.
  rewrite len_le_1_rev.
  f_equal. f_equal. f_equal.
  rewrite <- Z2Nat.inj_add by omega. rewrite H2.
  rewrite <- Z2Nat.inj_sub by omega. f_equal; omega.
  rewrite firstn_length, min_l. 
  change 1%nat with (Z.to_nat 1). apply Z2Nat.inj_le; omega.
  rewrite skipn_length.  rewrite H2.
  rewrite <- Z2Nat.inj_sub by omega. apply Z2Nat.inj_le; omega.
Qed.

Lemma Zlength_flip_between:
 forall A i j (al: list A),
 0 <= i  -> i<=j -> j <= Zlength al ->
 Zlength (flip_between i j al) = Zlength al.
Proof.
intros.
unfold flip_between.
rewrite !Zlength_app, !Zlength_firstn, !Zlength_skipn, !Zlength_rev.
forget (Zlength al) as n.
rewrite (Z.max_comm 0 i).
rewrite (Z.max_l i 0) by omega.
rewrite (Z.max_comm 0 j).
rewrite (Z.max_l j 0) by omega.
rewrite (Z.max_comm 0 (j-i)).
rewrite (Z.max_l (j-i) 0) by omega.
rewrite (Z.max_comm 0 (n-i)).
rewrite (Z.max_l (n-i) 0) by omega.
rewrite Z.max_r by omega.
rewrite (Z.min_l i n) by omega.
rewrite Z.min_l by omega.
omega.
Qed.

Lemma flip_fact_3:
 forall A (al: list A) (d: A) j size,
  size = Zlength al ->
  0 <= j < size - j - 1 ->
firstn (Z.to_nat j)
  (firstn (Z.to_nat (size - j - 1)) (flip_between j (size - j) al) ++
   firstn (Z.to_nat 1) (skipn (Z.to_nat j) (flip_between j (size - j) al)) ++
   skipn (Z.to_nat (size - j - 1 + 1)) (flip_between j (size - j) al)) ++
firstn (Z.to_nat 1)
  (skipn (Z.to_nat (size - j - 1)) al) ++
skipn (Z.to_nat (j + 1))
  (firstn (Z.to_nat (size - j - 1)) (flip_between j (size - j) al) ++
   firstn (Z.to_nat 1) (skipn (Z.to_nat j) (flip_between j (size - j) al)) ++
   skipn (Z.to_nat (size - j - 1 + 1)) (flip_between j (size - j) al)) =
flip_between (Z.succ j) (size - Z.succ j) al.
Proof.
intros.
assert (Zlength (rev al) = size) by (rewrite Zlength_rev; omega).
unfold flip_between.
rewrite Zfirstn_app1.
Focus 2. {
rewrite Zlength_firstn, Z.max_r by omega.
rewrite !Zlength_app.
rewrite Zlength_firstn, Z.max_r by omega.
rewrite Zlength_firstn, Z.max_r by omega.
rewrite !Zlength_skipn.
rewrite (Z.max_r 0 j) by omega.
rewrite (Z.max_r 0 (size-j)) by omega.
rewrite Z.max_r by omega.
rewrite Z.max_r by omega.
rewrite (Z.min_l j) by omega.
rewrite (Z.min_l (size-j-j)) by omega.
rewrite Z.min_l by omega.
omega.
} Unfocus.
rewrite Zfirstn_app2
 by (rewrite Zlength_firstn, Z.max_r by omega;
      rewrite Z.min_l by omega; omega).
rewrite Zfirstn_app1
 by (rewrite Zlength_firstn, Z.max_r by omega;
      rewrite Z.min_l by omega; omega).
rewrite Zfirstn_firstn by omega.
rewrite Zskipn_app1.
Focus 2. {
rewrite Zlength_firstn, Z.max_r by omega.
rewrite Zlength_rev. 
rewrite !Zlength_app.
rewrite Zlength_firstn, Z.max_r by omega.
rewrite Z.min_l by omega.
rewrite Zlength_firstn.
rewrite (Z.min_l j (Zlength al)) by omega.
rewrite Z.max_r by omega.
rewrite Zlength_app.
rewrite Zlength_firstn, Z.max_r by omega.
rewrite Zlength_skipn.
rewrite (Z.max_r 0 j)  by omega.
rewrite (Z.max_r 0 ) by omega.
rewrite (Z.min_l  (size-j-j)) by omega.
rewrite Zlength_skipn.
rewrite (Z.max_r 0 (size-j)) by omega.
rewrite Z.max_r by omega.
rewrite Z.min_l by omega.
omega.
} Unfocus.
rewrite Zskipn_app2
 by (rewrite Zlength_firstn, Z.max_r by omega;
       rewrite Z.min_l by omega; omega).
rewrite Zlength_firstn, Z.max_r by omega.
rewrite Z.min_l by omega.
rewrite Zfirstn_app1.
Focus 2. {
rewrite Zlength_firstn, Z.max_r by omega.
rewrite Zlength_skipn, (Z.max_r 0 j) by omega.
rewrite Z.max_r by omega.
rewrite Z.min_l by omega. omega.
} Unfocus.
rewrite Zfirstn_firstn by omega.
rewrite Zskipn_app2
 by (rewrite Zlength_firstn, Z.max_r by omega;
       rewrite Z.min_l by omega; omega).
rewrite Zskipn_app1.
Focus 2. {
rewrite Zlength_firstn, Z.max_r by omega.
rewrite Z.min_l by omega.
rewrite Zlength_firstn, Z.max_r by omega.
rewrite Zlength_skipn, (Z.max_r 0 j) by omega.
rewrite Z.max_r by omega.
rewrite Z.min_l by omega. omega.
} Unfocus.
rewrite Zfirstn_app1.
Focus 2. {
rewrite !Zlength_skipn, !Zlength_firstn.
rewrite (Z.max_r 0 j) by omega.
rewrite (Z.min_l j) by omega.
rewrite Zlength_skipn.
rewrite (Z.max_r 0 j) by omega.
rewrite (Z.max_r 0 (Zlength al - j)) by omega.
rewrite (Z.max_l 0 (j-j)) by omega.
rewrite (Z.max_r 0 (size-j-j)) by omega.
rewrite Z.min_l by omega.
rewrite Z.max_r by omega.
omega.
} Unfocus.
rewrite Zskipn_app2.
Focus 2. {
rewrite Zlength_firstn, Z.max_r by omega.
rewrite (Z.min_l j) by omega.
omega.
} Unfocus.
rewrite Zskipn_app2.
Focus 2. {
rewrite Zlength_firstn, Z.max_r by omega.
rewrite (Z.min_l j) by omega.
rewrite Zlength_firstn, Z.max_r by omega.
rewrite Zlength_skipn, (Z.max_r 0 j) by omega.
rewrite Z.max_r by omega.
rewrite Z.min_l by omega.
omega.
} Unfocus.
rewrite Zlength_firstn, Z.max_r by omega.
rewrite Zlength_firstn, Z.max_r by omega.
rewrite Zlength_skipn, (Z.max_r 0 j) by omega.
rewrite Z.max_r by omega.
rewrite Z.min_l by omega.
rewrite Z.min_l by omega.
rewrite Zskipn_skipn by omega.
rewrite !Zskipn_firstn by omega.
rewrite !Z.sub_diag.
rewrite Z.sub_0_r.
rewrite !Zskipn_skipn by omega.
rewrite Zfirstn_firstn by omega.
rewrite <- app_ass.
f_equal.
rewrite <- (firstn_skipn (Z.to_nat j) (rev al)) at 2.
rewrite Zfirstn_app2
  by (rewrite Zlength_firstn, Z.max_r by omega;
        rewrite Z.min_l by omega; omega).
rewrite Zlength_firstn, Z.max_r by omega;
rewrite Z.min_l by omega.
replace (Z.succ j - j) with 1 by omega.
f_equal.
rewrite app_nil_end.
rewrite app_nil_end at 1.
rewrite <- Znth_cons with (d0:=d) by omega.
rewrite <- Znth_cons with (d0:=d) by omega.
f_equal.
rewrite Znth_rev by omega.
f_equal. omega.
replace (size - j - 1 - j - (j + 1 - j))
  with (size- Z.succ j- Z.succ j) by omega.
replace (j+(j+1-j)) with (j+1) by omega.
f_equal.
rewrite Z.add_0_r.
rewrite <- (firstn_skipn (Z.to_nat 1) (skipn (Z.to_nat (size- Z.succ j)) (rev al))).
rewrite Zskipn_skipn by omega.
f_equal.
rewrite app_nil_end.
rewrite app_nil_end at 1.
rewrite <- Znth_cons with (d0:=d) by omega.
rewrite <- Znth_cons with (d0:=d) by omega.
f_equal.
rewrite Znth_rev by omega.
f_equal.
omega.
f_equal.
f_equal.
omega.
Qed.

Lemma flip_between_map:
  forall A B (F: A -> B) lo hi (al: list A),
   0 <= lo -> lo <= hi -> hi <= Zlength al ->
  flip_between lo hi (map F al) = map F (flip_between lo hi al).
Proof.
intros.
unfold flip_between.
rewrite !map_app.
rewrite !map_firstn, !map_skipn, !map_rev.
auto.
Qed.

Lemma flip_fact_2:
  forall {A} (al: list A) size j d,
 Zlength al = size ->
  j < size - j - 1 ->
   0 <= j ->
  Znth (size - j - 1) al d =
  Znth (size - j - 1) (flip_between j (size - j) al) d.
Proof.
intros.
unfold flip_between.
rewrite app_Znth2
 by (rewrite Zlength_firstn, Z.max_r by omega;
      rewrite Zlength_rev, Z.min_l by omega; omega).
rewrite Zlength_firstn, Z.max_r by omega;
rewrite Zlength_rev, Z.min_l by omega.
rewrite app_Znth1.
Focus 2. {
rewrite Zlength_firstn, Z.max_r by omega;
rewrite Zlength_skipn by omega.
rewrite (Z.max_r 0 j) by omega.
rewrite Z.max_r by omega.
rewrite Z.min_l by omega.
omega. } Unfocus.
rewrite Znth_firstn by omega.
rewrite Znth_skipn by omega.
f_equal; omega.
Qed.

Lemma body_reverse: semax_body Vprog Gprog f_reverse reverse_spec.
Proof.
start_function.
name a _a.
name n _n.
name lo' _lo.
name hi' _hi.
name s _s.
name t _t.

forward.  (* lo = 0; *)
forward _. (* hi = n; *)

assert_PROP (Zlength (map Vint contents) = size).
 entailer.
rename H0 into ZL.
forward_while (reverse_Inv a0 sh (map Vint contents) size)
    (PROP  () LOCAL  (temp _a a0)
   SEP (`(data_at sh (tarray tint size) (map Vint (rev contents)) a0)))
   j.
(* Prove that current precondition implies loop invariant *)
apply exp_right with 0.
entailer!; try omega.
f_equal; omega.
apply derives_refl'.
f_equal.
apply flip_fact_0; auto.
(* Prove that loop invariant implies typechecking condition *)
entailer!.
(* Prove that invariant && not loop-cond implies postcondition *)
entailer!.
apply derives_refl'.
f_equal.
rewrite map_rev. apply flip_fact_1; try omega. auto.
(* Prove that loop body preserves invariant *)
forward. (* t = a[lo]; *)
{
  entailer!.
  clear - H0 H HRE H1.
  rewrite Zlength_map in *.
  rewrite flip_between_map by omega.
  rewrite Znth_map with (d':=Int.zero).
  apply I.
  rewrite Zlength_flip_between by omega.
  omega.
}
forward.  (* s = a[hi-1]; *)
{
  entailer!.
  clear - H0 HRE H1.
  rewrite Zlength_map in *.
  rewrite flip_between_map by omega.
  rewrite Znth_map with (d':=Int.zero).
  apply I.
  rewrite Zlength_flip_between by omega.
  omega.
}
rewrite <- flip_fact_2 by (rewrite ?Zlength_flip_between; omega).
forward. (*  a[hi-1] = t; *)
forward. (* a[lo] = s; *)
forward lo'0. (* lo++; *)
forward hi'0. (* hi--; *)
(* Prove postcondition of loop body implies loop invariant *)
{
  apply exp_right with (Zsucc j).
 entailer. rewrite prop_true_andp by (f_equal; omega).
 apply derives_refl'. clear H7 H6.
 rewrite H5,H4; simpl. rewrite <- H5, <- H4. clear H5 H4 TC.
 unfold data_at.    f_equal.
 clear - H0 H HRE H1.
 remember (Zlength (map Vint contents)) as size.
 forget (map Vint contents) as al.
 repeat match goal with |- context [reptype ?t] => change (reptype t) with val end.
 rewrite !Znth_cons by (repeat rewrite Zlength_flip_between; try omega).
 apply flip_fact_3; auto.
 apply Vundef.
}
forward. (* return; *)
Qed.

Definition four_contents := [Int.repr 1; Int.repr 2; Int.repr 3; Int.repr 4].

Lemma forall_Forall: forall A (P: A -> Prop) xs d,
  (forall x, In x xs -> P x) ->
  forall i, 0 <= i < Zlength xs -> P (Znth i xs d).
Proof.
  intros.
  unfold Znth.
  if_tac; [omega |].
  assert (Z.to_nat i < length xs)%nat.
  Focus 1. {
    rewrite Zlength_correct in H0.
    destruct H0 as [_ ?].
    apply Z2Nat.inj_lt in H0; [| omega | omega].
    rewrite Nat2Z.id in H0.
    exact H0.
  } Unfocus.
  forget (Z.to_nat i) as n.
  clear i H0 H1.
  revert n H2; induction xs; intros.
  + destruct n; simpl in H2; omega.
  + destruct n.
    - specialize (H a (or_introl eq_refl)).
      simpl.
      tauto.
    - simpl in *.
      apply IHxs; [| omega].
      intros.
      apply H.
      tauto.
Qed.

Lemma body_main:  semax_body Vprog Gprog f_main main_spec.
Proof.
start_function.
normalize; intro a; normalize.

forward_call'  (*  revarray(four,4); *)
  (a, Ews, four_contents, 4).
   repeat split; try computable; auto.
forward_call'  (*  revarray(four,4); *)
    (a,Ews, rev four_contents,4).
   split. computable. auto.
rewrite rev_involutive.
forward. (* return s; *)
Qed.

Existing Instance NullExtension.Espec.

Lemma all_funcs_correct:
  semax_func Vprog Gprog (prog_funct prog) Gprog.
Proof.
unfold Gprog, prog, prog_funct; simpl.
semax_func_skipn.
semax_func_cons body_reverse.
semax_func_cons body_main.
apply semax_func_nil.
Qed.

