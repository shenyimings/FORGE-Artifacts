// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ERC20Helper } from "../../modules/erc20-helper/src/ERC20Helper.sol";

import { IERC20Like, ILiquidatorLike, IUniswapRouterLike } from "../interfaces/Interfaces.sol";
import { IUniswapV2StyleStrategy }                         from "../interfaces/IUniswapV2StyleStrategy.sol";

contract SushiswapStrategy is IUniswapV2StyleStrategy {

    address public constant override ROUTER = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

    uint256 private constant NOT_IN_FLASH = uint256(0);
    uint256 private constant IN_FLASH     = uint256(1);

    uint256 private _state;

    modifier onlyInFlash() {
        require(_state == IN_FLASH, "SSS:NOT_IN_FLASH");
        _;
    }

    modifier flashLock() {
        require(_state == NOT_IN_FLASH, "SSS:NOT_IN_FLASH");
        _state = IN_FLASH;
        _;
        _state = NOT_IN_FLASH;
    }

    function flashBorrowLiquidation(
        address flashLender_,
        uint256 collateralBorrowed_,
        uint256 maxReturnFunds_,
        uint256 minFundsProfit_,
        address collateralAsset_,
        address middleAsset_,
        address fundsAsset_,
        address destination_
    )
        external override flashLock
    {
        // Calculate the amount of fundsAsset the flashLender will require for a successful transaction and approve.
        uint256 expectedFundsAmount = ILiquidatorLike(flashLender_).getExpectedAmount(collateralBorrowed_);
        require(ERC20Helper.approve(fundsAsset_, flashLender_, expectedFundsAmount), "SSS:FBL:APPROVE_FAILED");

        // Call `liquidatePortion`, specifying `swap` as the low-level call to perform.
        ILiquidatorLike(flashLender_).liquidatePortion(
            collateralBorrowed_,
            maxReturnFunds_,
            abi.encodeWithSelector(
                IUniswapV2StyleStrategy.swap.selector,
                collateralBorrowed_,
                expectedFundsAmount + minFundsProfit_,
                collateralAsset_,
                middleAsset_,
                fundsAsset_
            )
        );

        uint256 funds = IERC20Like(fundsAsset_).balanceOf(address(this));

        // Only skip transferring funds if no profit expected AND no profit received.
        require(
            (minFundsProfit_ == uint256(0) && funds == uint256(0)) || ERC20Helper.transfer(fundsAsset_, destination_, funds),
            "SSS:FBL:FUNDS_TRANSFER"
        );

        uint256 collateral = IERC20Like(collateralAsset_).balanceOf(address(this));

        require(collateral == uint256(0) || ERC20Helper.transfer(collateralAsset_, destination_, collateral), "SSS:FBL:COLLATERAL_TRANSFER");
    }

    function swap(
        uint256 collateralBorrowed_,
        uint256 minFundsOut_,
        address collateralAsset_,
        address middleAsset_,
        address fundsAsset_
    )
        external override onlyInFlash
    {
        // If allowance for the router is insufficient, increase it.
        require(
            (IERC20Like(collateralAsset_).allowance(address(this), ROUTER) >= collateralBorrowed_) || ERC20Helper.approve(collateralAsset_, ROUTER, type(uint256).max),
            "SSS:S:APPROVE_FAILED"
        );

        bool hasMiddleAsset = middleAsset_ != address(0);

        address[] memory path = new address[](hasMiddleAsset ? 3 : 2);

        path[0] = collateralAsset_;
        path[1] = hasMiddleAsset ? middleAsset_ : fundsAsset_;

        if (hasMiddleAsset) {
            path[2] = fundsAsset_;
        }

        IUniswapRouterLike(ROUTER).swapExactTokensForTokens(collateralBorrowed_, minFundsOut_, path, address(this), type(uint256).max);
    }

}
