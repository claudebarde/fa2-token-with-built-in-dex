// EQUALITY

type numbers =
| Int of int * int
| Nat of nat * nat
| Tez of tez * tez

let is_equal (p: numbers): unit =
    match p with
    | Int (first, second) -> assert (first = second)
    | Nat (first, second) -> assert (first = second)
    | Tez (first, second) -> assert (first = second)

let is_greater (p: numbers): unit =
    match p with
    | Int (first, second) -> assert (first = second)
    | Nat (first, second) -> assert (first = second)
    | Tez (first, second) -> assert (first = second)

let is_greater_or_equal (p: numbers): unit =
    match p with
    | Int (first, second) -> assert (first = second)
    | Nat (first, second) -> assert (first = second)
    | Tez (first, second) -> assert (first = second)

let is_less (p: numbers): unit =
    match p with
    | Int (first, second) -> assert (first = second)
    | Nat (first, second) -> assert (first = second)
    | Tez (first, second) -> assert (first = second)

let is_less_or_equal (p: numbers): unit =
    match p with
    | Int (first, second) -> assert (first = second)
    | Nat (first, second) -> assert (first = second)
    | Tez (first, second) -> assert (first = second)

// DIFFERENCE

let diff_nat (first: nat) (second: nat): nat =
    if first > second
    then abs (first - second)
    else abs (second - first)

let diff_int (first: int) (second: int): nat =
    if first > second
    then abs (first - second)
    else abs (second - first)

let diff_tez (first: tez) (second: tez): tez =
    if first > second
    then first - second
    else second - first

// TOKENS

let fetch_balance (user: address) (token_id: token_id) (ledger: ledger): nat =
    match Big_map.find_opt (user, token_id) ledger with
    | None -> 0n
    | Some b -> b
