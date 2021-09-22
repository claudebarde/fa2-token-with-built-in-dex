let mutez_to_natural (a: tez) : nat =  a / 1mutez

let natural_to_mutez (a: nat): tez = a * 1mutez  

let is_a_nat (i : int) : nat option = Michelson.is_nat i

let ceildiv (numerator : nat) (denominator : nat) : nat =
    match (ediv numerator denominator) with
    | None   -> (failwith("DIV by 0") : nat)
    | Some v ->  let (q, r) = v in if r = 0n then q else q + 1n

[@inline]
let token_transfer (storage: storage) (from: address) (to_: address) (token_amount: nat) (token_id: token_id) : operation =
    let token_contract: (transfer_param list) contract =
        match (Tezos.get_entrypoint_opt "%transfer" Tezos.self_address : (transfer_param list) contract option) with
        | None -> (failwith error_TOKEN_CONTRACT_MUST_HAVE_A_TRANSFER_ENTRYPOINT : (transfer_param list) contract)
        | Some contract -> contract in
    let param: transfer_param list = [{ from_ = from; txs = [{to_ = to_; token_id = token_id; amount = token_amount }] }] in
    Tezos.transaction param 0mutez token_contract

[@inline]
let xtz_transfer (to_ : address) (amount_ : tez) : operation =
    let to_contract : unit contract =
    match (Tezos.get_contract_opt to_ : unit contract option) with
    | None -> (failwith error_INVALID_TO_ADDRESS : unit contract)
    | Some c -> c in
    Tezos.transaction () amount_ to_contract

[@inline]
let mint_tokens (token_amount: nat) (token_id: nat) (recipient: address) : operation =
    let token_contract: mint_params contract =
        match (Tezos.get_entrypoint_opt "%mint" Tezos.self_address : mint_params contract option) with
        | None -> (failwith "NO_MINT_ENTRYPOINT" : mint_params contract)
        | Some contract -> contract in
    let param: mint_params = { recipient = recipient; amount = token_amount; token_id = token_id } in
    Tezos.transaction param 0mutez token_contract

