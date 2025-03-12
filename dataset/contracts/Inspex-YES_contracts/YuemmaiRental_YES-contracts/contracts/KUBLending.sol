//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./abstracts/LendingContract.sol";
import "./modules/kkub/interfaces/IKKUB.sol";
import "./modules/kap20/interfaces/IKAP20.sol";
import "./modules/kap20/interfaces/IKToken.sol";

contract KUBLending is LendingContract {
    address public kkub;

    constructor(
        address kkub_,
        address controller_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory lTokenName_,
        string memory lTokenSymbol_,
        uint8 lTokenDecimals_,
        address committee_,
        address adminRouter_,
        address kyc_,
        uint256 acceptedKycLevel_
    )
        LendingContract(
            controller_,
            interestRateModel_,
            initialExchangeRateMantissa_,
            lTokenName_,
            lTokenSymbol_,
            lTokenDecimals_,
            committee_,
            adminRouter_,
            kyc_,
            acceptedKycLevel_
        )
    {
        kkub = kkub_;
    }

    /*** User Interface ***/

    function deposit(uint256 depositAmount, address sender) external payable {
        uint256 err;
        if (adminRouter.isSuperAdmin(msg.sender, PROJECT)) {
            requireKYC(sender);
            (err, ) = depositInternal(
                sender,
                depositAmount,
                TransferMethod.BK_NEXT
            );
        } else {
            (err, ) = depositInternal(
                msg.sender,
                msg.value,
                TransferMethod.METAMASK
            );
        }

        requireNoError(err, "Mint failed");
    }

    function withdraw(uint256 withdrawTokens, address payable sender)
        external
        returns (uint256)
    {
        uint256 err;
        if (adminRouter.isSuperAdmin(msg.sender, PROJECT)) {
            requireKYC(sender);
            err = withdrawInternal(sender, withdrawTokens, TransferMethod.BK_NEXT);
        } else {
            err = withdrawInternal(payable(msg.sender), withdrawTokens, TransferMethod.METAMASK);
        }
        return err;
    }

    function withdrawUnderlying(uint256 withdrawAmount, address payable sender)
        external
        returns (uint256)
    {
        uint256 err;
        if (adminRouter.isSuperAdmin(msg.sender, PROJECT)) {
            requireKYC(sender);
            err = withdrawUnderlyingInternal(sender, withdrawAmount, TransferMethod.BK_NEXT);
        } else {
            err = withdrawUnderlyingInternal(
                payable(msg.sender),
                withdrawAmount,
                TransferMethod.METAMASK
            );
        }
        return err;
    }

    function borrow(uint256 borrowAmount, address payable sender)
        external
        returns (uint256)
    {
        uint256 err;
        if (adminRouter.isSuperAdmin(msg.sender, PROJECT)) {
            requireKYC(sender);
            err = borrowInternal(sender, borrowAmount, TransferMethod.BK_NEXT);
        } else {
            err = borrowInternal(payable(msg.sender), borrowAmount, TransferMethod.METAMASK);
        }
        return err;
    }

    function repayBorrow(uint256 repayAmount, address sender) external payable {
        uint256 err;
        if (adminRouter.isSuperAdmin(msg.sender, PROJECT)) {
            requireKYC(sender);
            (err, ) = repayBorrowInternal(
                sender,
                repayAmount,
                TransferMethod.BK_NEXT
            );
        } else {
            (err, ) = repayBorrowInternal(
                msg.sender,
                repayAmount,
                TransferMethod.METAMASK
            );
        }
        requireNoError(err, "Repay borrow fail");
    }

    function repayBorrowBehalf(
        address borrower,
        uint256 repayAmount,
        address sender
    ) external payable {
        uint256 err;
        if (adminRouter.isSuperAdmin(msg.sender, PROJECT)) {
            requireKYC(sender);
            (err, ) = repayBorrowBehalfInternal(
                sender,
                borrower,
                repayAmount,
                TransferMethod.BK_NEXT
            );
        } else {
            (err, ) = repayBorrowBehalfInternal(
                msg.sender,
                borrower,
                repayAmount,
                TransferMethod.METAMASK
            );
        }
        requireNoError(err, "Repay borrow behalf failed");
    }

    function liquidateBorrow(address borrower, address payable sender)
        external
        payable
    {
        uint256 err;

        if (adminRouter.isSuperAdmin(msg.sender, PROJECT)) {
            requireKYC(sender);
            (err, ) = liquidateBorrowInternal(sender, borrower, TransferMethod.BK_NEXT);
        } else {
            (err, ) = liquidateBorrowInternal(payable(msg.sender), borrower, TransferMethod.METAMASK);
        }

        requireNoError(err, "Liquidate borrow failed");
    }

    receive() external payable {
        if (
            msg.sender != _controller.yesVault() && msg.sender != kkub
        ) {
            (uint256 err, ) = depositInternal(
                msg.sender,
                msg.value,
                TransferMethod.METAMASK
            );
            requireNoError(err, "Deposit failed");
        }
    }

    /*** Safe Token ***/

    function getCashPrior() internal view override returns (uint256) {
        (MathError err, uint256 startingBalance) = subUInt(
            address(this).balance,
            msg.value
        );
        require(err == MathError.NO_ERROR);
        return startingBalance;
    }

    function doTransferIn(
        address from,
        uint256 amount,
        TransferMethod method
    ) internal override returns (uint256) {
        if (method == TransferMethod.BK_NEXT) {
            return doTransferInBKNext(from, amount);
        } else {
            return doTransferInMetamask(from, amount);
        }
    }

    function doTransferInBKNext(address from, uint256 amount)
        private
        returns (uint256)
    {
        uint256 balanceBefore = address(this).balance;

        IKToken(kkub).externalTransfer(from, address(this), amount);
        IKKUB(kkub).withdrawAdmin(amount, address(this));

        uint256 balanceAfter = address(this).balance;
        require(balanceAfter >= balanceBefore, "Transfer in overflow");
        return balanceAfter - balanceBefore; // underflow already checked above, just subtract
    }

    function doTransferInMetamask(address from, uint256 amount)
        private
        returns (uint256)
    {
        require(msg.sender == from, "Sender mismatch");
        require(msg.value == amount, "Value mismatch");
        return amount;
    }

    function doTransferOutBitkubNext(address payable to, uint256 amount)
        private
    {
        IKKUB(kkub).deposit{value: amount}();
        IKAP20(kkub).transfer(to, amount);
    }

    function doTransferOutMetaMask(address payable to, uint256 amount)
        private
    {
        /* Send the Ether, with minimal gas and revert on failure */
        to.transfer(amount);
    }

    function doTransferOut(address payable to, uint256 amount, TransferMethod method)
        internal
        override
    {
        if (method == TransferMethod.BK_NEXT) {
            return doTransferOutBitkubNext(to, amount);
        } else {
            return doTransferOutMetaMask(to, amount);
        }
    }

    function requireNoError(uint256 errCode, string memory message)
        internal
        pure
    {
        if (errCode == uint256(Error.NO_ERROR)) {
            return;
        }

        bytes memory fullMessage = new bytes(bytes(message).length + 5);
        uint256 i;

        for (i = 0; i < bytes(message).length; i++) {
            fullMessage[i] = bytes(message)[i];
        }

        fullMessage[i + 0] = bytes1(uint8(32));
        fullMessage[i + 1] = bytes1(uint8(40));
        fullMessage[i + 2] = bytes1(uint8(48 + (errCode / 10)));
        fullMessage[i + 3] = bytes1(uint8(48 + (errCode % 10)));
        fullMessage[i + 4] = bytes1(uint8(41));

        require(errCode == uint256(Error.NO_ERROR), string(fullMessage));
    }
}
