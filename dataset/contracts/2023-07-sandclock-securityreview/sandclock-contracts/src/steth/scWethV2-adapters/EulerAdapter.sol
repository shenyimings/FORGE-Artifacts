// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IEulerDToken, IEulerEToken, IEulerMarkets} from "lib/euler-interfaces/contracts/IEuler.sol";

import {Constants as C} from "../../lib/Constants.sol";
import {IAdapter} from "../IAdapter.sol";

contract EulerAdapter is IAdapter {
    using SafeTransferLib for ERC20;
    using SafeTransferLib for WETH;
    using FixedPointMathLib for uint256;

    address constant protocol = C.EULER;
    IEulerMarkets constant markets = IEulerMarkets(C.EULER_MARKETS);
    IEulerEToken constant eWstEth = IEulerEToken(C.EULER_ETOKEN_WSTETH);
    IEulerDToken constant dWeth = IEulerDToken(C.EULER_DTOKEN_WETH);

    uint256 public constant id = uint256(keccak256("EulerAdapter"));

    function setApprovals() external override {
        ERC20(C.WSTETH).safeApprove(protocol, type(uint256).max);
        WETH(payable(C.WETH)).safeApprove(protocol, type(uint256).max);
        markets.enterMarket(0, address(C.WSTETH));
    }

    function revokeApprovals() external override {
        ERC20(C.WSTETH).safeApprove(protocol, 0);
        WETH(payable(C.WETH)).safeApprove(protocol, 0);
    }

    function supply(uint256 _amount) external override {
        eWstEth.deposit(0, _amount);
    }

    function borrow(uint256 _amount) external override {
        dWeth.borrow(0, _amount);
    }

    function repay(uint256 _amount) external override {
        dWeth.repay(0, _amount);
    }

    function withdraw(uint256 _amount) external override {
        eWstEth.withdraw(0, _amount);
    }

    function claimRewards(bytes calldata data) external override {}

    function getCollateral(address _account) external view override returns (uint256) {
        return eWstEth.balanceOfUnderlying(_account);
    }

    function getDebt(address _account) external view override returns (uint256) {
        return dWeth.balanceOf(_account);
    }

    function getMaxLtv() external view override returns (uint256) {
        uint256 collateralFactor = markets.underlyingToAssetConfig(C.WSTETH).collateralFactor;
        uint256 borrowFactor = markets.underlyingToAssetConfig(C.WSTETH).borrowFactor;

        uint256 scaledCollateralFactor = collateralFactor.divWadDown(C.EULER_CONFIG_FACTOR_SCALE);
        uint256 scaledBorrowFactor = borrowFactor.divWadDown(C.EULER_CONFIG_FACTOR_SCALE);

        return scaledCollateralFactor.mulWadDown(scaledBorrowFactor);
    }
}
