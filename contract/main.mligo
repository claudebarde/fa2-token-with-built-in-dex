#include "./partials/utils.mligo"
#include "./partials/interface.mligo"
#include "./partials/transfer.mligo"
#include "./partials/update_operators.mligo"
#include "./partials/balance_of.mligo"
#include "./partials/admin.mligo"
#include "./partials/mint_burn.mligo"
   
let main (action, s: parameter * storage): return =
    match action with
    | Transfer p -> ([]: operation list), transfer (p, s)
    | Update_operators p -> ([]: operation list), update_operators (p, s)
    | Balance_of p -> balance_of (p, s)
    | Mint p -> ([]: operation list), mint (p, s)
    | Update_whitelisted_minters p -> ([]: operation list), update_whitelisted_minters (p, s)
