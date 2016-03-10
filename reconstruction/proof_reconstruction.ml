open Definitions

let rec rebuild_delta derivation =
  match derivation with
  | AMark i -> DMark i
  | AFcI (t, a) ->
     (
       match (t.m, t.s) with
       | (MLambda (_, i, _), SFc (s1, s2)) ->
	  DLambda (i, s1, rebuild_delta a)
       | _ -> failwith "wrong tree"
     )
  | AFcE (_, a1, a2) ->
     DApp (rebuild_delta a1, rebuild_delta a2)
  | AAndI (_, a1, a2) ->
     DAnd (rebuild_delta a1, rebuild_delta a2)
  | AAndEL (_, a) ->
     DLeft (rebuild_delta a)
  | AAndER (_, a) ->
     DRight (rebuild_delta a)
  | ANull _ -> failwith "empty tree"

let replace derivation leaf c =
  let rec visit (derivation : derivation) =
    match derivation with
    | ANull c' when c = c' -> leaf
    | ANull _ -> failwith "full"
    | AMark _ -> failwith "full"
    | AFcI (t, a) -> AFcI (t, visit a)
    | AFcE (t, a1, a2) ->
       (
	 try (
	   let a1' = visit a1 in
	   AFcE (t, a1', a2)
	 )
	 with Failure "full" ->
	   let a2' = visit a2 in
	   AFcE (t, a1, a2')
       )
    | AAndI (t, a1, a2) ->
       (
	 try (
	   let a1' = visit a1 in
	   AAndI (t, a1', a2)
	 )
	 with Failure "full" ->
	   let a2' = visit a2 in
	   AAndI (t, a1, a2')
       )
    | AAndEL (t, a) -> AAndEL (t, visit a)
    | AAndER (t, a) -> AAndER (t, visit a)
  in visit derivation

let shift pb =
  match pb.jlist with
  | [] -> failwith "should not happen"
  | t :: l -> {cmax = pb.cmax; jlist = l; derivation = pb.derivation }

let choose_var pb =
  (
    match pb.jlist with
    | t :: l ->
       (
	 match t.m with
	 | MVar x ->
	    let i = find_i x t.s t.g in
	    shift ({cmax = pb.cmax; jlist = pb.jlist; derivation = replace pb.derivation (AMark i) t.c})
	 | _ -> failwith "var"
       )
    | _ -> failwith "var"
  )

let choose_fci pb =
  match pb.jlist with
  | t :: l ->
     (
       match t.m, t.s with
       | MLambda (x, i, m), SFc (s1, s2) ->
	  {
	    cmax = pb.cmax;
	    jlist = {c = t.c; g = (x, i, s1)::t.g; m = m; s = s2} :: l;
	    derivation = replace pb.derivation (AFcI (t, ANull t.c)) t.c
	  }
       | _ -> failwith "fci"
     )
  | _ -> failwith "fci"

let choose_fce pb a =
  match pb.jlist with
  | t :: l ->
     (
       match t.m with
       | MApp (m1, m2) ->
	  {
	    cmax = pb.cmax+1;
	    jlist = {c = pb.cmax+1; g = t.g; m = m1; s = SFc (a, t.s)}
		    :: {c = t.c; g = t.g; m = m2; s = a}
		    :: l;
	    derivation = replace pb.derivation (AFcE (t, ANull (pb.cmax+1), ANull t.c)) t.c
	  }
       | _ -> failwith "fce"
     )
  | _ -> failwith "fce"

let choose_andi pb =
  match pb.jlist with
  | t :: l ->
     (
       match t.s with
       | SAnd (s1, s2) ->
	  {
	    cmax = pb.cmax+1;
	    jlist = {c = pb.cmax+1; g = t.g; m = t.m; s = s1}
		    :: {c = t.c; g = t.g; m = t.m; s = s2}
		    :: l;
	    derivation = replace pb.derivation (AAndI (t, ANull (pb.cmax+1), ANull t.c)) t.c;
	  }
       | _ -> failwith "andi"
     )
  | _ -> failwith "andi"

let choose_andel pb a =
  match pb.jlist with
  | t :: l ->
     {
       cmax = pb.cmax;
       jlist = {c = t.c; g = t.g; m = t.m; s = SAnd (t.s, a)} :: l ;
       derivation = replace pb.derivation (AAndEL (t, ANull t.c)) t.c;
     }
  | _ -> failwith "andel"

let choose_ander pb a =
  match pb.jlist with
  | t :: l ->
     {
       cmax = pb.cmax;
       jlist = {c = t.c; g = t.g; m = t.m; s = SAnd (a, t.s)} :: l ;
       derivation = replace pb.derivation (AAndER (t, ANull t.c)) t.c;
     }
  | _ -> failwith "ander"

let changegoal pb =
  let rec cdr x l =
    match l with
    | [] -> x :: []
    | y :: l' -> y :: (cdr x l')
  in
  match pb.jlist with
  | t :: l ->
     {
       cmax = pb.cmax;
       jlist = cdr t l;
       derivation = pb.derivation
     }
  | _ -> failwith "change"

let possibilities t list bol =
  let visit_fci l =
    match t.m, t.s with
    | MLambda _, SFc _ -> "->I" :: l
    | _ -> l
  and visit_fce l =
    match t.m with
    | MApp _ -> "->E" :: l
    | _ -> l
  and visit_var l =
    match t.m with
    | MVar x ->
       (
	 try (
	   let _ = find_i x t.s t.g in
	   "var" :: l
	 )
	 with Failure "empty list" -> l
       )
    | _ -> l
  and visit_andi l =
    match t.s with
    | SAnd _ -> "&I" :: l
    | _ -> l
  and visit_change l =
    match list with
    | [] -> l
    | _ -> "change" :: l
  in visit_fci (visit_fce (visit_var (visit_andi (visit_change ("&El" :: "&Er" :: (if bol then ["backtrack"] else []))))))

let choose pb bol =
  let rec aux =
    function
    | [] -> print_string "\n\n"
    | op :: l ->
       begin
	 print_string op;
	 if l = [] then () else print_string " ; ";
	 aux l
       end
  in
  let rec choose_type () =
    print_string "\nType the intermediate type you want, or 'cancel' to come back to rules.\n\n";
    let l = read_line () in
    match l with
    | "cancel" -> failwith "annul"
    | _ ->
       try (
	 let lb = Lexing.from_string l in
	 Parser_sigma.s Lexer_sigma.read lb
       )
       with _ ->
	 begin
	   print_string "\nWhat you taped is not understandable...\n\n";
	   choose_type ()
	 end
  and loop () =
    (
      match pb.jlist with
      | [] -> failwith "abnormal"
      | t :: l ->
	 (
	   print_string "\n";
	   print_pb pb;
	   print_string "Choose your rule :\n\n";
	   let lp = possibilities t l bol in
	   aux lp;
	   let opt = read_line () in
	   if List.exists (fun o -> opt = o) lp
	   then
	     match opt with
	     | "->I" -> OFcI
	     | "var" -> OVar
	     | "backtrack" -> OBacktrack
	     | "&I" -> OAndI
	     | "change" -> OChangeGoal
	     | "->E" ->
		(
		  try OFcE (choose_type ())
		  with Failure "annul" -> loop ()
		)
	     | "&El" ->
		(
		  try OAndEL (choose_type ())
		  with Failure "annul" -> loop ()
		)
	     | "&Er" ->
		(
		  try OAndER (choose_type ())
		  with Failure "annul" -> loop ()
		)
	     | _ -> failwith "isn't happening ever"
	   else
	     begin
	       print_string "\nYou cannot choose this option yet, or you taped something wrong\n\n";
	       loop ()
	     end
	 )
    )
  in
  loop ()

let rec algorithm pb_tot =
  match pb_tot with
  | [] -> failwith "should not happen"
  | pb :: lnext ->
     match pb.jlist with
     | [] ->
	print_string ("\nYou succeeded, here is the delta you were looking for:\n"^(delta_to_string (rebuild_delta pb.derivation))^ "\n\n")
     | _ ->
	let opt = choose pb (if lnext = [] then false else true) in
	match opt with
	| OFcI ->
	   algorithm ((choose_fci pb) :: pb_tot)
	| OFcE a ->
	   algorithm ((choose_fce pb a) :: pb_tot)
	| OAndI ->
	   algorithm ((choose_andi pb) :: pb_tot)
	| OAndEL a ->
	   algorithm ((choose_andel pb a) :: pb_tot)
	| OAndER a ->
	   algorithm ((choose_ander pb a) :: pb_tot)
	| OVar ->
	   algorithm ((choose_var pb) :: pb_tot)
	| OBacktrack -> algorithm lnext
	| OChangeGoal -> algorithm ((changegoal pb) :: pb_tot)

let main_pr lbm lbs =
  let m = Parser_m.m Lexer_m.read lbm
  and s = Parser_sigma.s Lexer_sigma.read lbs
  in
  let pb = {
    cmax = 0;
    jlist =  [{c = 0; g = []; m = m; s = s}];
    derivation = ANull 0
  }
  in algorithm [pb]
