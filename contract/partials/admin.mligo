let update_whitelisted_minters (minter, s: address * storage): storage =
    if Tezos.sender <> s.admin
    then (failwith "NOT_AN_ADMIN": storage)
    else
        if Big_map.mem minter s.whitelisted_minters
        then { s with whitelisted_minters = Big_map.remove minter s.whitelisted_minters }
        else { s with whitelisted_minters = Big_map.add minter unit s.whitelisted_minters }