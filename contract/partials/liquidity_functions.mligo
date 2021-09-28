let add_liquidity (p, s: add_liquidity * storage): return =
    let { owner = owner ;
          minLqtMinted = minLqtMinted ;
          maxTokensDeposited = maxTokensDeposited ;
          deadline = deadline } = p in

    if Tezos.now >= deadline then
        (failwith error_THE_CURRENT_TIME_MUST_BE_LESS_THAN_THE_DEADLINE: return)
    else
        // the contract is initialized, use the existing exchange rate
        // mints nothing if the contract has been emptied, but that's OK
        let xtz_pool   : nat = mutez_to_natural s.xtz_pool in
        let nat_amount : nat = mutez_to_natural Tezos.amount  in
        let lqt_minted : nat = nat_amount * s.lqt_total  / xtz_pool in
        let tokens_deposited : nat = ceildiv (nat_amount * s.token_pool) xtz_pool in

        if tokens_deposited > maxTokensDeposited then
            (failwith error_MAX_TOKENS_DEPOSITED_MUST_BE_GREATER_THAN_OR_EQUAL_TO_TOKENS_DEPOSITED : return)
        else if lqt_minted < minLqtMinted then
            (failwith error_LQT_MINTED_MUST_BE_GREATER_THAN_MIN_LQT_MINTED : return)
        else
            let new_storage = { s with
                lqt_total  = s.lqt_total + lqt_minted ;
                token_pool = s.token_pool + tokens_deposited ;
                xtz_pool   = s.xtz_pool + Tezos.amount } in

            // send tokens from sender to exchange
            let op_token = token_transfer owner Tezos.self_address tokens_deposited 0n in
            // mint lqt tokens for them
            let op_lqt = mint_tokens lqt_minted s.lqt_token_id owner in

            ([op_token; op_lqt], new_storage)

let remove_liquidity (p, s: remove_liquidity * storage): return =
    let { to_ = to_ ;
          lqtBurned = lqtBurned ;
          minXtzWithdrawn = minXtzWithdrawn ;
          minTokensWithdrawn = minTokensWithdrawn ;
          deadline = deadline } = p in

    if Tezos.now >= deadline 
    then
      (failwith error_THE_CURRENT_TIME_MUST_BE_LESS_THAN_THE_DEADLINE : return)    
    else if Tezos.amount > 0mutez 
    then
        (failwith error_AMOUNT_MUST_BE_ZERO : return)
    else begin
        let xtz_withdrawn    : tez = natural_to_mutez ((lqtBurned * (mutez_to_natural s.xtz_pool)) / s.lqt_total) in
        let tokens_withdrawn : nat = lqtBurned * s.token_pool /  s.lqt_total in

        // Check that minimum withdrawal conditions are met
        if xtz_withdrawn < minXtzWithdrawn 
        then
            (failwith error_THE_AMOUNT_OF_XTZ_WITHDRAWN_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_XTZ_WITHDRAWN : return)
        else if tokens_withdrawn < minTokensWithdrawn
        then
            (failwith error_THE_AMOUNT_OF_TOKENS_WITHDRAWN_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_TOKENS_WITHDRAWN : return)
        // Proceed to form the operations and update the storage
        else 
            begin                                                                
                // calculate lqt_total, convert int to nat
                let new_lqt_total = match (is_a_nat (s.lqt_total - lqtBurned)) with
                    // This check should be unecessary, the fa12 logic normally takes care of it
                    | None -> (failwith error_CANNOT_BURN_MORE_THAN_THE_TOTAL_AMOUNT_OF_LQT : nat)
                    | Some n -> n in
                // Calculate token_pool, convert int to nat
                let new_token_pool = match is_a_nat (s.token_pool - tokens_withdrawn) with
                    | None -> (failwith error_TOKEN_POOL_MINUS_TOKENS_WITHDRAWN_IS_NEGATIVE : nat)
                    | Some n -> n in
                                    
                let op_lqt = burn_tokens lqtBurned s.lqt_token_id Tezos.sender in
                let op_token = token_transfer Tezos.self_address to_ tokens_withdrawn s.lqt_token_id in
                let op_xtz = xtz_transfer to_ xtz_withdrawn in
                let new_storage = { s with xtz_pool = s.xtz_pool - xtz_withdrawn ; lqt_total = new_lqt_total ; token_pool = new_token_pool } in
                ([op_lqt; op_token; op_xtz], new_storage)
            end
    end

