// SPDX-License-Identifier: MIT

pragma solidity 0.6;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import '../../../../Fodl/core/interfaces/ICTokenProvider.sol';
import '../../../../Fodl/modules/Lender/ILendingPlatform.sol';
import './AaveLendingPolygonBaseAdapter.sol';

import { ILendingPlatformPolygon } from '../LendingDispatcherPolygon.sol';

import '../../../../../contracts/Libs/IWETH.sol';
import '../../../../../contracts/Libs/Uint2Str.sol';

contract AaveLendingPolygonAdapter is ILendingPlatformPolygon, AaveLendingPolygonBaseAdapter {
    using SafeMath for uint256;
    uint256 public constant LIQUIDITY_BUFFER = 10; // wei

    constructor(
        address _aavePoolProvider,
        address _aaveData,
        address _aaveIncentives
    ) public AaveLendingPolygonBaseAdapter(_aavePoolProvider, _aaveData, _aaveIncentives) {}

    /**
     * redeem all token supplied
     */
    function redeemAll(address, address token) external override {
        address aave = IAaveLendingPoolProviderPolygon(PoolProvider).getLendingPool();
        IAaveLendingPoolPolygon(aave).withdraw(token, type(uint256).max, address(this));
    }

    /**
     * @return available borrow amount in token
     */
    function getLiquidity(address, address token) external override returns (uint256) {
        address aave = IAaveLendingPoolProviderPolygon(PoolProvider).getLendingPool();
        address oracle = IAaveLendingPoolProviderPolygon(PoolProvider).getPriceOracle();
        (, , uint256 availableBorrowsETH, , , ) = IAaveLendingPoolPolygon(aave).getUserAccountData(address(this));
        uint256 price = IAavePriceOracleGetterPolygon(oracle).getAssetPrice(token);
        uint256 decimals = ERC20(token).decimals();
        uint256 result = (availableBorrowsETH.mul((uint256(10)**decimals))).div(price);
        return result > LIQUIDITY_BUFFER ? result - LIQUIDITY_BUFFER : result; // lower by buffer to avoid precision errors
    }
}
