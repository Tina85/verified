Require Import Coq.Arith.Arith.
Require Import Coq.Init.Nat.
Require Import Coq.Lists.List.
Require Import Coq.Logic.FunctionalExtensionality.
Require Import Permutation.
Require Import SortSpec.

Require Import Tactics.CpdtTactics.

Ltac b2p :=
  repeat
    try match goal with
        | [ H : (_ <=? _) = true |- _] => apply leb_complete in H
        | [ H : (_ <=? _) = false |- _] => apply leb_complete_conv in H
        end.

Lemma Forall_Permutation :
  forall A (l l' : list A) P, Forall P l -> Permutation l l' -> Forall P l'.
Proof.
  intros. apply Forall_forall.
  intros. apply Permutation_sym in H0.
  eapply Permutation_in in H0; eauto.
  rewrite Forall_forall in H.
  apply H. apply H0.
Qed.

Definition AllLe (x : nat) (l : list nat) : Prop := Forall (fun y => x <= y) l.
Definition AllGe (x : nat) (l : list nat) : Prop := Forall (fun y => x >= y) l.

Hint Unfold AllLe AllGe.

Lemma lnilge1 :
  length (@nil nat) >= 1 -> False.
Proof.
  crush.
Qed.

Lemma llt1 :
  forall (l : list nat), length l < 1 -> l = nil.
Proof.
  intros; destruct l; crush.
Qed.

Definition lengthOrder (l1 l2 : list nat) :=
  length l1 < length l2.

Lemma lengthOrder_wf' :
  forall len l, length l <= len -> Acc lengthOrder l.
Proof.
  Hint Constructors Acc.
  unfold lengthOrder; induction len; crush.
Defined.

Theorem lengthOrder_wf : well_founded lengthOrder.
Proof.
  Hint Constructors Acc.
  unfold lengthOrder; intro; eapply lengthOrder_wf'; eauto.
Defined.

Fixpoint divide (x : nat) (l : list nat) : (list nat) * (list nat) :=
  match l with
  | nil => (nil, nil)
  | y :: l' => let (p1, p2) := divide x l'
                in if (y <=? x) then (y :: p1, p2) else (p1, y :: p2)
  end.

Definition pivot (l : list nat) : (length l >= 1) -> nat * ((list nat) * (list nat)) :=
  match l with
  | nil => fun proof : length nil >= 1 => match lnilge1 proof with end
  | x :: l' => fun _ => (x, divide x l')
  end.

Lemma divide_spec :
  forall x l l1 l2,
    (l1, l2) = divide x l -> AllLe x l2 /\ AllGe x l1 /\ Permutation (l1 ++ l2) l.
Proof.
  intros x l; induction l; crush;
  destruct (divide x l); destruct (a <=? x) eqn:H1; b2p; inversion H; subst;
  pose proof (IHl l0 l3); crush;
  apply Permutation_sym; apply Permutation_cons_app; crush.
Qed.

Lemma divide_length :
  forall x l l1 l2,
    (l1, l2) = divide x l -> length l1 <= length l /\ length l2 <= length l.
Proof.
  intros; pose proof (divide_spec x l l1 l2); crush;
  apply Permutation_length in H3;
  rewrite app_length in H3; crush.
Qed.

Lemma pivot_wf :
  forall l x l1 l2 (proof : length l >= 1),
    (x, (l1, l2)) = pivot l proof ->
      lengthOrder l1 l /\ lengthOrder l2 l.
Proof.
  intros; unfold pivot in H;
  destruct l; crush;
  pose proof (divide_length n l l1 l2);
  unfold lengthOrder; crush.
Qed.

Lemma pivot_spec :
  forall l x l1 l2 (proof : length l >= 1),
    (x, (l1, l2)) = pivot l proof ->
      AllLe x l2 /\ AllGe x l1 /\ Permutation l (l1 ++ (x :: nil) ++ l2).
Proof.
  Hint Resolve Permutation_cons_app.
  intros; unfold pivot in H; destruct l; crush; apply divide_spec in H; crush.
Qed.

Definition quicksort : list nat -> list nat.
  refine (Fix lengthOrder_wf (fun _ => list nat)
    (fun (l : list nat)
      (quicksort : forall l' : list nat, lengthOrder l' l -> list nat) =>
        match ge_dec (length l) 1 with
        | left proof => let t := pivot l proof
                         in quicksort (fst (snd t)) _ ++ (fst t) :: nil ++ quicksort (snd (snd t)) _
        | right _ => l
        end
	  )
	); remember (pivot l proof); repeat destruct p; simpl;
	   pose proof (pivot_wf l n l0 l1 proof); crush.
Defined.

Extraction divide.
Extraction pivot.
Extraction quicksort.

Theorem quicksort_eq : forall l,
  quicksort l =
    match ge_dec (length l) 1 with
    | left proof => let t := pivot l proof
                     in quicksort (fst (snd t)) ++ (fst t) :: nil ++ quicksort (snd (snd t))
    | right _ => l
    end.
Proof.
  intros. apply (Fix_eq lengthOrder_wf (fun _ => list nat)); intros.
  destruct (ge_dec (length x) 1); simpl; repeat f_equal; auto.
Qed.

Lemma all_le_ge_sorted :
  forall n l0 l1, AllGe n l0 -> AllLe n l1 -> Sorted l0 -> Sorted l1 ->
    Sorted (l0 ++ (n :: nil) ++ l1).
Proof.
  intros n l0.
  induction l0; intros; simpl.
  - inversion H0; subst; crush.
  - destruct l0.
    + constructor; crush; inversion H; auto.
    + simpl; constructor; crush; inversion H1; crush.
      apply IHl0; crush; inversion H; crush.
Qed.

Lemma all_le_permutation :
  forall n l0 l1, AllLe n l0 -> Permutation l0 l1 -> AllLe n l1.
Proof.
  intros.
  pose proof (Forall_Permutation nat l0 l1 (fun x => n <= x)); auto.
Qed.

Theorem quicksort_ok :
  SortSpec quicksort.
Proof.
  unfold SortSpec.
  intros.
  apply (well_founded_ind lengthOrder_wf
    (fun l => Sorted (quicksort l) /\ Permutation l (quicksort l))
  ).
  intros; rewrite quicksort_eq; simpl; destruct (ge_dec (length x) 1).
  - remember (pivot x g); repeat destruct p; simpl.
    pose proof (pivot_wf x n l0 l1 g);
    pose proof (pivot_spec x n l0 l1 g); crush;
    apply H in H0; apply H in H3; crush.
    + apply all_le_ge_sorted; crush.
      pose proof (Forall_Permutation nat l0 (quicksort l0) (fun x => n >= x)); auto.
      pose proof (Forall_Permutation nat l1 (quicksort l1) (fun x => n <= x)); auto.
    + apply Permutation_add_inside; crush.
  - apply not_ge in n. apply llt1 in n. subst; crush.
Qed.
