// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockStETH} from "./MockStETH.sol";

contract MockWstETH is ERC20 {
    MockStETH public stEth;

    constructor(MockStETH _stEth) ERC20("Mock wrapped staked Ether", "mwstETH", 18) {
        stEth = _stEth;
    }

    function wrap(uint256 _stETHAmount) external returns (uint256) {
        require(stEth.allowance(msg.sender, address(this)) >= _stETHAmount, "MockWstETH: INSUFFICIENT_stETH_ALLOWANCE");
        require(stEth.balanceOf(msg.sender) >= _stETHAmount, "MockWstETH: INSUFFICIENT_stETH_BALANCE");

        stEth.transferFrom(msg.sender, address(this), _stETHAmount);
        _mint(msg.sender, _stETHAmount);
        return _stETHAmount;
    }

    function unwrap(uint256 _wstETHAmount) external returns (uint256) {
        require(this.balanceOf(msg.sender) >= _wstETHAmount, "MockWstETH: INSUFFICIENT_wstETH_BALANCE");
        require(stEth.balanceOf(address(this)) >= _wstETHAmount, "MockWstETH: INSUFFICIENT_stETH_BALANCE");

        _burn(msg.sender, _wstETHAmount);
        stEth.transfer(msg.sender, _wstETHAmount);
        return _wstETHAmount;
    }

    function getWstETHByStETH(uint256 _stETHAmount) external pure returns (uint256) {
        return _stETHAmount;
    }

    function getStETHByWstETH(uint256 _wstETHAmount) external pure returns (uint256) {
        return _wstETHAmount;
    }

    function stEthPerToken() external pure returns (uint256) {
        return 1e18;
    }

    function tokensPerStEth() external pure returns (uint256) {
        return 1e18;
    }
}
