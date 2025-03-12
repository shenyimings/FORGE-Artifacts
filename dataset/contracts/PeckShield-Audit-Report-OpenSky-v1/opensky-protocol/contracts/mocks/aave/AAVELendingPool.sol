pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import './dependencies/token/ERC20/IERC20.sol';
import './interfaces/IAToken.sol';

import './dependencies/token/ERC20/SafeERC20.sol';

import {ILendingPool} from './interfaces/ILendingPool.sol';

contract AAVELendingPool {
    using SafeERC20 for IERC20;

    address immutable aToken;

    ILendingPool.ReserveData r;

    //  mapping(address => ILendingPool.ReserveData) internal _reserves;

    constructor(address aToken_) {
        aToken = aToken_;
    }

    // helper
    function initReserve(address aToken) external {
        r.aTokenAddress = aToken;
    }

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external {
        IERC20(asset).safeTransferFrom(msg.sender, aToken, amount);

        IAToken(aToken).mint(onBehalfOf, amount);
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        uint256 amountToWithdraw = amount;

        IAToken(aToken).burn(msg.sender, to, amountToWithdraw);

        return amountToWithdraw;
    }

    function getReserveData(address asset) public view returns (ILendingPool.ReserveData memory) {
        asset;
        return r;
    }
}
