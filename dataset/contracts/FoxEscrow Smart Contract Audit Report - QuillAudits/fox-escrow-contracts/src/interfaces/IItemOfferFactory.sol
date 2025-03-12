// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./IItemOffer.sol";

interface IItemOfferFactory {
    function xFoxAddress() external view returns (address);
    function devAddress() external view returns (address);
    function escrowMultisigFeeAddress() external view returns (address);
    function offers() external view returns (IItemOffer[] memory);
    function getActiveOffers() external view returns (IItemOffer[] memory);
    function logTransactionVolume(uint256 amount) external;
}
