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

/// @title WETH9 issued fully backed by ETH test
/// @notice Ante Test to check WETH9 minted WETH matches deposited ETH in contract
contract AnteWETH9Test is AnteTest("Checks WETH9 issued WETH fully backed by ETH") {
    // https://etherscan.io/address/0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    address public immutable wETH9Addr;

    IERC20 public wETH9Token;

    /// @param _wETH9Addr WETH9 contract address (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 on mainnet)
    constructor(address _wETH9Addr) {
        wETH9Addr = _wETH9Addr;
        wETH9Token = IERC20(_wETH9Addr);

        protocolName = "WETH9";
        testedContracts = [_wETH9Addr];
    }

    /// @notice test to check WETH token supply against contract balance
    /// @return true if WETH9 token supply equals contract balance
    function checkTestPasses() external view override returns (bool) {
        return address(wETH9Token).balance == wETH9Token.totalSupply();
    }
}
