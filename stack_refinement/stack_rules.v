From iris.proofmode Require Import tactics.
From iris.algebra Require Import auth gmap agree.
From iris_examples.logrel.F_mu_ref_conc Require Import logrel_binary.
Import uPred.
From iris.algebra Require deprecated.
Import deprecated.dec_agree.


Definition stackUR : ucmraT := gmapUR loc (agreeR valO).

Class stackG Σ :=
  StackG { stack_inG :> inG Σ (authR stackUR); stack_name : gname }.

Definition stack_mapsto `{stackG Σ} (l : loc) (v : val) : iProp Σ :=
  own stack_name (◯ {[ l := to_agree v ]}).

Notation "l ↦ˢᵗᵏ v" := (stack_mapsto l v) (at level 20) : bi_scope.

Definition stateUR  : cmraT :=
  (prodR fracR (agreeR (leibnizO loc))).


Definition newstate (q:Qp) (b:loc):stateUR := (q, to_agree (b : leibnizO loc)).


Notation "γ ⤇[ q ] b" := (own γ ( newstate q  b))
                             (at level 20, q at level 50, format "γ ⤇[ q ] b") : bi_scope.
Notation "γ ⤇½ b" := (own γ (newstate (1/2) b))
                         (at level 30, format "γ ⤇½  b") : bi_scope.




Section Rules.
  Context `{stackG Σ}.
  Notation D := (prodO valO valO -n> iPropO Σ).

  Global Instance stack_mapsto_persistent l v : Persistent (l ↦ˢᵗᵏ v).
  Proof. apply _. Qed.

  Lemma stack_mapstos_agree l v w : l ↦ˢᵗᵏ v ∗ l ↦ˢᵗᵏ w ⊢ ⌜v = w⌝.
  Proof.
    rewrite -own_op -auth_frag_op singleton_op own_valid.
    by iIntros (->%auth_frag_valid%singleton_valid%agree_op_invL').
  Qed.

  Program Definition StackLink_pre (Q : D) : D -n> D := λne P v,
    (∃ l w, ⌜v.1 = LocV l⌝ ∗ l ↦ˢᵗᵏ w ∗
            ((⌜w = InjLV UnitV⌝ ∧ ⌜v.2 = FoldV (InjLV UnitV)⌝) ∨
            (∃ y1 z1 y2 z2 z1v, ⌜w = InjRV (PairV y1 (FoldV z1))⌝ ∗ ⌜z1 = (LocV z1v) ⌝ ∗
              ⌜v.2 = FoldV (InjRV (PairV y2 z2))⌝ ∗ Q (y1, y2) ∗ ▷ P(z1, z2))))%I.
  Solve Obligations with solve_proper.

  Global Instance StackLink_pre_contractive Q : Contractive (StackLink_pre Q).
  Proof. solve_contractive. Qed.

  Definition StackLink (Q : D) : D := fixpoint (StackLink_pre Q).

  Lemma StackLink_unfold Q v :
    StackLink Q v ≡ (∃ l w,
      ⌜v.1 = LocV l⌝ ∗ l ↦ˢᵗᵏ w ∗
      ((⌜w = InjLV UnitV⌝ ∧ ⌜v.2 = FoldV (InjLV UnitV)⌝) ∨
      (∃ y1 z1 y2 z2 z1v, ⌜w = InjRV (PairV y1 (FoldV z1))⌝ ∗ ⌜z1 = (LocV z1v) ⌝ ∗
                      ⌜v.2 = FoldV (InjRV (PairV y2 z2))⌝
                      ∗ Q (y1, y2) ∗ ▷ @StackLink Q (z1, z2))))%I.
  Proof. rewrite {1}/StackLink (fixpoint_unfold (StackLink_pre Q) v) //. Qed.

  Global Opaque StackLink. (* So that we can only use the unfold above. *)

  Global Instance StackLink_persistent (Q : D) v `{∀ vw, Persistent (Q vw)} :
    Persistent (StackLink Q v).
  Proof.
    unfold Persistent.
    iIntros "H". iLöb as "IH" forall (v). rewrite StackLink_unfold.
    iDestruct "H" as (l w) "[% [#Hl [#Hr|Hr]]]"; subst.
    { iExists l, w; iAlways; eauto. }
    iDestruct "Hr" as (y1 z1 y2 z2 z2v) "(#H1 & #Hv & #H2 & #HQ & H')".
    rewrite later_forall. iDestruct ("IH" with "H'") as "#H''". iClear "H'".
    iAlways. eauto 20.
  Qed.

  Lemma stackR_alloc (h : stackUR) (i : loc) (v : val) :
    h !! i = None → ● h ~~> ● (<[i := to_agree v]> h) ⋅ ◯ {[i := to_agree v]}.
  Proof. intros. Locate "~~>". by apply auth_update_alloc, alloc_singleton_local_update. Qed.

  Context `{heapIG Σ}.

  Definition stack_owns (h : gmap loc val) :=
    (own stack_name (● ((to_agree <$> h) : stackUR))
        ∗ [∗ map] l ↦ v ∈ h, l ↦ᵢ v)%I.
  Locate "_ ↦ᵢ _".
  Lemma stack_owns_alloc h l v :
    stack_owns h ∗ l ↦ᵢ v ==∗ stack_owns (<[l := v]> h) ∗ l ↦ˢᵗᵏ v.
  Proof.
    iIntros "[[Hown Hall] Hl]".
    iDestruct (own_valid with "Hown") as %Hvalid.
    destruct (h !! l) as [w|] eqn:?.
    { iDestruct (@big_sepM_lookup with "Hall") as "Hl'"; first done.
      by iDestruct (@mapsto_valid_2 loc val with "Hl Hl'") as %Hvl. }
    iMod (own_update with "Hown") as "[Hown Hl']".
    { eapply auth_update_alloc.
        eapply (alloc_singleton_local_update _ l (to_agree v)); last done.
    by rewrite lookup_fmap Heqo. }
    iModIntro. rewrite /stack_owns. rewrite fmap_insert. iFrame "Hl' Hown".
    iApply @big_sepM_insert; simpl; try iFrame; auto.
  Qed.

  Lemma stack_owns_open_close h l v :
    stack_owns h -∗ l ↦ˢᵗᵏ v -∗ l ↦ᵢ v ∗ (l ↦ᵢ v -∗ stack_owns h).
  Proof.
    iIntros "[Howns Hls] Hl".
    iDestruct (own_valid_2 with "Howns Hl")
      as %[[az [Haz Hq]]%singleton_included_l _]%auth_both_valid.
    rewrite lookup_fmap in Haz.
    assert (∃ z, h !! l = Some z) as Hz.
    { revert Haz; case: (h !! l) => [z|] Hz; first (by eauto); inversion Hz. }
    destruct Hz as [z Hz]; rewrite Hz in Haz.
    apply Some_equiv_inj in Haz; revert Hq; rewrite -Haz => Hq.
    apply Some_included_total, to_agree_included, leibniz_equiv in Hq; subst.
    rewrite (big_sepM_lookup_acc _ _ l); eauto.
    iDestruct "Hls" as "[Hl' Hls]".
    iIntros "{$Hl'} Hl'". rewrite /stack_owns. iFrame "Howns". by iApply "Hls".
  Qed.

  Lemma stack_owns_later_open_close h l v :
    ▷ stack_owns h -∗ l ↦ˢᵗᵏ v -∗ ▷ (l ↦ᵢ v ∗ (l ↦ᵢ v -∗ stack_owns h)).
  Proof. iIntros "H1 H2". iNext; by iApply (stack_owns_open_close with "H1"). Qed.

From iris.bi.lib Require Import fractional.
Context `{inG Σ stateUR}.
Global Instance makeElem_fractional γ m:  Fractional(λ q, γ ⤇[ q ] m)%I.
Proof.
  intros p q. rewrite /newstate.
  rewrite -own_op; f_equiv.
  split; first done.
    by rewrite /= agree_idemp.
Qed.

Global Instance makeElem_as_fractional γ m q:
  AsFractional (own γ (newstate q m)) (λ q, γ ⤇[q] m)%I q.
Proof.
  split. done. apply _.
Qed.

Global Instance makeElem_Exclusive m: Exclusive (newstate 1 m).
Proof.
  intros [y ?] [H' _]. apply (exclusive_l _ _ H').
Qed.

Lemma makeElem_op p q n: newstate p n ⋅ newstate q n ≡ newstate (p + q) n.
Proof.
  rewrite /newstate; split; first done.
    by rewrite /= agree_idemp.
Qed.

Lemma makeElem_eq γ p q (n m : loc): γ ⤇[p] n -∗ γ ⤇[q] m -∗ ⌜n = m⌝.
Proof.
  iIntros "H1 H2".
  iDestruct (own_valid_2 with "H1 H2") as %HValid.
  destruct HValid as [_ H2'].
  iIntros "!%"; by apply agree_op_invL'.
Qed.

Lemma makeElem_entail γ p q (n m : loc): γ ⤇[p] n -∗ γ ⤇[q] m -∗ γ ⤇[p + q] n.
Proof.
  iIntros "H1 H2".
  iDestruct (makeElem_eq with "H1 H2") as %->.
  rewrite <- makeElem_op.
  iSplitL "H1".
  done.
  done.
Qed.

Lemma makeElem_update γ (n m k : loc): γ ⤇½ n -∗ γ ⤇½ m ==∗ γ ⤇[1] k.
Proof.
  iIntros "H1 H2".
  iDestruct (makeElem_entail with "H1 H2") as "H".
  rewrite Qp_div_2.
  iApply (own_update with "H"); by apply cmra_update_exclusive.
Qed.
Lemma invalid γ a:  γ⤇[3 / 2] a-∗ False.
Proof.
  iIntros "H".
  iDestruct (own_valid with "H") as %[[] _].
  eauto.
Qed.
Lemma dummy: (1/2 + 1/2 + 1/2 = 3/2)%Qp.
Proof.
  apply (bool_decide_unpack _).
  by compute.
Qed.

End Rules.
