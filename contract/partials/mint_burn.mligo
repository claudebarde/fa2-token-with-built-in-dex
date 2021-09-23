let mint (p, s: mint_params * storage): storage =
    if not Big_map.mem Tezos.sender s.whitelisted_minters
    then (failwith "UNAUTHORIZED_MINTER": storage)
    else if not Big_map.mem p.token_id s.token_metadata
    then (failwith "FA2_TOKEN_UNDEFINED": storage)
    else
        let { recipient = recipient; amount = amt; token_id = token_id } = p in
        let new_ledger: ledger =
            match Big_map.find_opt (recipient, token_id) s.ledger with
            | None -> Big_map.add (recipient, token_id) amt s.ledger
            | Some b -> Big_map.update (recipient, token_id) (Some (b + amt)) s.ledger
        in { s with ledger = new_ledger; total_supply = s.total_supply + amt }

let burn (p, s: burn_params * storage): storage =
    if Tezos.sender <> s.admin
    then (failwith "NOT_AN_ADMIN": storage)
    else
        let new_ledger: ledger =
            match Big_map.find_opt (p.owner, p.token_id) s.ledger with
            | None -> s.ledger
            | Some b -> 
                if p.amount > b
                then (failwith "INSUFFICIENT_TOKENS_TO_BURN": ledger)
                else Big_map.update (p.owner, p.token_id) (Some (abs(b - p.amount))) s.ledger
        in { s with ledger = new_ledger }