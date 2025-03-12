// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ERC20Helper } from "../../modules/erc20-helper/src/ERC20Helper.sol";

import { IERC20Like, ILiquidatorLike, IUniswapRouterLike } from "../interfaces/Interfaces.sol";
import { IUniswapV2StyleStrategy }                         from "../interfaces/IUniswapV2StyleStrategy.sol";

contract UniswapV2Strategy is IUniswapV2StyleStrategy {

    address public constant override ROUTER = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    uint256 private constant NOT_IN_FLASH = uint256(0);
    uint256 private constant IN_FLASH     = uint256(1);

    uint256 private _state;

    modifier onlyInFlash() {
        require(_state == IN_FLASH, "UV2S:NOT_IN_FLASH");
        _;
    }

    modifier flashLock() {
        require(_state == NOT_IN_FLASH, "UV2S:NOT_IN_FLASH");
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
        require(ERC20Helper.approve(fundsAsset_, flashLender_, expectedFundsAmount), "UV2S:FBL:APPROVE_FAILED");

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
            "UV2S:FBL:FUNDS_TRANSFER"
        );

        uint256 collateral = IERC20Like(collateralAsset_).balanceOf(address(this));

        require(collateral == uint256(0) || ERC20Helper.transfer(collateralAsset_, destination_, collateral), "UV2S:FBL:COLLATERAL_TRANSFER");
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
            "UV2S:S:APPROVE_FAILED"
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
