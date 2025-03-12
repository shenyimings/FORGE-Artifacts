pragma solidity 0.5.16;

import { BErc20 } from "./btoken/BErc20.sol";
import { BEther } from "./btoken/BEther.sol";
import { Registry } from "./Registry.sol";
import { BComptroller } from "./BComptroller.sol";
import { ICToken, ICErc20, ICEther } from "./interfaces/CTokenInterfaces.sol";
import { IAvatar } from "./interfaces/IAvatar.sol";
import { Exponential } from "./lib/Exponential.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// user will give an allowance to this contract, and also delegate his B account
contract Import is Exponential {
    using SafeERC20 for IERC20;

    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    Registry public registry;
    BComptroller public bComptroller;
    address public bETH;

    constructor(Registry _registery, BComptroller _bComptroller) public {
        require(_registery != Registry(0), "registry-0");
        require(_bComptroller != BComptroller(0), "registry-0");

        registry = _registery;
        bComptroller = _bComptroller;

        address cETH = registry.cEther();
        bETH = bComptroller.c2b(cETH);
    }

    function _repayAllDebt(
        address[] memory cTokenDebt,
        address[] memory debtUnderlying,
        uint[] memory originalDebt,
        address account
    )
        internal
    {
        for(uint i = 0 ; i < cTokenDebt.length ; i++) {
            address cDebt = cTokenDebt[i];
            uint debt = originalDebt[i];
            if(debtUnderlying[i] == ETH) {
                ICEther(cDebt).repayBorrowBehalf.value(debt)(account);
            } else {
                IERC20(debtUnderlying[i]).safeApprove(address(cDebt), debt);
                require(ICErc20(cDebt).repayBorrowBehalf(account, debt) == 0, "repay-failed");
            }
        }
    }

    function _transferCollateral(
        address[] memory cTokenCollateral,
        address account,
        address avatar
    )
        internal
    {
        for(uint i = 0 ; i < cTokenCollateral.length ; i++) {
            ICToken cColl = ICToken(cTokenCollateral[i]);
            uint collBalance = cColl.balanceOf(account);
            IAvatar(avatar).collectCToken(address(cColl), account, collBalance);
        }
    }

    function _borrowDebtOnB(
        address[] memory cTokenDebt,
        uint[] memory originalDebt,
        address avatar
    )
        internal
    {
        for(uint i = 0 ; i < cTokenDebt.length ; i++) {
            uint debt = originalDebt[i];
            address bTokenDebt = bComptroller.c2b(cTokenDebt[i]);
            require(BErc20(bTokenDebt).borrowOnAvatar(avatar, debt) == 0, "borrowOnAvatar-failed");
        }
    }

    // this is safe only if the owner of the compound account is an EOA
    function importAccount(
        address[] calldata cTokenCollateral,
        address[] calldata collateralUnderlying,
        address[] calldata cTokenDebt,
        address[] calldata debtUnderlying,
        uint ethFlashLoan
    )
        external
    {

        require(cTokenCollateral.length == collateralUnderlying.length, "collateral-length-missmatch");
        require(cTokenDebt.length == debtUnderlying.length, "debt-length-missmatch");
        require(mul_(ethFlashLoan, 100) <= mul_(address(this).balance, 101), "flashloan-fees-over-1%");

        // Compound account of an EOA
        address account = tx.origin;
        address avatar = registry.getAvatar(account);

        // mint flash loaned ETH on B
        uint ethBalance = address(this).balance;
        BEther(bETH).mintOnAvatar.value(ethBalance)(avatar);

        uint[] memory originalDebt = new uint[](cTokenDebt.length);
        for(uint i = 0 ; i < cTokenDebt.length ; i++) {
            originalDebt[i] = ICToken(cTokenDebt[i]).borrowBalanceCurrent(account);
        }

        // borrow the original debt on B
        _borrowDebtOnB(
            cTokenDebt,
            originalDebt,
            avatar
        );

        // repay all debt on Compound
        _repayAllDebt(cTokenDebt, debtUnderlying, originalDebt, account);

        // redeem all non ETH collateral from Compound and deposit it in B
        _transferCollateral(
            cTokenCollateral,
            account,
            avatar
        );

        BEther(bETH).redeemUnderlyingOnAvatar(avatar, ethBalance);
        if(address(this).balance < ethFlashLoan) {
            BEther(bETH).borrowOnAvatar(avatar, ethFlashLoan - address(this).balance);
        }

        msg.sender.transfer(address(this).balance);
    }

    // accept ETH transfers
    function() external payable {}
}

contract FlashLoanLike {
    function borrow(address _token, uint _amount, bytes calldata _data) external;
}

// user will call this contract
// this contract will be upgraded over time, depending on available flash loan
// sources
contract FlashLoanImport {
    using SafeERC20 for IERC20;
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function flashImport(
        address[] calldata cTokenCollateral,
        address[] calldata collateralUnderlying,
        address[] calldata cTokenDebt,
        address[] calldata debtUnderlying,
        address payable importer,
        uint            ethAmountToFlashBorrow,
        address payable flash
    )
        external
    {
        require(cTokenDebt.length == debtUnderlying.length, "debt-length-missmatch");

        if(address(this).balance < ethAmountToFlashBorrow) {
            // this will invoke a recursive call
            return FlashLoanLike(flash).borrow(ETH, ethAmountToFlashBorrow, msg.data);
        }

        // now balance is sufficient
        importer.transfer(ethAmountToFlashBorrow);

        Import(importer).importAccount(
            cTokenCollateral,
            collateralUnderlying,
            cTokenDebt,
            debtUnderlying,
            ethAmountToFlashBorrow
        );

        flash.transfer(ethAmountToFlashBorrow);
    }

    // accept ETH transfers
    function() external payable {}
}

// user will call this contract
// this contract will be upgraded over time, depending on available flash loan
// sources
contract FlashLoanImportWithFees {
    using SafeERC20 for IERC20;
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function flashImport(
        address[] calldata cTokenCollateral,
        address[] calldata collateralUnderlying,
        address[] calldata cTokenDebt,
        address[] calldata debtUnderlying,
        address payable importer,
        uint ethAmountToFlashBorrow,
        address payable flash
    )
        external
    {
        require(cTokenDebt.length == debtUnderlying.length, "debt-length-missmatch");

        if(address(this).balance < ethAmountToFlashBorrow) {
            // this will invoke a recursive call
            return FlashLoanLike(flash).borrow(ETH, ethAmountToFlashBorrow, msg.data);
        }

        // now balance is sufficient
        importer.transfer(ethAmountToFlashBorrow);

        Import(importer).importAccount(cTokenCollateral,
            collateralUnderlying,
            cTokenDebt,
            debtUnderlying,
            ethAmountToFlashBorrow + 1000
        );

        flash.transfer(ethAmountToFlashBorrow + 1000);
    }

    // accept ETH transfers
    function() external payable {}
}