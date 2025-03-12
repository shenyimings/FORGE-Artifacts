//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title binance TokenHub interface
 * @dev Helps in cross-chain transfers (BSC -> BC)
 */
interface ITokenHub {
    function relayFee() external view returns (uint256);

    function transferOut(
        address contractAddr,
        address recipient,
        uint256 amount,
        uint64 expireTime
    ) external payable returns (bool);
}
