(* TODO:
   define meta-env, substitution
   do refinement
   do checking
   define "complex" lexing/parsing
   define "complex" printing

*)

type location = Lexing.position * Lexing.position
let dummy_loc = (Lexing.dummy_pos, Lexing.dummy_pos)

(* sorts *)
type sort = Type | Kind

(* Core type *)
type term =
  | Sort of location * sort
  | Let of location * string * term * term * term (* let s : t1 := t2 in t3 *)
  | Prod of location * string * term * term (* forall s : t1, t2 *)
  | Abs of location * string * term * term (* fun s : t1 => t2 *)
  | App of location * term * term list (* t1 t2 *)
  | Inter of location * term * term (* t1 & t2 *)
  | Union of location * term * term (* t1 | t2 *)
  | SPair of location * term * term (* < t1, t2 > *)
  | SPrLeft of location * term (* proj_l t1 *)
  | SPrRight of location * term (* proj_r t1 *)
  | SMatch of location * term * term * string * term * term * string * term * term (* match t1 return t2 with s1 : t3 => t4 , s2 : t5 => t6 end *)
  | SInLeft of location * term * term (* inj_l t1 t2 *)
  | SInRight of location * term * term (* inj_r t1 t2 *)
  | Coercion of location * term * term (* coe t1 t2 *)
  | Var of location * int (* bruijn index *)
  | Const of location * string (* variable name *)
  | Underscore of location (* meta-variables before analysis *)
  | Meta of location * int * (term list) (* index and substitution *)

(* This is the safe way to construct an application *)
(* putting spines in spines *)
let app l t1 t2 =
  match t1 with
  | App(l, t1, l1) -> App(l, t1, t2 :: l1)
  | _ -> App (l, t1, t2 :: [])

let app' l t1 t2 =
  match t1 with
  | App(l, t1, l1) -> App(l, t1, t2 @ l1)
  | _ -> App(l, t1, t2)

let nothing = Underscore dummy_loc

(* In the contexts, there are let-ins and axioms *)
type declaration =
  | DefAxiom of string * term (* x : A *)
  | DefLet of string * term * term (* x := t : A *)

(* Indices for meta-variables are integers (not de Bruijn indices) *)

(* Idea:
Two questions:
- do we know the essence? (Y/N)
- do we know the type? (Y/N)
Hence 4 main algorithms.

Meta-environment: list of 4 possible things:
- is_sort ?n (means ?n is either Type or Kind) (superseded by ?n is sort s)
- ?n is sort s
- Gamma |- ?n : T (superseded by ?n := x and by essence(?n) := x : T)
- Gamma |- essence ?n := x : T (superseded by ?n := x)
- Gamma |- ?n := x : T
*)
type metadeclaration =
  | IsSort of int
  | SubstSort of int * term
  | DefMeta of declaration list * int * term
  | Subst of declaration list * int * term * term

type metaenv = int * (metadeclaration list)

(* Commands from the REPL *)
type sentence =
  | Quit
  | Load of string
  | Proof of string * term
  | Axiom of string * term
  | Definition of string * term * term
  | Print of string
  | Print_all
  | Show
  | Compute of term
  | Help
  | Error
  | Beginmeta
  | Endmeta
  | Unify of term * term
  | Add of (string * term) list * term
  | UAxiom of string * term
  | UDefinition of string * term * term

(* Error during type reconstruction or unification *)
exception Err of string

type errcheck =
  | Kind_Error
  | Coercion_Error
  | Const_Error
  | Force_Type_Error

let notnone x =
  match x with
  | None -> failwith "notnone"
  | Some x -> x

let find l n =
    try
      ignore @@ List.find (fun m -> m = n) l;
      true
    with
    | Not_found -> false
