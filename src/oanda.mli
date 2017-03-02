(*---------------------------------------------------------------------------
   Copyright (c) 2017 Vincent Bernardoff. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)

(**  OANDA APIv20 bindings

    {e %%VERSION%% — {{:%%PKG_HOMEPAGE%% }homepage}} *)

(** {1 Oanda} *)

module Account : sig
  module Id : sig
    type t = {
      site : int ;
      division : int ;
      user : int ;
      account : int ;
    }

    val of_string : string -> t option
    val to_string : t -> string
    val encoding : t Json_encoding.encoding
  end

  module Properties : sig
    type t = {
      id : Id.t ;
      mt4AccountID : int ;
      tags : string list ;
    }

    val encoding : t Json_encoding.encoding
  end
end

module Instrument : sig
  type name = {
    base : string ;
    quote : string ;
  }

  val create_name : base:string -> quote:string -> name
  val name_of_string : string -> name option
  val name_to_string : name -> string
  val name_encoding : name Json_encoding.encoding
end

module Price : sig
  type bucket = {
    price : float ;
    liquidity : int ;
  }

  type t = {
    base : string ;
    quote : string ;
    timestamp : Ptime.t ;
    tradeable : bool ;
    bids : bucket list ;
    asks : bucket list ;
    closeoutBid : float ;
    closeoutAsk : float ;
  }

  val encoding : t Json_encoding.encoding
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
