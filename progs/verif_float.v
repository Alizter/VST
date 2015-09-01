Require Import floyd.proofauto.
Require Import progs.float.
Instance CompSpecs : compspecs := compspecs_program prog.
Instance CS_legal : compspecs_legal CompSpecs.
Proof. prove_CS_legal. Qed.

Local Open Scope logic.

Definition main_spec :=
 DECLARE _main
  WITH u : unit
  PRE  [] main_pre prog u
  POST [ tint ] main_post prog u.

Definition t_struct_foo := Tstruct _foo noattr.

Definition Vprog : varspecs := (_s, t_struct_foo)::nil.

Definition Gprog : funspecs := 
     main_spec::nil.

Lemma gvar_size_compatible:
  forall i s rho t, 
    gvar i s rho -> 
    sizeof cenv_cs t <= Int.modulus ->
    size_compatible t s.
Proof.
intros.
hnf in H. destruct (Map.get (ve_of rho) i) as [[? ? ] | ]; try contradiction.
destruct (ge_of rho i); try contradiction.
subst s.
simpl; auto.
Qed.


Lemma gvar_align_compatible:
  forall i s rho t, 
    gvar i s rho -> 
    align_compatible t s.
Proof.
intros.
hnf in H. destruct (Map.get (ve_of rho) i) as [[? ? ] | ]; try contradiction.
destruct (ge_of rho i); try contradiction.
subst s.
simpl; auto.
exists 0. reflexivity.
Qed.

Lemma body_main:  semax_body Vprog Gprog f_main main_spec.
Proof.
name x1 _x1.
name y1 _y1.
name y2 _y2.
name s _s.
start_function.
apply semax_pre with
 (PROP  ()
   LOCAL  (gvar _s s)
   SEP 
   (`(data_at Ews t_struct_foo (Vint (Int.repr 5), 
          (Vsingle (Float32.of_bits (Int.repr 1079655793)),
           Vfloat (Float.of_bits (Int64.repr 0)))) s))). {
unfold data_at.
 unfold_field_at 1%nat.
entailer!.
rewrite proj_sumbool_is_true by auto;
rewrite value_fits_ind; split3; 
 erewrite unfold_reptype_elim by reflexivity;
 simpl; hnf; simpl; auto.
unfold field_at, data_at', at_offset. simpl.
unfold mapsto'; rewrite !if_true by auto.
rewrite proj_sumbool_is_true by auto.
repeat rewrite prop_true_andp by
 (split; [(split3; [ | | split3; [ | | split3; [ | | split]]]; auto; try reflexivity; try apply I;
   try (eapply gvar_size_compatible; eauto; simpl; computable);
   try (eapply gvar_align_compatible; eauto);
   solve [compute; auto])
  | intro; apply I
  ]).
fold tint; fold tfloat; fold tdouble.
repeat match goal with |- context [field_offset ?A ?B ?C] =>
  set (aa :=field_offset A B C); compute in aa; subst aa
end.
normalize.
cancel.
}
forward.
forward.
forward.
forward y1_old.
forward.
Qed.
