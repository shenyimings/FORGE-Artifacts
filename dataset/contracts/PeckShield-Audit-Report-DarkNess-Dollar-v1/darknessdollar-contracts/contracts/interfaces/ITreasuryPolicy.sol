// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ITreasuryPolicy {
    function minting_fee() external view returns (uint256);

    function redemption_fee() external view returns (uint256);

    function reserve_share_state() external view returns (uint8);

    function setMintingFee(uint256 _minting_fee) external;

    function setRedemptionFee(uint256 _redemption_fee) external;
}
