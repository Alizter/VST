Require Import floyd.proofauto.
Import ListNotations.
Require sha.sha.
Require Import sha.SHA256.
Local Open Scope logic.

Require Import sha.spec_sha.
Require Import sha_lemmas.
Require Import sha.HMAC_functional_prog.

Require Import sha.hmac091c.

Require Import sha.spec_hmac.
Require Import vst_lemmas.
Require Import hmac_pure_lemmas.
Require Import hmac_common_lemmas.

Lemma body_hmac_double: semax_body HmacVarSpecs HmacFunSpecs 
      f_HMAC2 HMAC_Double_spec.
Proof.
start_function.
name key' _key.
name keylen' _key_len.
name d' _d.
name n' _n.
name md' _md.
simpl_stackframe_of.
rename keyVal into k. rename msgVal into d.
destruct KEY as [kl key].
destruct MSG as [dl data]. simpl in *.
rename H into WrshMD. 
rewrite memory_block_isptr. normalize.
rename H into isPtrMD. rename H0 into KL. rename H1 into DL. 
forward_if (EX c:_,
   PROP  (isptr c)
   LOCAL  (`(eq md) (eval_id _md); `(eq k) (eval_id _key);
   `(eq (Vint (Int.repr kl))) (eval_id _key_len); `(eq d) (eval_id _d);
   `(eq (Vint (Int.repr dl))) (eval_id _n);
   `(eq c) (eval_var _c t_struct_hmac_ctx_st);
   `(eq KV) (eval_var sha._K256 (tarray tuint 64)))
   SEP 
   (`(data_at_ Tsh t_struct_hmac_ctx_st c);
   `(data_block Tsh key k); `(data_block Tsh data d); `(K_vector KV);
   `(memory_block shmd (Int.repr 64) md))).
  { apply isptrD in isPtrMD. destruct isPtrMD as [b [i HH]]; rewrite HH in *; clear HH.
    forward; entailer.
  }
  { forward. entailer.
    rewrite data_at__isptr.
    apply exp_right with (x:=eval_var _c t_struct_hmac_ctx_st rho).
    entailer.
  }
apply extract_exists_pre. intros c. normalize. rename H into isPtrC. 
eapply semax_seq'.
myframe_SEP'' (0::1::3::nil).
remember (HMACabs init_s256abs init_s256abs init_s256abs Z0 nil) as dummyHMA.
remember (c, k, kl, key, KV, dummyHMA) as WITNESS.
forward_call WITNESS.
  assert (FR: Frame = nil).
       subst Frame. reflexivity.
     rewrite FR. clear FR Frame. 
  subst WITNESS. entailer. cancel. unfold initPre. 
   apply isptrD in Pkey'. destruct Pkey' as [kb [kofs HK]]. subst key'.
   cancel.
after_call.
subst WITNESS. normalize. simpl.

eapply semax_pre with (P':=EX  h : hmacabs,
  (PROP  (hmacInit key h)
   LOCAL  (tc_environ Delta; `(eq md) (eval_id _md); `(eq k) (eval_id _key);
   `(eq (Vint (Int.repr kl))) (eval_id _key_len); `(eq d) (eval_id _d);
   `(eq (Vint (Int.repr dl))) (eval_id _n);
   `(eq c) (eval_var _c t_struct_hmac_ctx_st);
   `(eq KV) (eval_var sha._K256 (tarray tuint 64)))
   SEP 
   (`(hmacstate_ h c); `(initPostKey k key); `(K_vector KV);
    `(data_block Tsh data d);
    `(memory_block shmd (Int.repr 64) md)))).
  entailer. apply (exp_right h); entailer.
apply extract_exists_pre. intros h0. normalize; rename H into HmacInit.

eapply semax_seq'. 
myframe_SEP'' (0::2::3::nil). 
remember (h0, c, d, dl, data, KV) as WITNESS.
(*Remark on confusing error messages: if the spec of HMAC_update includes _len OF tuint
  instead of _len OF tint, the following forward_call fails, complaining that
  WITNESS is not of type hmacabs * val * val * Z * list Z * val. But it is, 
  and the error message is wrong.*)
