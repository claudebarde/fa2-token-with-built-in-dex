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
    | Transfer p -> ([]: operation list), transfer (p, s)
    | Update_operators p -> ([]: operation list), update_operators (p, s)
    | Balance_of p -> balance_of (p, s)
    | Mint p -> ([]: operation list), mint (p, s)
    | Burn p -> ([]: operation list), burn (p, s)
    | Update_whitelisted_minters p -> ([]: operation list), update_whitelisted_minters (p, s)
    | Add_liquidity p -> add_liquidity (p, s)
    | Remove_liquidity p -> remove_liquidity (p, s)
