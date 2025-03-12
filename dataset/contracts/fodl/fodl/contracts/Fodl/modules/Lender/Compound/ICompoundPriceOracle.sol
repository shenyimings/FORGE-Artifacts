// SPDX-License-Identifier: MIT

// Taken from: https://github.com/studydefi/money-legos/blob/abae7f0c2be3bb32a820ca182433872570037042/src/compound/contracts/ICompoundPriceOracle.sol

pragma solidity 0.6.12;

/// @dev Interface of the ERC20 standard as defined in the EIP.
interface ICompoundPriceOracle {
    function getUnderlyingPrice(address cToken) external view returns (uint256);

    function price(string calldata symbol) external view returns (uint256);
}
