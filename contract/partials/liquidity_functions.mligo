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
            let op_token = token_transfer new_storage Tezos.sender Tezos.self_address tokens_deposited s.lqt_token_id in
            // mint lqt tokens for them
            let op_lqt = mint_tokens lqt_minted s.lqt_token_id Tezos.sender in

            ([op_token; op_lqt], new_storage)
