// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMaGaugeStruct {
    struct MaGauge {
        bool active;
        bool stablePair;
        address pair;
        address token0;
        address token1;
        address maGaugeAddress;
        string name;
        string symbol;
        uint maGaugeId;
    }


    struct MaNftInfo {
        // pair info
        uint token_id;
        string name;
        string symbol;
        address pair_address; 			// pair contract address
        address vault_address;      //dyson vault address if it's a cl gauge
        address gauge;  		// maGauge contract address
        address owner;
        uint lp_balance;
        uint weight;
        uint emissions_claimable;
        uint maturity_time;
        uint maturity_multiplier;
    }
}
