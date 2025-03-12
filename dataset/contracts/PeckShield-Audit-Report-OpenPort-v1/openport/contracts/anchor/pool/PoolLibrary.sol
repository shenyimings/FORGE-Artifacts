// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../../math/SafeMath.sol";

library PoolLibrary {
    using SafeMath for uint256;

    // Constants for various precisions
    uint256 private constant PRICE_PRECISION = 1e6;

    // ================ Structs ================
    // Needed to lower stack size
    struct MintFF_Params {
        uint256 gr_price_anchor;
        uint256 col_price_anchor;
        uint256 gr_amount;
        uint256 collateral_amount;
        uint256 col_ratio;
    }

    struct BuybackGr_Params {
        uint256 excess_collateral_dollar_value_d18;
        uint256 gr_price_anchor;
        uint256 col_price_anchor;
        uint256 Gr_amount;
    }

    // ================ Functions ================

    function calcMint1t1Synth(uint256 col_price, uint256 collateral_amount_d18) public pure returns (uint256) {
        return (collateral_amount_d18.mul(col_price)).div(1e6);
    }

    function calcMintAlgorithmicSynth(uint256 gr_price_anchor, uint256 gr_amount_d18) public pure returns (uint256) {
        return gr_amount_d18.mul(gr_price_anchor).div(1e6);
    }

    // Must be internal because of the struct
    function calcMintFractionalSynth(MintFF_Params memory params) internal pure returns (uint256, uint256) {
        // Since solidity truncates division, every division operation must be the last operation in the equation to ensure minimum error
        // The contract must check the proper ratio was sent to mint Anchor. We do this by seeing the minimum mintable Anchor based on each amount 
        uint256 gr_dollar_value_d18;
        uint256 c_dollar_value_d18;
        
        // Scoping for stack concerns
        {    
            // Anchor amounts of the collateral and the Gr
            gr_dollar_value_d18 = params.gr_amount.mul(params.gr_price_anchor).div(1e6);
            c_dollar_value_d18 = params.collateral_amount.mul(params.col_price_anchor).div(1e6);

        }
        uint calculated_gr_dollar_value_d18 = 
                    (c_dollar_value_d18.mul(1e6).div(params.col_ratio))
                    .sub(c_dollar_value_d18);

        uint calculated_gr_needed = calculated_gr_dollar_value_d18.mul(1e6).div(params.gr_price_anchor);

        return (
            c_dollar_value_d18.add(calculated_gr_dollar_value_d18),
            calculated_gr_needed
        );
    }

    function calcRedeem1t1Synth(uint256 col_price_anchor, uint256 synth_amount) public pure returns (uint256) {
        return synth_amount.mul(1e6).div(col_price_anchor);
    }

    // Must be internal because of the struct
    function calcBuyBackGr(BuybackGr_Params memory params) internal pure returns (uint256) {
        // If the total collateral value is higher than the amount required at the current collateral ratio then buy back up to the possible Gr with the desired collateral
        require(params.excess_collateral_dollar_value_d18 > 0, "No excess collateral to buy back!");

        // Make sure not to take more than is available
        uint256 gr_dollar_value_d18 = params.Gr_amount.mul(params.gr_price_anchor).div(1e6);
        require(gr_dollar_value_d18 <= params.excess_collateral_dollar_value_d18, "You are trying to buy back more than the excess!");

        // Get the equivalent amount of collateral based on the market value of Gr provided 
        uint256 collateral_equivalent_d18 = gr_dollar_value_d18.mul(1e6).div(params.col_price_anchor);
        //collateral_equivalent_d18 = collateral_equivalent_d18.sub((collateral_equivalent_d18.mul(params.buyback_fee)).div(1e6));

        return (
            collateral_equivalent_d18
        );

    }


    // Returns value of collateral that must increase to reach recollateralization target (if 0 means no recollateralization)
    function recollateralizeAmount(uint256 total_supply, uint256 global_collateral_ratio, uint256 global_collat_value) public pure returns (uint256) {
        uint256 target_collat_value = total_supply.mul(global_collateral_ratio).div(1e6); // We want 18 decimals of precision so divide by 1e6; total_supply is 1e18 and global_collateral_ratio is 1e6
        // Subtract the current value of collateral from the target value needed, if higher than 0 then system needs to recollateralize
        return target_collat_value.sub(global_collat_value); // If recollateralization is not needed, throws a subtraction underflow
        // return(recollateralization_left);
    }

    function calcRecollateralizeSynthInner(
        uint256 collateral_amount, 
        uint256 col_price,
        uint256 global_collat_value,
        uint256 synth_total_supply,
        uint256 global_collateral_ratio
    ) public pure returns (uint256, uint256) {
        uint256 collat_value_attempted = collateral_amount.mul(col_price).div(1e6);
        uint256 effective_collateral_ratio = global_collat_value.mul(1e6).div(synth_total_supply); //returns it in 1e6
        uint256 recollat_possible = (global_collateral_ratio.mul(synth_total_supply).sub(synth_total_supply.mul(effective_collateral_ratio))).div(1e6);

        uint256 amount_to_recollat;
        if(collat_value_attempted <= recollat_possible){
            amount_to_recollat = collat_value_attempted;
        } else {
            amount_to_recollat = recollat_possible;
        }

        return (amount_to_recollat.mul(1e6).div(col_price), amount_to_recollat);

    }

}