forward_call WITNESS.
  assert (FR: Frame = nil).
       subst Frame. reflexivity.
     rewrite FR. clear FR Frame. 
  subst WITNESS. entailer.
  apply andp_right. 2: cancel.
    unfold hmacstate_. normalize. apply prop_right. 
    assert (HH: s256a_len (absCtxt h0) = 512).
    Focus 2. destruct DL as [DL1 [DL2 DL3]]. split; trivial. split; trivial.
             rewrite HH; assumption. 
    destruct h0; simpl in *. 
    destruct H1 as [reprMD [reprI [reprO [iShaLen [oShaLen [K [i [KL1 [KL2 KL3]]]]]]]]].
    inversion HmacInit; clear HmacInit.
    destruct H1 as [oS [InnSHA [OntSHA XX]]]. inversion XX; clear XX.
    subst. assumption.
after_call.
subst WITNESS. normalize.

normalize. simpl.
apply semax_pre with (P':=EX  x : hmacabs,
  (PROP  (hmacUpdate data h0 x)
   LOCAL  (tc_environ Delta; `(eq md) (eval_id _md);
   `(eq k) (eval_id _key); `(eq (Vint (Int.repr kl))) (eval_id _key_len);
   `(eq d) (eval_id _d); `(eq (Vint (Int.repr dl))) (eval_id _n);
   `(eq c) (eval_var _c t_struct_hmac_ctx_st);
   `(eq KV) (eval_var sha._K256 (tarray tuint 64)))
   SEP 
   (`(K_vector KV); `(hmacstate_ x c); `(data_block Tsh data d);
    `(initPostKey k key); `(memory_block shmd (Int.repr 64) md)))).
  entailer. apply (exp_right x). entailer.
apply extract_exists_pre. intros h1. normalize. rename H into HmacUpdate.

(*XXX: was: rewrite (split_memory_block 32). 2: omega. 2: trivial. simpl. 
normalize. rename H into OIR_0_md. rename H0 into OIR_64_md.
Look what we now need to do:*)
destruct md; try contradiction; clear isPtrMD.
assert (GTmod64: 64 < Int.modulus).
  rewrite <- initialize.max_unsigned_modulus, int_max_unsigned_eq. omega.
specialize (memory_block_size_compatible shmd (tarray tuint 16)). simpl; intros.
rewrite (H _ GTmod64); clear H.
normalize. unfold size_compatible in H. simpl in H; rename H into SizeCompat64.
specialize (memory_block_split shmd b (Int.unsigned i) 32 32); intros XX.
  rewrite Int.repr_unsigned in XX. 
  assert (32 + 32 = 64) by omega. rewrite H in XX; clear H.
  rewrite XX; clear XX.
2: omega. 2: trivial. 2: trivial. 
Focus 2. split; try omega. specialize (Int.unsigned_range i). omega.
normalize. (*GTmad64 and SizeCompat play the roles of the earlier OIR_0_md and OIR_64_md*)

eapply semax_seq'.
myframe_SEP'' [3; 2; 0].
remember (h1, c, Vptr b i, shmd, KV) as WITNESS. (*md=Vptr b i from now on*)
forward_call WITNESS.
  assert (FR: Frame = nil).
       subst Frame. reflexivity.
     rewrite FR. clear FR Frame. 
  subst WITNESS. entailer. 
after_call.
subst WITNESS. normalize.

normalize. simpl.

