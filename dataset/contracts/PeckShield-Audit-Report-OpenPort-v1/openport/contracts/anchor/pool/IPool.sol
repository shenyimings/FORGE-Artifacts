// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IPool {
    function minting_fee() external view returns (uint256);
    function redemption_fee() external view returns (uint256);
    function buyback_fee() external view returns (uint256);
    function recollat_fee() external view returns (uint256);
    function collatAnchorBalance() external view returns (uint256);
    function availableExcessCollatDV() external view returns (uint256);
    function getCollateralPrice() external view returns (uint256);
    function setCollatBNBOracle(address _collateral_wbnb_oracle_address, address _wbnb_address) external;
    function mint1t1Synth(uint256 collateral_amount, uint256 anchor_out_min) external;
    function mintAlgorithmicSynth(uint256 gr_amount_d18, uint256 anchor_out_min) external;
    function mintFractionalSynth(uint256 collateral_amount, uint256 gr_amount, uint256 anchor_out_min) external;
    function redeem1t1Synth(uint256 anchor_amount, uint256 COLLATERAL_out_min) external;
    function redeemFractionalSynth(uint256 anchor_amount, uint256 Gr_out_min, uint256 COLLATERAL_out_min) external;
    function redeemAlgorithmicSynth(uint256 anchor_amount, uint256 Gr_out_min) external;
    function collectRedemption() external;
    function recollateralizeSynth(uint256 collateral_amount, uint256 Gr_out_min) external;
    function buyBackGr(uint256 Gr_amount, uint256 COLLATERAL_out_min) external;
    function toggleMinting() external;
    function toggleRedeeming() external;
    function toggleRecollateralize() external;
    function toggleBuyBack() external;
    function toggleCollateralPrice(uint256 _new_price) external;
    function setPoolParameters(uint256 new_ceiling, uint256 new_bonus_rate, uint256 new_redemption_delay, uint256 new_mint_fee, uint256 new_redeem_fee, uint256 new_buyback_fee, uint256 new_recollat_fee) external;
    function setTimelock(address new_timelock) external;
}