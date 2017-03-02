open Core.Std
open Async.Std

open Cohttp_async
module Json = Json_encoding.Make(Json_repr.Yojson)

open Oanda

let headers = ref @@ Cohttp.Header.init ()

let set_token tok =
  Cohttp.Header.of_list ["Authorization", "Bearer " ^ tok]

let practice_url = Uri.of_string "https://api-fxpractice.oanda.com"
let trade_url = Uri.of_string "https://api-fxtrade.oanda.com"

let practice_stream_url = Uri.of_string "https://stream-fxpractice.oanda.com"
let trade_stream_url = Uri.of_string "https://stream-fxtrade.oanda.com"

type api = Practice | Trade

let url_of_api = function
| Practice -> practice_url
| Trade -> trade_url

let streaming_url_of_api = function
| Practice -> practice_stream_url
| Trade -> trade_stream_url

let named_obj1_encoding ~name ~encoding =
  let open Json_encoding in
  obj1 (req name encoding)

type error = {
  code : int option ;
  message : string ;
}

let error_encoding =
  let open Json_encoding in
  conv
    (fun { code ; message } ->
       match code with
       | None -> ("", message)
       | Some code -> (string_of_int code, message))
    (function
    | ("", message) -> { code = None ; message }
    | (code, message) -> { code = Some (int_of_string code) ; message })
    (obj2
       (dft "errorCode" string "")
       (req "errorMessage" string))

module Accounts = struct
  let list ~api =
    let url = url_of_api api in
    let url = Uri.with_path url "/v3/accounts" in
    Client.get ~headers:!headers url >>= fun (resp, body) ->
    Body.to_string body >>| fun body_str ->
    let body_json = Yojson.Safe.from_string body_str in
    if Cohttp.Code.(is_error (code_of_status resp.status)) then
      let error = Json.destruct
          (Json_encoding.list Account.Properties.encoding) body_json in
      Error error
    else
    let account = Json.destruct
        (Json_encoding.list Account.Properties.encoding) body_json in
    Ok account
end
