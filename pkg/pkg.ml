#!/usr/bin/env ocaml
#use "topfind"
#require "topkg"
open Topkg

let () =
  Pkg.describe "oanda" @@ fun c ->
  Ok [ Pkg.mllib "src/oanda.mllib" ]
