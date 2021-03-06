open Utils
open Reduction
open Unification

(* Note: for now, these functions suppose that there is no type meta-variables in the terms *)
(* TODO: design an unification algorithm for types modulo subtyping *)

(* rewriting functions for disjunctive and conjunctive normal forms *)
let rec anf a =
  let rec distr f a b =
    match (a,b) with
    | (Union(l,a1,a2),_) -> Inter(l, distr f a1 b, distr f a2 b)
    | (_, Inter(l,b1,b2)) -> Inter(l, distr f a b1, distr f a b2)
    | _ -> f a b
  in
  match a with
  | Prod(l,id,a,b) -> distr (fun a b -> Prod(l,id,a,b)) (danf a) (canf b)
  | _ -> a
and canf a =
  let rec distr a b =
    match (a,b) with
    | (Inter(l,a1,a2),_) -> Inter(l, distr a1 b, distr a2 b)
    | (_,Inter(l,b1,b2)) -> Inter(l, distr a b1, distr a b2)
    | _ -> Union(dummy_loc,a,b)
  in
  match a with
  | Inter(l,a,b) -> Inter(l, canf a, canf b)
  | Union(l,a,b) -> distr (canf a) (canf b)
  | _ -> anf a
and danf a =
  let rec distr a b =
    match (a,b) with
    | (Union(l,a1,a2),_) -> Union(l, distr a1 b, distr a2 b)
    | (_,Union(l,b1,b2)) -> Union(l, distr a b1, distr a b2)
    | _ -> Inter(dummy_loc, a,b)
  in
  match a with
  | Inter(l,a,b) -> distr (danf a) (danf b)
  | Union(l,a,b) -> Union(l, danf a, danf b)
  | _ -> anf a

(* tell whether a <= b *)
(* we suppose types are not essence types *)
let is_subtype env ctx a b =
  let a = danf @@ strongly_normalize false env ctx a in
  let b = canf @@ strongly_normalize false env ctx b in
  let rec foo env ctx a b =
  match (a, b) with
  | (Union(_,a1,a2),_) -> foo env ctx a1 b && foo env ctx a2 b
  | (_,Inter(_,b1,b2)) -> foo env ctx a b1 && foo env ctx a b2
  | (Inter(_,a1,a2),_) -> foo env ctx a1 b || foo env ctx a2 b
  | (_,Union(_,b1,b2)) -> foo env ctx a b1 || foo env ctx a b2
  | (Prod(_,_,a1,a2),Prod(_,_,b1,b2))
    -> foo env ctx b1 a1 && foo env (Env.add_var ctx (DefAxiom("",nothing))) a2 b2
  | _ -> same_term a b
  in foo env ctx a b
