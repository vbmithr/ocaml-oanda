(*---------------------------------------------------------------------------
   Copyright (c) 2017 Vincent Bernardoff. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)

let ptime_encoding =
  let open Json_encoding in
  conv
    (fun t -> Ptime.to_rfc3339 t)
    (fun s ->
       match Ptime.of_rfc3339 s with
       | Ok (t, _, _) -> t
       | Error _ -> invalid_arg "ptime_encoding")
    string

let decimal_encoding =
  Json_encoding.(conv string_of_float float_of_string string)

module Account = struct
  module Id = struct
    type t = {
      site : int ;
      division : int ;
      user : int ;
      account : int ;
    }

    let of_string s =
      let vs = String.split_on_char '-' s in
      match ListLabels.map vs ~f:int_of_string with
      | exception _ -> None
      | [ site ; division ; user ; account ] ->
          Some { site ; division ; user ; account }
      | _ -> None

    let to_string { site ; division ; user ; account } =
      Printf.sprintf "%d-%d-%d-%d" site division user account

    let encoding =
      let open Json_encoding in
      conv
        to_string
        (fun s -> match of_string s with
          | Some a -> a
          | None -> invalid_arg "AccountID.encoding")
        string
  end

  module Properties = struct
    type t = {
      id : Id.t ;
      mt4AccountID : int ;
      tags : string list ;
    }

    let encoding =
      let open Json_encoding in
      conv
        (fun { id ; mt4AccountID ; tags } -> (id, mt4AccountID, tags))
        (fun (id, mt4AccountID, tags) -> { id ; mt4AccountID ; tags })
        (obj3
           (req "id" Id.encoding)
           (dft "mt4AccountID" int 0)
           (dft "tags" (list string) []))
  end
end

module Instrument = struct
  type name = {
    base : string ;
    quote : string ;
  }

  let name_of_string s =
    match String.split_on_char '_' s with
    | exception _ -> None
    | [ base ; quote ] -> Some { base ; quote }
    | _ -> None

  let name_to_string { base ; quote } = base ^ "_" ^ quote

  let name_encoding =
    let open Json_encoding in
    conv
      name_to_string
      (fun s -> match name_of_string s with
        | Some a -> a
        | None -> invalid_arg "Instrument.name.encoding")
      string

  type kind = Currency | Cfd | Metal
  let kind_of_string = function
  | "CURRENCY" -> Some Currency
  | "CFD" -> Some Cfd
  | "METAL" -> Some Metal
  | _ -> None

  let kind_to_string = function
  | Currency -> "CURRENCY"
  | Cfd -> "CFD"
  | Metal -> "METAL"

  let kind_encoding =
    let open Json_encoding in
    conv
      kind_to_string
      (fun s -> match kind_of_string s with
        | Some a -> a
        | None -> invalid_arg "Instrument.kind.encoding")
      string

  type t = {
    base : string ;
    quote : string ;
    kind : kind ;
    displayName : string ;
    pipLocation : int ;
    displayPrecision : int ;
    tradeUnitsPrecision : int ;
    minimumTradeSize : float ;
    maximumTrailingStopDistance : float ;
    minimumTrailingStopDistance : float ;
    maximumPositionSize : float ;
    maximumOrderUnits : float ;
    marginRate : float ;
  }
end

module Price = struct
  type status = Tradeable | Non_tradeable | Invalid

  let status_of_string = function
  | "tradeable" -> Some Tradeable
  | "non-tradeable" -> Some Non_tradeable
  | "invalid" -> Some Invalid
  | _ -> None

  let status_to_string = function
  | Tradeable -> "tradeable"
  | Non_tradeable -> "non-tradeable"
  | Invalid -> "invalid"

  let status_encoding =
    let open Json_encoding in
    conv
      status_to_string
      (fun s -> match status_of_string s with
        | Some a -> a
        | None -> invalid_arg "Price.status.encoding")
      string

  type bucket = {
    price : float ;
    liquidity : int ;
  }

  let bucket_encoding =
    let open Json_encoding in
    conv
      (fun { price ; liquidity } -> (price, liquidity))
      (fun (price, liquidity) -> { price ; liquidity })
      (obj2
         (req "price" decimal_encoding)
         (req "liquidity" int))

  type quote_home = {
    positive : float ;
    negative : float ;
  }

  let quote_home_encoding =
    let open Json_encoding in
    conv
      (fun { positive ; negative } -> positive, negative)
      (fun (positive, negative) -> { positive ; negative })
      (obj2
         (req "positiveUnits" decimal_encoding)
         (req "negativeUnits" decimal_encoding))

  type available_detail = {
    default : float ;
    reduceFirst : float ;
    reduceOnly : float ;
    openOnly : float ;
  }

  let available_detail_encoding =
    let open Json_encoding in
    conv
      (fun { default ; reduceFirst ; reduceOnly ; openOnly } ->
         (default, reduceFirst, reduceOnly, openOnly))
      (fun (default, reduceFirst, reduceOnly, openOnly) ->
         { default ; reduceFirst ; reduceOnly ; openOnly })
      (obj4
        (req "default" decimal_encoding)
        (req "reduceFirst" decimal_encoding)
        (req "reduceOnly" decimal_encoding)
        (req "openOnly" decimal_encoding))

  type available = {
    long : available_detail ;
    short : available_detail ;
  }

  let available_encoding =
    let open Json_encoding in
    conv
      (fun { long ; short } -> long, short)
      (fun (long, short) -> { long ; short })
      (obj2
         (req "long" available_detail_encoding)
         (req "short" available_detail_encoding))

  type t = {
    base : string ;
    quote : string ;
    timestamp : Ptime.t ;
    status : status ;
    bids : bucket list ;
    asks : bucket list ;
    closeoutBid : float ;
    closeoutAsk : float ;
    quote_home : quote_home ;
    available : available ;
  }

  let encoding =
    let open Json_encoding in
    conv
      (fun { base ; quote ; timestamp ; status ;
             bids ; asks ; closeoutBid ; closeoutAsk ; quote_home ; available } ->
        ("PRICE", { Instrument.base ; quote }, timestamp, status, bids,
         asks, closeoutBid, closeoutAsk, quote_home, available))
      (fun (_, { base ; quote }, timestamp, status, bids,
            asks, closeoutBid, closeoutAsk, quote_home, available) ->
        { base ; quote ; timestamp ; status ;
          bids ; asks ; closeoutBid ; closeoutAsk ; quote_home ;
          available })
      (obj10
         (req "type" string)
         (req "instrument" Instrument.name_encoding)
         (req "time" ptime_encoding)
         (req "status" status_encoding)
         (req "bids" (list bucket_encoding))
         (req "asks" (list bucket_encoding))
         (req "closeoutBid" decimal_encoding)
         (req "closeoutAsk" decimal_encoding)
         (req "quoteHomeConversionFactors" quote_home_encoding)
         (req "unitsAvailable" available_encoding))
end

(*---------------------------------------------------------------------------
   Copyright (c) 2017 Vincent Bernardoff

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
