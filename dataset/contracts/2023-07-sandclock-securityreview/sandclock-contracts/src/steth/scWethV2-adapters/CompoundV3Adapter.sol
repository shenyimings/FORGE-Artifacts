// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";

import {Constants as C} from "../../lib/Constants.sol";
import {IComet} from "../../interfaces/compound-v3/IComet.sol";
import {IAdapter} from "../IAdapter.sol";

contract CompoundV3Adapter is IAdapter {
    using SafeTransferLib for ERC20;

    IComet public immutable compoundV3Comet = IComet(C.COMPOUND_V3_COMET_WETH);

    uint256 public constant id = uint256(keccak256("CompoundV3Adapter"));

    function setApprovals() external override {
        ERC20(C.WSTETH).safeApprove(address(compoundV3Comet), type(uint256).max);
        ERC20(C.WETH).safeApprove(address(compoundV3Comet), type(uint256).max);
    }

    function revokeApprovals() external override {
        ERC20(C.WSTETH).safeApprove(address(compoundV3Comet), 0);
        ERC20(C.WETH).safeApprove(address(compoundV3Comet), 0);
    }

    function supply(uint256 _amount) external override {
        compoundV3Comet.supply(C.WSTETH, _amount);
    }

    function borrow(uint256 _amount) external override {
        compoundV3Comet.withdraw(C.WETH, _amount);
    }

    function repay(uint256 _amount) external override {
        compoundV3Comet.supply(C.WETH, _amount);
    }

    function withdraw(uint256 _amount) external override {
        compoundV3Comet.withdraw(C.WSTETH, _amount);
    }

    function claimRewards(bytes calldata data) external override {}

    function getCollateral(address _account) external view override returns (uint256) {
        return compoundV3Comet.userCollateral(_account, C.WSTETH).balance;
    }

    function getDebt(address _account) external view override returns (uint256) {
        return compoundV3Comet.borrowBalanceOf(_account);
    }

    function getMaxLtv() external view override returns (uint256) {
        return compoundV3Comet.getAssetInfoByAddress(C.WSTETH).borrowCollateralFactor;
    }
}
