(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)



[@@@ocaml.warning "+9"]


type arity = 
  | Single of Lam_arity.t
  | Submodule of Lam_arity.t array

(* TODO: add a magic number *)
type cmj_value = {
  arity : arity ;
  persistent_closed_lambda : Lam.t option ; 
  (** Either constant or closed functor *)
}

type effect = string option


let single_na = Single Lam_arity.na
(** we don't force people to use package *)
type cmj_case = Ext_namespace.file_kind
  
type t = {
  values : cmj_value String_map.t;
  effect : effect;
  npm_package_path : Js_packages_info.t ;
  cmj_case : cmj_case; 
}

let mk ~values ~effect ~npm_package_path ~cmj_case : t = 
  {
    values; 
    effect;
    npm_package_path;
    cmj_case
  }

let cmj_magic_number =  "BUCKLE20171012"
let cmj_magic_number_length = 
  String.length cmj_magic_number

let pure_dummy = 
  {
    values = String_map.empty;
    effect = None;
    npm_package_path = Js_packages_info.empty;
    cmj_case = Little_js;
  }

let no_pure_dummy = 
  {
    values = String_map.empty;
    effect = Some Ext_string.empty;
    npm_package_path = Js_packages_info.empty;  
    cmj_case = Little_js; (** TODO: consistent with Js_config.bs_suffix default *)
  }

let digest_length = 16 (*16 chars *)

let verify_magic_in_beg ic =
  let buffer = really_input_string ic cmj_magic_number_length in 
  if buffer <> cmj_magic_number then
    Ext_pervasives.failwithf ~loc:__LOC__ 
      "cmj files have incompatible versions, please rebuilt using the new compiler : %s" 
        __LOC__


(* Serialization .. *)
let from_file name : t =
  let ic = open_in_bin name in 
  verify_magic_in_beg ic ; 
  let _digest = Digest.input ic in 
  let v  : t = input_value ic in 
  close_in ic ;
  v 

let from_file_with_digest name : t * Digest.t =
  let ic = open_in_bin name in 
  verify_magic_in_beg ic ; 
  let digest = Digest.input ic in 
  let v  : t = input_value ic in 
  close_in ic ;
  v,digest 


let from_string s : t = 
  let magic_number = String.sub s 0 cmj_magic_number_length in 
  if magic_number = cmj_magic_number then 
    Marshal.from_string s  (digest_length + cmj_magic_number_length)
  else 
    Ext_pervasives.failwithf ~loc:__LOC__ 
      "cmj files have incompatible versions, please rebuilt using the new compiler : %s"
        __LOC__

let rec for_sure_not_changed (name : string) cur_digest =   
  if Sys.file_exists name then 
    let ic = open_in_bin name in 
    verify_magic_in_beg ic ; 
    let digest = Digest.input ic in 
    close_in ic; 
    (digest : string) = cur_digest
  else false  
    
(* This may cause some build system always rebuild
  maybe should not be turned on by default
*) 
let to_file name ~check_exists (v : t) = 
  let s = Marshal.to_string v [] in 
  let cur_digest = Digest.string s in 
  if  not (check_exists && for_sure_not_changed name cur_digest) then 
    let oc = open_out_bin name in 
    output_string oc cmj_magic_number;    
    Digest.output oc cur_digest;
    output_string oc s;
    close_out oc 