apply semax_pre with (P':=EX dig : list Z, EX  h2 : hmacabs,
  (PROP  (hmacFinal h1 dig h2)
   LOCAL  (tc_environ Delta; 
   `(eq (Vptr b i)) (eval_id _md); `(eq k) (eval_id _key);
   `(eq (Vint (Int.repr kl))) (eval_id _key_len); `(eq d) (eval_id _d);
   `(eq (Vint (Int.repr dl))) (eval_id _n);
   `(eq c) (eval_var _c t_struct_hmac_ctx_st);
   `(eq KV) (eval_var sha._K256 (tarray tuint 64)))
   SEP 
   (`(K_vector KV); `(hmacstate_PostFinal h2 c);
    `(data_block shmd dig (Vptr b i));
    `(memory_block shmd (Int.repr 32)
       (Vptr b (Int.repr (Int.unsigned i + 32)))); `(data_block Tsh data d);
    `(initPostKey k key)))).
  entailer.
   apply (exp_right x). apply (exp_right x0). entailer. 
apply extract_exists_pre; intros dig.
apply extract_exists_pre; intros h2.
normalize. rename H into Round1Final.

(**************Round 2*******************************)

apply semax_pre with (P':=
  (PROP  ()
   LOCAL  (tc_environ Delta; 
   `(eq (Vptr b i)) (eval_id _md); `(eq k) (eval_id _key);
   `(eq (Vint (Int.repr kl))) (eval_id _key_len); `(eq d) (eval_id _d);
   `(eq (Vint (Int.repr dl))) (eval_id _n);
   `(eq c) (eval_var _c t_struct_hmac_ctx_st);
   `(eq KV) (eval_var sha._K256 (tarray tuint 64)))
   SEP 
   (`(K_vector KV); `(initPre c nullval h2 key);
    `(data_block shmd dig (Vptr b i));
    `(memory_block shmd (Int.repr 32)
       (Vptr b (Int.repr (Int.unsigned i + 32)))); `(data_block Tsh data d);
    `(initPostKey k key)))).
  { entailer. cancel. eapply hmacstate_PostFinal_PreInitNull; eassumption.
  }

eapply semax_seq'. 
myframe_SEP'' [0; 1].
forward_call (c, nullval, kl, key, KV, h2).
  assert (FR: Frame = nil).
       subst Frame. reflexivity.
     rewrite FR. clear FR Frame. 
  entailer. 
after_call.
normalize. simpl.

eapply semax_pre with (P':=EX  x : hmacabs,
  (PROP  (hmacInit key x)
   LOCAL  (tc_environ Delta; tc_environ Delta;
   `(eq (Vptr b i)) (eval_id _md); `(eq k) (eval_id _key);
   `(eq (Vint (Int.repr kl))) (eval_id _key_len); `(eq d) (eval_id _d);
   `(eq (Vint (Int.repr dl))) (eval_id _n);
   `(eq c) (eval_var _c t_struct_hmac_ctx_st);
   `(eq KV) (eval_var sha._K256 (tarray tuint 64)))
   SEP (`(hmacstate_ x c); `(K_vector KV); `(data_block shmd dig (Vptr b i));
        `(memory_block shmd (Int.repr 32) (Vptr b (Int.repr (Int.unsigned i + 32))));
        `(data_block Tsh data d); `(initPostKey k key)))).
  entailer. apply (exp_right x). entailer.
apply extract_exists_pre. intros h3. normalize. rename H into h3_init.

eapply semax_seq'. 
myframe_SEP'' [0; 1; 4].
forward_call (h3, c, d, dl, data, KV).
  assert (FR: Frame = nil).
       subst Frame. reflexivity.
     rewrite FR. clear FR Frame. 
  entailer.
  apply andp_right. 2: cancel.
    unfold hmacstate_. normalize. apply prop_right. 
    assert (HH: s256a_len (absCtxt h3) = 512).
    Focus 2. destruct DL as [DL1 [DL2 DL3]]. split; trivial. split; trivial.
             rewrite HH; assumption. 
    destruct h3; simpl in *. 
    destruct H1 as [reprMD [reprI [reprO [iShaLen [oShaLen [K [ii [KL1 [KL2 KL3]]]]]]]]].
    inversion h3_init; clear h3_init.
    destruct H1 as [oS [InnSHA [OntSHA XX]]]. inversion XX; clear XX.
    subst. assumption.
after_call.
normalize. simpl. 

apply semax_pre with (P':=EX  x : hmacabs,
  (PROP  (hmacUpdate data h3 x)
   LOCAL  (tc_environ Delta; 
   `(eq (Vptr b i)) (eval_id _md); `(eq k) (eval_id _key);
   `(eq (Vint (Int.repr kl))) (eval_id _key_len); `(eq d) (eval_id _d);
   `(eq (Vint (Int.repr dl))) (eval_id _n);
   `(eq c) (eval_var _c t_struct_hmac_ctx_st);
   `(eq KV) (eval_var sha._K256 (tarray tuint 64)))
   SEP  (`(K_vector KV); `(hmacstate_ x c); `(data_block Tsh data d);
         `(data_block shmd dig (Vptr b i));
         `(memory_block shmd (Int.repr 32) (Vptr b (Int.repr (Int.unsigned i + 32))));
         `(initPostKey k key)))).
  entailer. apply (exp_right x). entailer. 
