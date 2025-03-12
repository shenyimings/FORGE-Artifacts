// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {IEulerMarkets, IEulerEToken, IEulerDToken} from "lib/euler-interfaces/contracts/IEuler.sol";

import {Constants as C} from "../../lib/Constants.sol";
import {IAdapter} from "../IAdapter.sol";

/**
 * @title Euler Lending Protocol Adapter
 * @notice Facilitates lending and borrowing for the Euler lending protocol
 */
contract EulerAdapter is IAdapter {
    using FixedPointMathLib for uint256;

    ERC20 constant usdc = ERC20(C.USDC);
    WETH constant weth = WETH(payable(C.WETH));

    // address of the EULER protocol contract
    address public constant protocol = 0x27182842E098f60e3D576794A5bFFb0777E025d3;
    // address of the EULER markets contract
    IEulerMarkets public constant markets = IEulerMarkets(0x3520d5a913427E6F0D6A83E07ccD4A4da316e4d3);
    // address of the EULER eUSDC token contract (supply token)
    IEulerEToken public constant eUsdc = IEulerEToken(0xEb91861f8A4e1C12333F42DCE8fB0Ecdc28dA716);
    // address of the EULER eWETH token contract (debt token)
    IEulerDToken public constant dWeth = IEulerDToken(0x62e28f054efc24b26A794F5C1249B6349454352C);
    // vaule used to scale the token's collateral/borrow factors from the euler market
    uint32 constant EULER_CONFIG_FACTOR_SCALE = 4_000_000_000;

    /// @inheritdoc IAdapter
    uint256 public constant override id = 3;

    /// @inheritdoc IAdapter
    function setApprovals() external override {
        usdc.approve(protocol, type(uint256).max);
        weth.approve(protocol, type(uint256).max);
        markets.enterMarket(0, address(usdc));
    }

    /// @inheritdoc IAdapter
    function revokeApprovals() external override {
        usdc.approve(protocol, 0);
        weth.approve(protocol, 0);
    }

    /// @inheritdoc IAdapter
    function supply(uint256 _amount) external override {
        eUsdc.deposit(0, _amount);
    }

    /// @inheritdoc IAdapter
    function borrow(uint256 _amount) external override {
        dWeth.borrow(0, _amount);
    }

    /// @inheritdoc IAdapter
    function repay(uint256 _amount) external override {
        dWeth.repay(0, _amount);
    }

    /// @inheritdoc IAdapter
    function withdraw(uint256 _amount) external override {
        eUsdc.withdraw(0, _amount);
    }

    /// @inheritdoc IAdapter
    function claimRewards(bytes calldata) external pure override {
        revert("not applicable");
    }

    /// @inheritdoc IAdapter
    function getCollateral(address _account) external view override returns (uint256) {
        return eUsdc.balanceOfUnderlying(_account);
    }

    /// @inheritdoc IAdapter
    function getDebt(address _account) external view override returns (uint256) {
        return dWeth.balanceOf(_account);
    }

    /// @inheritdoc IAdapter
    function getMaxLtv() external view override returns (uint256) {
        uint256 collateralFactor = markets.underlyingToAssetConfig(address(usdc)).collateralFactor;
        uint256 borrowFactor = markets.underlyingToAssetConfig(address(weth)).borrowFactor;

        uint256 scaledCollateralFactor = collateralFactor.divWadDown(EULER_CONFIG_FACTOR_SCALE);
        uint256 scaledBorrowFactor = borrowFactor.divWadDown(EULER_CONFIG_FACTOR_SCALE);

        return scaledCollateralFactor.mulWadDown(scaledBorrowFactor);
    }
}
