// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { MapleProxiedInternals } from "../modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol";
import { IMapleProxyFactory }    from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

import { ILiquidator } from "./interfaces/ILiquidator.sol";

import { ILoanManagerLike, IMapleGlobalsLike } from "./interfaces/Interfaces.sol";

import { LiquidatorStorage } from "./LiquidatorStorage.sol";

/*

    ██╗     ██╗ ██████╗ ██╗   ██╗██╗██████╗  █████╗ ████████╗ ██████╗ ██████╗
    ██║     ██║██╔═══██╗██║   ██║██║██╔══██╗██╔══██╗╚══██╔══╝██╔═══██╗██╔══██╗
    ██║     ██║██║   ██║██║   ██║██║██║  ██║███████║   ██║   ██║   ██║██████╔╝
    ██║     ██║██║▄▄ ██║██║   ██║██║██║  ██║██╔══██║   ██║   ██║   ██║██╔══██╗
    ███████╗██║╚██████╔╝╚██████╔╝██║██████╔╝██║  ██║   ██║   ╚██████╔╝██║  ██║
    ╚══════╝╚═╝ ╚══▀▀═╝  ╚═════╝ ╚═╝╚═════╝ ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝

*/

contract Liquidator is ILiquidator, LiquidatorStorage, MapleProxiedInternals {

    /******************************************************************************************************************************/
    /*** Modifiers                                                                                                              ***/
    /******************************************************************************************************************************/

    modifier whenProtocolNotPaused() {
        require(!IMapleGlobalsLike(globals()).protocolPaused(), "LIQ:PROTOCOL_PAUSED");

        _;
    }

    modifier nonReentrant() {
        require(locked == 1, "LIQ:LOCKED");

        locked = 2;

        _;

        locked = 1;
    }

    /******************************************************************************************************************************/
    /*** Migration Functions                                                                                                    ***/
    /******************************************************************************************************************************/

    function migrate(address migrator_, bytes calldata arguments_) external override {
        require(msg.sender == _factory(),        "LIQ:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "LIQ:M:FAILED");
    }

    function setImplementation(address implementation_) external override {
        require(msg.sender == _factory(), "LIQ:SI:NOT_FACTORY");

        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override {
        address poolDelegate_ = poolDelegate();

        require(msg.sender == poolDelegate_ || msg.sender == governor(), "LIQ:U:NOT_AUTHORIZED");

        IMapleGlobalsLike mapleGlobals = IMapleGlobalsLike(globals());

        if (msg.sender == poolDelegate_) {
            require(mapleGlobals.isValidScheduledCall(msg.sender, address(this), "LIQ:UPGRADE", msg.data), "LIQ:U:INVALID_SCHED_CALL");

            mapleGlobals.unscheduleCall(msg.sender, "LIQ:UPGRADE", msg.data);
        }

        IMapleProxyFactory(_factory()).upgradeInstance(version_, arguments_);
    }

    /******************************************************************************************************************************/
    /*** Liquidation Functions                                                                                                  ***/
    /******************************************************************************************************************************/

    function liquidatePortion(uint256 collateralAmount_, uint256 maxReturnAmount_, bytes calldata data_) external override whenProtocolNotPaused nonReentrant {
        require(msg.sender != collateralAsset && msg.sender != fundsAsset, "LIQ:LP:INVALID_CALLER");

        // Calculate the amount of fundsAsset required based on the amount of collateralAsset borrowed.
        uint256 returnAmount_ = getExpectedAmount(collateralAmount_);
        require(returnAmount_ <= maxReturnAmount_, "LIQ:LP:MAX_RETURN_EXCEEDED");

        // Transfer a requested amount of collateralAsset to the borrower.
        require(ERC20Helper.transfer(collateralAsset, msg.sender, collateralAmount_), "LIQ:LP:TRANSFER");

        collateralRemaining -= collateralAmount_;

        // Perform a low-level call to msg.sender, allowing a swap strategy to be executed with the transferred collateral.
        msg.sender.call(data_);

        emit PortionLiquidated(collateralAmount_, returnAmount_);

        // Pull required amount of fundsAsset from the borrower, if this amount of funds cannot be recovered atomically, revert.
        require(ERC20Helper.transferFrom(fundsAsset, msg.sender, address(this), returnAmount_), "LIQ:LP:TRANSFER_FROM");
    }

    function pullFunds(address token_, address destination_, uint256 amount_) external override {
        require(msg.sender == loanManager, "LIQ:PF:NOT_LM");

        emit FundsPulled(token_, destination_, amount_);

        require(ERC20Helper.transfer(token_, destination_, amount_), "LIQ:PF:TRANSFER");
    }

    function setCollateralRemaining(uint256 collateralAmount_) external override {
        require(msg.sender == loanManager, "LIQ:SCR:NOT_LM");

        collateralRemaining = collateralAmount_;
    }

    function getExpectedAmount(uint256 swapAmount_) public view override returns (uint256 expectedAmount_) {
        return ILoanManagerLike(loanManager).getExpectedAmount(collateralAsset, swapAmount_);
    }

    /******************************************************************************************************************************/
    /*** View Functions                                                                                                         ***/
    /******************************************************************************************************************************/

    function factory() public view override returns (address factory_) {
        factory_ = _factory();
    }

    function globals() public view returns (address globals_) {
        globals_ = IMapleProxyFactory(_factory()).mapleGlobals();
    }

    function governor() public view returns (address governor_) {
        governor_ = ILoanManagerLike(loanManager).governor();
    }

    function implementation() public view override returns (address implementation_) {
        implementation_ = _implementation();
    }

    function poolDelegate() public view returns (address poolDelegate_) {
        poolDelegate_ = ILoanManagerLike(loanManager).poolDelegate();
    }

}
