open Core
open Async
open Log.Global

open Oanda
open Oanda_async

let main trade_api loglevel cmd cmd_args () =
  let api = if trade_api then Trade else Practice in
  set_level (match loglevel with 2 -> `Info | 3 -> `Debug | _ -> `Error) ;
  Sys.home_directory () >>= fun homedir ->
  Reader.file_lines Filename.(concat homedir ".oanda") >>= fun lines ->
  init ~user_agent:"ocaml-oanda" ~token:(List.hd_exn lines) ;
  let cmd = String.lowercase cmd in
  match cmd with
  | "account" | "accounts" -> begin
      Account.list ~log:(Lazy.force log) api >>| function
      | Ok props ->
          printf "OK"
      | Error _err ->
          printf "Error"
    end
  | "price" -> begin
      begin
        let open Deferred.Result in
        Account.list ~log:(Lazy.force log) api >>= function
        | { id = account } :: _ ->
            let instruments =
              List.filter_map cmd_args ~f:Instrument.name_of_string in
            Account.price
              ~log:(Lazy.force log) ~account ~instruments api >>| fun prices ->
            ()
        | _ -> Deferred.return (Error { code = None ; message = "" })
      end >>= function
      | Ok () ->
          printf "OK" ;
          Deferred.unit
      | Error _ ->
          printf "Error" ;
          Deferred.unit
    end
  | cmd  ->
      printf "No such command %s" cmd;
      Deferred.unit

let command =
  let spec =
    let open Command.Spec in
    empty
    +> flag "-trade-api" no_arg ~doc:" Use trade API (non-simulated)"
    +> flag "-loglevel" (optional_with_default 1 int) ~doc:"1-3 global loglevel"
    +> anon ("cmd" %: string)
    +> anon (sequence ("cmd_args" %: string))
  in
  Command.async_spec ~summary:"OANDA Shell" spec main

let () = Command.run command

