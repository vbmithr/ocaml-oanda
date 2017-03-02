open Core.Std
open Async.Std
open Oanda

val init : user_agent:string -> token:string -> unit

type api = Practice | Trade

type error = {
  code : int option ;
  message : string ;
}

module Account : sig
  val list :
    ?log:Log.t ->
    api ->
    (Account.Properties.t list, error) Result.t Deferred.t

  val price :
    ?buf:Bi_outbuf.t ->
    ?log:Log.t ->
    ?since:Ptime.t ->
    account:Account.Id.t ->
    instruments:Instrument.name list ->
    api -> (Price.t list, error) Result.t Deferred.t
end