apply extract_exists_pre. intros h4. normalize. rename H into h4_update.

eapply semax_seq'. 
myframe_SEP'' [0; 1; 4].
forward_call (h4, c, Vptr b (Int.repr (Int.unsigned i + 32)), shmd, KV).
  assert (FR: Frame = nil).
       subst Frame. reflexivity.
     rewrite FR. clear FR Frame. 
  entailer. cancel.
after_call.
normalize. simpl.

eapply semax_pre with (P':=
      EX dig2 : list Z,
      EX h5 : hmacabs,
  (PROP  (hmacFinal h4 dig2 h5)
   LOCAL  (tc_environ Delta; `(eq (Vptr b i)) (eval_id _md); `(eq k) (eval_id _key);
   `(eq (Vint (Int.repr kl))) (eval_id _key_len); `(eq d) (eval_id _d);
   `(eq (Vint (Int.repr dl))) (eval_id _n);
   `(eq c) (eval_var _c t_struct_hmac_ctx_st);
   `(eq KV) (eval_var sha._K256 (tarray tuint 64)))
   SEP 
   (`(K_vector KV); `(hmacstate_PostFinal h5 c);
    `(data_block shmd dig2 (Vptr b (Int.repr (Int.unsigned i + 32))));
    `(data_block Tsh data d); `(data_block shmd dig (Vptr b i));
     `(initPostKey k key)))).
   entailer. 
   apply (exp_right x). apply (exp_right x0). entailer. 
apply extract_exists_pre. intros dig2. apply extract_exists_pre. intros h5.
normalize. rename H into Round2Final.

eapply semax_seq'.
myframe_SEP'' [1].
forward_call (h5,c).
  assert (FR: Frame = nil).
       subst Frame. reflexivity.
     rewrite FR. clear FR Frame. 
  entailer.
after_call.
simpl. normalize. simpl. normalize.
  rename H into SCc. rename H0 into ACc.

forward.
apply (exp_right dig).
simpl_stackframe_of. normalize. clear H0. 
assert (HS: hmacSimple key data dig).
    exists h0, h1. 
    split. destruct KL as [KL1 [KLb KLc]].
           (*rewrite KL1.*) assumption.
    split; try assumption.
    rewrite hmacFinal_hmacFinalSimple. exists h2; assumption.
assert (Size: sizeof t_struct_hmac_ctx_st <= Int.max_unsigned).
  rewrite int_max_unsigned_eq; simpl. omega.
apply andp_right. apply prop_right. split; trivial.
apply andp_right. apply prop_right. trivial. cancel.
rewrite sepcon_assoc. rewrite sepcon_comm.
apply sepcon_derives.
  assert (D1: dig = HMAC256 data key).
     apply hmac_sound with (h:=h2).
     exists h0, h1. auto.
  assert (D2: dig2 = HMAC256 data key).
     eapply hmac_sound with (h:=h5).
     exists h3, h4. auto.

  rewrite (split2_data_block 32 shmd (dig ++ dig)).
  2: subst dig; rewrite app_length, HMAC_length; omega.
  entailer.
  rewrite initial_world.Zlength_app, HMAC_Zlength. 
   apply andp_right. apply prop_right; simpl.
    specialize (Int.unsigned_range i). omega. 

  rewrite firstn_app1. 2: rewrite HMAC_length; trivial.
  rewrite firstn_precise.  2: rewrite HMAC_length; trivial.
  cancel.

  rewrite skipn_app2; rewrite HMAC_length. 2: omega. 
  simpl. cancel.

unfold data_block.
  rewrite Zlength_correct; simpl.
rewrite <- memory_block_data_at_; try reflexivity. 
(*XXX: was: rewrite memory_block_array_tuchar. *)
normalize.
rewrite (memory_block_data_at_ Tsh (tarray tuchar 392)).
  apply data_at_data_at_.
  trivial.
  trivial.
  trivial.
  unfold align_compatible. destruct (eval_var _c t_struct_hmac_ctx_st rho); trivial.
   simpl. apply Z.divide_1_l.
  simpl. rewrite <- initialize.max_unsigned_modulus, int_max_unsigned_eq. omega.
 
unfold align_compatible. destruct (eval_var _c t_struct_hmac_ctx_st rho); trivial.
Qed.
