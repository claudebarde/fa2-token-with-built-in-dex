#include "./partials/lqt_error_codes.mligo"
#include "./partials/interface.mligo"
#include "./partials/utils.mligo"
#include "./partials/transfer.mligo"
#include "./partials/update_operators.mligo"
#include "./partials/balance_of.mligo"
#include "./partials/admin.mligo"
#include "./partials/mint_burn.mligo"
#include "./partials/liquidity_functions.mligo"
   
let main (action, s: parameter * storage): return =
    match action with
    | Transfer p                    -> ([]: operation list), transfer (p, s)
    | Update_operators p            -> ([]: operation list), update_operators (p, s)
    | Balance_of p                  -> balance_of (p, s)
    | Mint p                        -> ([]: operation list), mint (p, s)
    | Burn p                        -> ([]: operation list), burn (p, s)
    | Update_whitelisted_minters p  -> ([]: operation list), update_whitelisted_minters (p, s)
    | Add_liquidity p               -> add_liquidity (p, s)
    | Remove_liquidity p            -> remove_liquidity (p, s)
    | Xtz_to_token p                -> xtz_to_token (p, s)
    | Token_to_xtz p                -> token_to_xtz (p, s)
    | Default                       -> ([]: operation list), default_ s

let test =
    let admin = Test.nth_bootstrap_account 0 in
    let user = Test.nth_bootstrap_account 1 in
    let () = Test.set_source admin in

    let initial_storage = 
    {
        ledger              = (Big_map.literal [((admin, 0n), 10_000_000n)]: ledger);
        metadata            = (Big_map.empty: (string, bytes) big_map);
        token_metadata      = (Big_map.literal [
                                        (0n, { token_id = 0n; token_info = (Map.empty: (string, bytes) map) });
                                        (1n, { token_id = 1n; token_info = (Map.empty: (string, bytes) map) })
                                    ]: token_metadata);
        operators           = (Big_map.empty: (((address * address) * token_id), unit) big_map);
        whitelisted_minters = (Big_map.empty: (address, unit) big_map);
        xtz_pool            = 1tez;
        token_pool          = 1_000_000n;
        total_supply        = 10_000_000n;
        lqt_total           = 1_000_000n;
        lqt_token_id        = 1n;
        admin               = admin;
    } in
    let (taddr, _, _) = Test.originate main initial_storage 1tez in
    let storage: storage = Test.get_storage taddr in
    let initial_total_supply = storage.total_supply in
    // checks that the contract has been originated properly
    let () = assert (storage.xtz_pool = 1tez) in
    // sets the contract address as an operator for the user
    let approve_param: update_operators_param list = [
            (Add_operator { owner = admin; operator = (Tezos.address (Test.to_contract taddr)); token_id = 0n });
            (Add_operator { owner = admin; operator = (Tezos.address (Test.to_contract taddr)); token_id = 1n })
        ] in
    let to_approve: (update_operators_param list) contract = Test.to_entrypoint "update_operators" taddr in
    let approved = match Test.transfer_to_contract to_approve approve_param 0tez with
    | Success -> true
    | Fail err -> 
        begin
            match err with
            | Rejected rej -> let () = Test.log ("rejected", rej) in false
            | Other -> let () = Test.log "other" in false
        end
    in
    let () = assert (approved = true) in
    // MINT entrypoint
    // this is supposed to fail as the admin address is not a whitelisted minter
    let mint_param: mint_params = { recipient = admin; amount = 1_000_000n; token_id = 0n } in
    let to_mint: mint_params contract = Test.to_entrypoint "mint" taddr in
    let () = Test.log("Expected to fail:") in
    let _ = match Test.transfer_to_contract to_mint mint_param 0tez with
    | Success -> true
    | Fail err -> 
        begin
            match err with
            | Rejected rej -> let () = Test.log ("rejected", rej) in false
            | Other -> let () = Test.log "other" in false
        end
    in
    // UPDATE_WHITELISTED_MINTERS entrypoint and MINT entrypoint
    let to_update_whitelisted_minters: address contract = Test.to_entrypoint "update_whitelisted_minters" taddr in
    let _ = match Test.transfer_to_contract to_update_whitelisted_minters admin 0tez with
    | Success -> true
    | Fail err -> 
        begin
            match err with
            | Rejected rej -> let () = Test.log ("rejected", rej) in false
            | Other -> let () = Test.log "other" in false
        end
    in
    let amt = 1_000_000n in
    let mint_param: mint_params = { recipient = admin; amount = amt; token_id = 0n } in
    let to_mint: mint_params contract = Test.to_entrypoint "mint" taddr in
    let _ = match Test.transfer_to_contract to_mint mint_param 0tez with
    | Success -> let () = Test.log ("Successful mint operation") in true
    | Fail err -> 
        begin
            match err with
            | Rejected rej -> let () = Test.log ("rejected", rej) in false
            | Other -> let () = Test.log "other" in false
        end
    in
    let storage: storage = Test.get_storage taddr in
    let () = assert (storage.total_supply = initial_total_supply + amt) in
    // TRANSFER
    // this will fail because of insufficient balance
    let amount_to_transfer = storage.total_supply + 1n in
    let new_transfer: transfer_param list = 
        [{ from_ = admin ; txs = [{ to_ = user ; token_id = 0n ; amount = amount_to_transfer }] }] in
    let to_transfer: (transfer_param list) contract = Test.to_entrypoint "transfer" taddr in
    let () = Test.log("Expected to fail:") in
    let _ = match Test.transfer_to_contract to_transfer new_transfer 0tez with
    | Success -> true
    | Fail err -> 
        begin
            match err with
            | Rejected rej -> let () = Test.log ("rejected", rej) in false
            | Other -> let () = Test.log "other" in false
        end
    in
    // this should work
    let amount_to_transfer = storage.total_supply / 2n in
    let new_transfer: transfer_param list = 
        [{ from_ = admin ; txs = [{ to_ = user ; token_id = 0n ; amount = amount_to_transfer }] }] in
    let to_transfer: (transfer_param list) contract = Test.to_entrypoint "transfer" taddr in
    let _ = match Test.transfer_to_contract to_transfer new_transfer 0tez with
    | Success -> let () = Test.log ("Successful transfer operation") in true
    | Fail err -> 
        begin
            match err with
            | Rejected rej -> let () = Test.log ("rejected", rej) in false
            | Other -> let () = Test.log "other" in false
        end
    in
    let storage: storage = Test.get_storage taddr in
    let user_balance: nat = 
        match Big_map.find_opt (user, 0n) storage.ledger with
        | None -> let () = Test.log ("No balance") in 0n
        | Some b -> b
    in
    let () = assert (user_balance = amount_to_transfer) in
    // BURN
    let to_burn: burn_params contract = Test.to_entrypoint "burn" taddr in
    let amount_to_burn: nat = user_balance / 10n in
    let balance_left: nat = abs (user_balance - amount_to_burn) in
    let burn_param: burn_params = { owner = admin ; amount = amount_to_burn; token_id = 0n } in
    let admin_balance: nat = 
        match Big_map.find_opt (admin, 0n) storage.ledger with
        | None -> let () = Test.log ("No balance") in 0n
        | Some b -> b
    in
    let _ = match Test.transfer_to_contract to_burn burn_param 0tez with
    | Success -> let () = Test.log ("Successful burn operation") in true
    | Fail err -> 
        begin
            match err with
            | Rejected rej -> let () = Test.log ("rejected", rej) in false
            | Other -> let () = Test.log "other" in false
        end
    in
    let storage: storage = Test.get_storage taddr in
    let user_balance: nat = 
        match Big_map.find_opt (admin, 0n) storage.ledger with
        | None -> let () = Test.log ("No balance") in 0n
        | Some b -> b
    in
    let () = assert (user_balance = balance_left) in
    // ADD LIQUIDITY
    let minLqtMinted = 1_000_000n in
    let maxTokensDeposited = 1_000_000n in
    let liquidity_param: add_liquidity = 
        { owner = admin; minLqtMinted = minLqtMinted; maxTokensDeposited = maxTokensDeposited; deadline = ("2021-09-28T11:59:24.348Z": timestamp) } in
    let to_add_liquidity: add_liquidity contract = Test.to_entrypoint "add_liquidity" taddr in
    let _ = match Test.transfer_to_contract to_add_liquidity liquidity_param 1tez with
    | Success -> let () = Test.log ("Successful add liquidity operation") in true
    | Fail err -> 
        begin
            match err with
            | Rejected rej -> let () = Test.log ("rejected", rej) in false
            | Other -> let () = Test.log "other" in false
        end
    in
    let storage: storage = Test.get_storage taddr in
    let _ = Test.log storage in
    assert (storage.xtz_pool = 2tez)