open Core
open Async

open Cohttp_async
module Json = Json_encoding.Make(Json_repr.Yojson)

open Oanda

let headers = ref @@ Cohttp.Header.init ()

let init ~user_agent ~token =
  headers := Cohttp.Header.of_list [
      "User-Agent", user_agent ;
      "Authorization", "Bearer " ^ token
    ]

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

module Account = struct
  let list ?log api =
    let encoding =
      let open Json_encoding in
      obj1 (req "accounts"
              (Json_encoding.list Account.Properties.encoding)) in
    let url = url_of_api api in
    let url = Uri.with_path url "/v3/accounts" in
    Client.get ~headers:!headers url >>= fun (resp, body) ->
    Body.to_string body >>| fun body_str ->
    Option.iter log ~f:(fun log -> Log.debug log "BODY: %s" body_str) ;
    let body_json = Yojson.Safe.from_string body_str in
    if Cohttp.Code.(is_error (code_of_status resp.status)) then
      let error = Json.destruct error_encoding body_json in
      Error error
    else
    let account = Json.destruct encoding body_json in
    Ok account

  let price
      ?(buf=Bi_outbuf.create 1024)
      ?log ?since ~account ~instruments api =
    let encoding =
      Json_encoding.(obj1 (req "prices" (list Price.encoding))) in
    let headers =
      Cohttp.Header.add !headers "Accept-Datetime-Format" "RFC3339" in
    let url = url_of_api api in
    let url = Uri.with_path url
        ("/v3/accounts/" ^ Account.Id.to_string account ^ "/pricing") in
    let instruments = List.map instruments ~f:Instrument.name_to_string in
    let url = Uri.with_query url @@ List.filter_opt [
        Option.map since
          ~f:(fun since -> "since", [Ptime.to_rfc3339 since]);
        Some ("instruments", instruments) ;
      ] in
    Option.iter log ~f:(fun log -> Log.debug log "URI: %s" (Uri.to_string url)) ;
    Client.get ~headers url >>= fun (resp, body) ->
    Body.to_string body >>| fun body_str ->
    Option.iter log ~f:(fun log -> Log.debug log "BODY: %s" body_str) ;
    if Cohttp.Code.(is_error (code_of_status resp.status)) then begin
      Option.iter log ~f:(fun log -> Log.debug log "ERROR: %d"
                             (Cohttp.Code.code_of_status resp.status)) ;
      let body_json = Yojson.Safe.from_string body_str in
      let error = Json.destruct error_encoding body_json in
      Error error
    end
    else
    let body_json = Yojson.Safe.from_string body_str in
    let account = Json.destruct encoding body_json in
    Ok account
end
