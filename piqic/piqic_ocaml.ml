(*pp camlp4o -I $PIQI_ROOT/camlp4 pa_labelscope.cmo pa_openin.cmo *)
(*
   Copyright 2009, 2010, 2011 Anton Lavrik

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*)


(* 
 * Piq interface compiler for OCaml
 *)

open Piqi_common


let mlname_func_param func_name param_name param =
  let make_name () =
    Some (func_name ^ "_" ^ param_name)
  in
  match param with
   | None -> ()
   | Some (`record x) ->
       x.R#ocaml_name <- make_name ()
   | Some (`alias x) ->
       x.A#ocaml_name <- make_name ()


let mlname_func x =
  let open T.Func in (
    if x.ocaml_name = None then x.ocaml_name <- Piqic_ocaml_base.mlname x.name;
    let func_name = some_of x.ocaml_name in
    mlname_func_param func_name "input" x.resolved_input;
    mlname_func_param func_name "output" x.resolved_output;
    mlname_func_param func_name "error" x.resolved_error;
  )


let mlname_functions l =
  List.iter mlname_func l


module Main = Piqi_main
open Main


let ocaml_pretty_print ifile ofile =
  let cmd =
    if ofile = "-"
    then Printf.sprintf "camlp4o %s" ifile
    else Printf.sprintf "camlp4o -o %s %s" ofile ifile 
  in
  let res = Sys.command cmd in
  if res <> 0
  then piqi_error ("command execution failed: " ^ cmd)


(* command-line flags *)
let flag_pp = ref false


let piqic_file ifile =
  Piqic_common.init ();

  (* obtain modname of the file by cutting out the directory and extension
   * parts *)
  let modname = Piqi_file.basename ifile in

  (* open output .ml file *)
  (*
  let modname = some_of piqi.T.Piqi.ocaml_name in
  let modname = String.lowercase modname in
  let ofile = modname ^ ".ml" in
  *)
  (* load input .piqi file *)
  let piqi = Piqi.load_piqi ifile in

  (* naming function parameters first, because otherwise they will be overriden
   * in Piqic_ocaml_base.mlname_defs *)
  mlname_functions piqi.P#resolved_func;

  (* chdir to the output directory *)
  Main.chdir_output !odir;

  let ofile =
    match !ofile with
      | "" -> modname ^ ".ml"
      | x -> x
  in
  (* call piq interface compiler for ocaml *)
  if not !flag_pp
  then
    let ch = Main.open_output ofile in
    Piqic_ocaml_base.piqic piqi ch
  else
    begin
      (* prettyprint generated OCaml code using Camlp4 *)
      let tmp_file = modname ^ ".tmp.ml" in
      (try
        let tmp_ch = open_out tmp_file in
        Piqic_ocaml_base.piqic piqi tmp_ch;
        close_out tmp_ch;
      with Sys_error s ->
        piqi_error ("error writing temporary file: " ^ s));
      ocaml_pretty_print tmp_file ofile;
      Main.add_tmp_file tmp_file;
    end


let usage = "Usage: piqic ocaml [options] <.piqi file>\nOptions:"


let speclist = Main.common_speclist @
  [
    arg_o;
    arg_C;

    "--pp", Arg.Set flag_pp,
      "pretty-print output using CamlP4 (camlp4o)"; 
    Piqic_common.arg__gen_defaults;
    Piqic_common.arg__normalize;
    arg__leave_tmp_files;
  ]


let run () =
  Main.parse_args () ~usage ~speclist;
  piqic_file !ifile

 
let _ =
  Main.register_command run "ocaml" "generate OCaml stubs from %.piqi"

