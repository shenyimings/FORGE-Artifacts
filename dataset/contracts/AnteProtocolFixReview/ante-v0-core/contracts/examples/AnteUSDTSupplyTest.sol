// SPDX-License-Identifier: GPL-3.0-only

// ┏━━━┓━━━━━┏┓━━━━━━━━━┏━━━┓━━━━━━━━━━━━━━━━━━━━━━━
// ┃┏━┓┃━━━━┏┛┗┓━━━━━━━━┃┏━━┛━━━━━━━━━━━━━━━━━━━━━━━
// ┃┗━┛┃┏━┓━┗┓┏┛┏━━┓━━━━┃┗━━┓┏┓┏━┓━┏━━┓━┏━┓━┏━━┓┏━━┓
// ┃┏━┓┃┃┏┓┓━┃┃━┃┏┓┃━━━━┃┏━━┛┣┫┃┏┓┓┗━┓┃━┃┏┓┓┃┏━┛┃┏┓┃
// ┃┃ ┃┃┃┃┃┃━┃┗┓┃┃━┫━┏┓━┃┃━━━┃┃┃┃┃┃┃┗┛┗┓┃┃┃┃┃┗━┓┃┃━┫
// ┗┛ ┗┛┗┛┗┛━┗━┛┗━━┛━┗┛━┗┛━━━┗┛┗┛┗┛┗━━━┛┗┛┗┛┗━━┛┗━━┛
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../AnteTest.sol";

/// @title Ante Test to check USDT supply never exceeds M2 (as of May 2021)
/// @dev As of 2021-05-31, est. M2 monetary supply is ~$20.1086 Trillion USD
/// From https://www.federalreserve.gov/releases/h6/current/default.htm
/// We represent the threshold as 20.1 Trillion * (10 ** usdt Decimals)
/// Or, more simply, 20.1 Trillion = 20,100 Billion
contract AnteUSDTSupplyTest is AnteTest("ERC20 Tether (USDT) supply doesn't exceed M2, ~$20T") {
    // https://etherscan.io/address/0xdac17f958d2ee523a2206206994597c13d831ec7#code
    address public immutable usdtAddr;
    uint256 public immutable thresholdSupply;

    ERC20 public usdtToken;

    /// @param _usdtAddr USDT contract address (0xdac17f958d2ee523a2206206994597c13d831ec7 on mainnet)
    constructor(address _usdtAddr) {
        usdtAddr = _usdtAddr;
        usdtToken = ERC20(_usdtAddr);

        protocolName = "Tether";
        testedContracts = [_usdtAddr];
        thresholdSupply = 20100 * (1000 * 1000 * 1000) * (10**usdtToken.decimals());
    }

    /// @notice test to check if USDT token supply is greater than M2 money supply
    /// @return true if USDT token supply is over M2
    function checkTestPasses() external view override returns (bool) {
        return (usdtToken.totalSupply() <= thresholdSupply);
    }
}
