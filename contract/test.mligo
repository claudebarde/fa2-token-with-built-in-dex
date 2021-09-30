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
        ledger              = (Big_map.literal [((admin, 0n), 1_000_000n); ((admin, 1n), 1_000_000n)]: ledger);
        metadata            = (Big_map.empty: (string, bytes) big_map);
        token_metadata      = (Big_map.literal [
                                        (0n, { token_id = 0n; token_info = (Map.empty: (string, bytes) map) });
                                        (1n, { token_id = 1n; token_info = (Map.empty: (string, bytes) map) })
                                    ]: token_metadata);
        operators           = (Big_map.empty: (((address * address) * token_id), unit) big_map);
        whitelisted_minters = (Big_map.empty: (address, unit) big_map);
        xtz_pool            = 1_000_000mutez;
        token_pool          = 1_000_000n;
        total_supply        = 1_000_000n;
        lqt_total           = 1_000_000n;
        lqt_token_id        = 1n;
        admin               = admin;
    } in
    let (taddr, _, _) = Test.originate main initial_storage 1tez in
    let contract_address = Tezos.address (Test.to_contract taddr) in
    let storage: storage = Test.get_storage taddr in
    let initial_total_supply = storage.total_supply in
    // checks that the contract has been originated properly
    let () = assert (storage.xtz_pool = 1tez) in
    // sets the contract address as an operator for the user
    let approve_param: update_operators_param list = [
            (Add_operator { owner = admin; operator = contract_address; token_id = 0n });
            (Add_operator { owner = admin; operator = contract_address; token_id = 1n })
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
    let () = Test.log("---------- Testing mint entrypoint ----------") in
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
    let () = Test.log("---------- Testing update_whitelisted_minters and mint entrypoints ----------") in
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
    let () = Test.log("---------- Testing transfer entrypoint ----------") in
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
    let () = Test.log("---------- Testing burn entrypoint ----------") in
    let to_burn: burn_params contract = Test.to_entrypoint "burn" taddr in
    let admin_balance: nat = 
        match Big_map.find_opt (admin, 0n) storage.ledger with
        | None -> let () = Test.log ("No balance") in 0n
        | Some b -> b
    in
    let amount_to_burn: nat = admin_balance / 10n in
    let balance_left: nat = abs (admin_balance - amount_to_burn) in
    let burn_param: burn_params = { owner = admin ; amount = amount_to_burn; token_id = 0n } in
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
    let admin_balance: nat = 
        match Big_map.find_opt (admin, 0n) storage.ledger with
        | None -> let () = Test.log ("No balance") in 0n
        | Some b -> b
    in
    let () = assert (admin_balance = balance_left) in
    // ADD LIQUIDITY
    let () = Test.log("---------- Testing add_liquidity entrypoint ----------") in
    let minLqtMinted = 100_000n in
    let maxTokensDeposited = 100_000n in
    let liquidity_param: add_liquidity = 
        { owner = admin; minLqtMinted = minLqtMinted; maxTokensDeposited = maxTokensDeposited; deadline = ("2021-09-28T11:59:24.348Z": timestamp) } in
    let to_add_liquidity: add_liquidity contract = Test.to_entrypoint "add_liquidity" taddr in
    let _ = match Test.transfer_to_contract to_add_liquidity liquidity_param 100_000mutez with
        | Success -> let () = Test.log ("Successful add liquidity operation") in true
        | Fail err -> 
            begin
                match err with
                | Rejected rej -> let () = Test.log ("rejected", rej) in false
                | Other -> let () = Test.log "other" in false
            end
    in
    let storage: storage = Test.get_storage taddr in
    let _ = assert (storage.xtz_pool = 1_100_000mutez) in
    // checks contract balance
    let contract_balance = 
        match Big_map.find_opt (contract_address, 0n) storage.ledger with
        | None -> let () = Test.log ("No balance") in 0n
        | Some b -> b in
    let _ = assert (contract_balance <= maxTokensDeposited) in
    // REMOVE LIQUIDITY
    let () = Test.log("---------- Testing remove_liquidity entrypoint ----------") in
    let admin_initial_tez_balance = Test.get_balance admin in
    // fetches admin's balance
    let admin_balance = 
        match Big_map.find_opt (admin, storage.lqt_token_id) storage.ledger with
        | None -> let () = Test.log ("No balance") in 0n
        | Some b -> b in
    let () = assert (admin_balance > 0n) in
    // builts parameter
    // xtz_withdrawn = ((lqtBurned * (mutez_to_natural s.xtz_pool)) / s.lqt_total)
    // xtz_withdrawn = ((1000000n * (2000000n)) / 2000000n)
    // tokens_withdrawn = lqtBurned * s.token_pool /  s.lqt_total
    // tokens_withdrawn = 1000000n * 2000000n / 2000000n
    let initial_storage = storage in
    let admin_initial_balance = admin_balance in
    let minXtzWithdrawn = 100_000mutez in
    let minTokensWithdrawn = 100_000n in
    let lqtBurned = 100_000n in
    let remove_liquidity_param: remove_liquidity = 
    { 
        to_                 = admin ; // recipient of the liquidity redemption
        lqtBurned           = lqtBurned ;  // amount of lqt owned by sender to burn
        minXtzWithdrawn     = minXtzWithdrawn ; // minimum amount of tez to withdraw
        minTokensWithdrawn  = minTokensWithdrawn ; // minimum amount of tokens to whitdw
        deadline            = ("2021-09-28T11:59:24.348Z": timestamp) ; // the time before which the request must be completed
    } in
    let to_remove_liquidity: remove_liquidity contract = Test.to_entrypoint "remove_liquidity" taddr in
    let _ = match Test.transfer_to_contract to_remove_liquidity remove_liquidity_param 0tez with
        | Success -> let () = Test.log ("Successful remove liquidity operation") in true
        | Fail err -> 
            begin
                match err with
                | Rejected rej -> let () = Test.log ("rejected", rej) in false
                | Other -> let () = Test.log "other" in false
            end
    in
    let storage: storage = Test.get_storage taddr in
    let admin_new_tez_balance = Test.get_balance admin in
    let _ = assert ((mutez_to_natural admin_new_tez_balance) >= ((mutez_to_natural admin_initial_tez_balance) + (mutez_to_natural minXtzWithdrawn))) in
    let _ = assert (storage.token_pool <= abs (initial_storage.token_pool - minTokensWithdrawn)) in
    let _ = assert (storage.lqt_total = abs (initial_storage.lqt_total - lqtBurned)) in
    // assert (storage.xtz_pool <= (initial_storage.xtz_pool - minXtzWithdrawn))
    // fetches admin's balance
    let admin_balance = 
        match Big_map.find_opt (admin, storage.lqt_token_id) storage.ledger with
        | None -> let () = Test.log ("No balance") in 0n
        | Some b -> b in
    // let _ = Test.log (admin_balance, admin_initial_balance + minTokensWithdrawn) in
    assert (admin_balance >= admin_initial_balance + minTokensWithdrawn)