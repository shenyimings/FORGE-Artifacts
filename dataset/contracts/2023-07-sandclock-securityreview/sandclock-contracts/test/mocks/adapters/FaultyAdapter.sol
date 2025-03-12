// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";

import {Constants as C} from "../../../src/lib/Constants.sol";
import {IAdapter} from "../../../src/steth/IAdapter.sol";

contract FaultyAdapter is IAdapter {
    ERC20 constant usdc = ERC20(C.USDC);
    WETH constant weth = WETH(payable(C.WETH));

    uint256 public constant override id = 0;

    // dummy address for token approvals
    address public constant protocol = address(0x123);

    function setApprovals() external override {
        usdc.approve(protocol, type(uint256).max);
        weth.approve(protocol, type(uint256).max);
    }

    function revokeApprovals() external override {
        usdc.approve(protocol, 0);
        weth.approve(protocol, 0);
    }

    function supply(uint256) external pure override {
        revert("not working");
    }

    function borrow(uint256) external pure override {
        revert("not working");
    }

    function repay(uint256) external pure override {
        revert("not working");
    }

    function withdraw(uint256) external pure override {
        revert("not working");
    }

    function claimRewards(bytes calldata _data) external view override {
        address caller = abi.decode(_data, (address));

        require(address(this) == caller, "invalid caller");
    }

    function getCollateral(address) external pure override returns (uint256) {
        revert("not working");
    }

    function getDebt(address) external pure override returns (uint256) {
        revert("not working");
    }

    function getMaxLtv() external pure override returns (uint256) {
        revert("not working");
    }
}