let xtz_to_token (p, s: xtz_to_token * storage) =
   let { to_ = to_ ;
         minTokensBought = minTokensBought ;
         deadline = deadline } = p in

    if Tezos.now >= deadline then
        (failwith error_THE_CURRENT_TIME_MUST_BE_LESS_THAN_THE_DEADLINE : return)    
    else begin
        // we don't check that xtz_pool > 0, because that is impossible
        // unless all liquidity has been removed
        let xtz_pool = mutez_to_natural s.xtz_pool in
        let nat_amount = mutez_to_natural Tezos.amount in

	let amount_net_burn = (nat_amount * 999n) / 1000n in
	let burn_amount = abs (nat_amount - amount_net_burn) in
	
	let tokens_bought =
            (let bought = (amount_net_burn * fee * s.token_pool) / (xtz_pool * 1000n + (amount_net_burn * fee)) in
            if bought < minTokensBought then
                (failwith error_TOKENS_BOUGHT_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_TOKENS_BOUGHT : nat)
            else
                bought)
        in
        let new_token_pool = (match is_nat (s.token_pool - tokens_bought) with
            | None -> (failwith error_TOKEN_POOL_MINUS_TOKENS_BOUGHT_IS_NEGATIVE : nat)
            | Some difference -> difference) in

        // update xtz_pool
        let new_storage = { s with
                        xtz_pool = s.xtz_pool + (natural_to_mutez amount_net_burn);
                        token_pool = new_token_pool } in
        // send tokens_withdrawn to to address
        // if tokens_bought is greater than storage.tokenPool, this will fail
        let op = token_transfer Tezos.self_address to_ tokens_bought s.lqt_token_id in
        let op_burn = xtz_transfer null_address (natural_to_mutez burn_amount) in
	([ op ; op_burn], new_storage)
    end

let token_to_xtz (p, s: token_to_xtz * storage) =
    let { to_ = to_ ;
          tokensSold = tokensSold ;
          minXtzBought = minXtzBought ;
          deadline = deadline } = p in

    if Tezos.now >= deadline then
        (failwith error_THE_CURRENT_TIME_MUST_BE_LESS_THAN_THE_DEADLINE : return)    
    else if Tezos.amount > 0mutez then
        (failwith error_AMOUNT_MUST_BE_ZERO : return)
    else
        // we don't check that tokenPool > 0, because that is impossible
        // unless all liquidity has been removed
        let xtz_bought = natural_to_mutez (((tokensSold * fee * (mutez_to_natural s.xtz_pool)) / (s.token_pool * 1000n + (tokensSold * fee)))) in
       
        let xtz_bought_net_burn =
            let bought = (xtz_bought * 999n) / 1000n in
            if bought < minXtzBought 
            then (failwith error_XTZ_BOUGHT_MUST_BE_GREATER_THAN_OR_EQUAL_TO_MIN_XTZ_BOUGHT : tez) 
            else bought in

        let op_token = token_transfer Tezos.sender Tezos.self_address tokensSold s.lqt_token_id in
        let op_tez = xtz_transfer to_ xtz_bought_net_burn in
        let storage = { s with token_pool = s.token_pool + tokensSold ;
                                    xtz_pool = s.xtz_pool - xtz_bought } in

        let burn_amount = xtz_bought - xtz_bought_net_burn in
        let op_burn = xtz_transfer null_address burn_amount in
        ([op_token ; op_tez; op_burn], storage)

// entrypoint to allow depositing funds
let default_ (s: storage): storage =  { s with xtz_pool = s.xtz_pool + Tezos.amount }
