// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IWETH.sol";
import "./IDMMExchangeRouterDelegate.sol";
import "./IDMMLiquidityRouterDelegate.sol";

/// @dev full interface for router
interface IDMMRouter01Delegate is IDMMExchangeRouterDelegate, IDMMLiquidityRouterDelegate {
    //    function factory() external pure returns (address);
    //
    //    function weth() external pure returns (IWETH);
}
