// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./ILockedTokenOffer.sol";

interface IOfferFactory {
    function xFoxAddress() external view returns (address);
    function devAddress() external view returns (address);
    function escrowMultisigFeeAddress() external view returns (address);
    function offers() external view returns (ILockedTokenOffer[] memory);
    function getActiveOffers() external view returns (ILockedTokenOffer[] memory);
    function logTransactionVolume(uint256 amount) external;
}
