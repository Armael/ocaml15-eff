module type S = sig
  type 'a cont
  effect Suspend  : ('a cont -> unit) -> 'a
  effect Resume   : ('a cont * 'a) -> unit
  val suspend : ('a cont -> unit) -> 'a
  val resume  : 'a cont -> 'a -> unit
  val fork    : (unit -> unit) -> unit
  val fork_on : (unit -> unit) -> int -> unit
  val yield   : unit -> unit
  val get_tid : unit -> int
  val run     : (unit -> unit) -> unit
end

module Make (S : sig val num_domains : int end) : S = struct

  type queue_num = int
  type 'a cont = ('a, unit) continuation * queue_num

  effect Fork     : (unit -> unit) -> unit
  effect Yield    : unit
  effect Suspend  : ('a cont -> unit) -> 'a
  effect Resume   : ('a cont * 'a) -> unit
  effect GetTid   : int

  let fork f      = perform (Fork f)
  let yield ()    = perform Yield
  let suspend f   = perform (Suspend f)
  let resume t v  = perform (Resume (t, v))
  let get_tid ()  = perform GetTid

  effect ForkOn     : (unit -> unit) * int -> unit
  effect NumDomains : int

  let fork_on f dom_id = perform (ForkOn (f, dom_id))
  let num_domains () = perform NumDomains

  open CAS.Sugar

  let num_threads = ref 0

  let sq = Array.init S.num_domains (fun _ -> MSQueue.create ())

  let fresh_tid () = Oo.id (object end)

  let enqueue c dom_id = MSQueue.push (Array.get sq dom_id) c

  let rec dequeue_wid dom_id =
    let b = Backoff.create () in
    let queue = Array.get sq dom_id in
    let rec loop () = match MSQueue.pop queue with
      | Some k -> continue k ()
      | None ->
          if !num_threads = 0 then ()
          else ( Backoff.once b ; loop () )
    in loop ()
  and dequeue () = dequeue_wid (Domain.self ())
  and spawn f (tid:int) =
    CAS.incr num_threads;
    begin
      match f () with
      | () -> (CAS.decr num_threads; dequeue ())
      | effect (Fork f) k -> enqueue k (Domain.self ()); spawn f (fresh_tid ())
      | effect Yield k -> enqueue k (Domain.self ()); dequeue ()
      | effect (Suspend f) k -> f (k, Domain.self()); dequeue ()
      | effect (Resume ((t,qid), v)) k -> enqueue k qid; continue t v
      | effect GetTid k -> continue k tid
      | effect NumDomains k -> continue k (S.num_domains)
      | effect (ForkOn (f, dom_id)) k ->
          (enqueue k dom_id; spawn f (fresh_tid ()))
    end

  let run_with f num_domains =
    let started = ref 0 in
    let worker () =
      let b = Backoff.create ~max:16 () in
      let rec loop () =
        if !started = 1 then dequeue ()
        else (Backoff.once b; loop ())
      in loop ()
    in
    for i = 1 to num_domains - 1 do
      Domain.spawn worker
    done ;
    spawn (fun () -> CAS.incr started; f ()) (fresh_tid ())

  let run f = run_with f S.num_domains

end
