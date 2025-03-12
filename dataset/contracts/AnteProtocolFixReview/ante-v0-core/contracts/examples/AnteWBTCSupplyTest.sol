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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../AnteTest.sol";

/// @title WBTC supply never exceeds 21 million test
/// @notice Ante Test to check that WBTC supply is always less than 21 million
contract AnteWBTCSupplyTest is AnteTest("Wrapped BTC (WBTC) supply doesn't exceed 21m") {
    // https://etherscan.io/address/0x2260fac5e5542a773aa44fbcfedf7c193bc2c599#code
    address public immutable wBTCAddr;

    //21 million * 1e8 (for decimals), maximum total Bitcoin supply
    uint256 public constant THRESHOLD_SUPPLY = 21 * 1000 * 1000 * 1e8;

    IERC20 public wBTCToken;

    /// @param _wBTCAddr WBTC contract address (0x2260fac5e5542a773aa44fbcfedf7c193bc2c599 on mainnet)
    constructor(address _wBTCAddr) {
        protocolName = "WBTC";
        testedContracts = [_wBTCAddr];

        wBTCAddr = _wBTCAddr;
        wBTCToken = IERC20(_wBTCAddr);
    }

    /// @notice test to check WBTC token supply
    /// @return true if WBTC supply is less than 21 million
    function checkTestPasses() external view override returns (bool) {
        return (wBTCToken.totalSupply() <= THRESHOLD_SUPPLY);
    }
}
