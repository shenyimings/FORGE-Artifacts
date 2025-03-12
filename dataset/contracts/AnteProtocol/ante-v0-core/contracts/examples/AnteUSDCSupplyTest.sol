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

/// @title Ante Test to check USDC supply never exceeds M2 (as of May 2021)
/// @dev As of 2021-05-31, est. M2 monetary supply is ~$20.1086 Trillion USD
/// From https://www.federalreserve.gov/releases/h6/current/default.htm
/// We represent the threshold as 20.1 Trillion * (10 ** usdt Decimals)
/// Or, more simply, 20.1 Trillion = 20,100 Billion
contract AnteUSDCSupplyTest is AnteTest("ERC20 USD Coin (USDC) supply doesn't exceed M2, ~$20T") {
    // https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48#code
    address public immutable usdcAddr;
    uint256 public immutable thresholdSupply;

    ERC20 public usdcToken;

    /// @param _usdcAddr usdc contract address (0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 on mainnet)
    constructor(address _usdcAddr) {
        usdcAddr = _usdcAddr;
        usdcToken = ERC20(_usdcAddr);
        thresholdSupply = 20100 * (1000 * 1000 * 1000) * (10**usdcToken.decimals());

        protocolName = "USD Coin";
        testedContracts = [_usdcAddr];
    }

    /// @notice test to check if usdc token supply is greater than M2 money supply
    /// @return true if usdc token supply is over M2
    function checkTestPasses() external view override returns (bool) {
        return (usdcToken.totalSupply() <= thresholdSupply);
    }
}
