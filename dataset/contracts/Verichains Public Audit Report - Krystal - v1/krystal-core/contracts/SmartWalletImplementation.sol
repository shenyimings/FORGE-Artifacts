// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@kyber.network/utils-sc/contracts/IERC20Ext.sol";
import "./interfaces/ISmartWalletImplementation.sol";
import "./SmartWalletStorage.sol";
import "./swap/ISwap.sol";
import "./lending/ILending.sol";

contract SmartWalletImplementation is SmartWalletStorage, ISmartWalletImplementation {
    using SafeERC20 for IERC20Ext;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    event ApprovedAllowances(IERC20Ext[] tokens, address[] spenders, bool isReset);
    event ClaimedPlatformFees(address[] wallets, IERC20Ext[] tokens, address claimer);

    constructor(address _admin) SmartWalletStorage(_admin) {}

    receive() external payable {}

    /// Claim fee to platform wallets
    function claimPlatformFees(address[] calldata platformWallets, IERC20Ext[] calldata tokens)
        external
        override
        nonReentrant
    {
        for (uint256 i = 0; i < platformWallets.length; i++) {
            for (uint256 j = 0; j < tokens.length; j++) {
                uint256 fee = platformWalletFees[platformWallets[i]][tokens[j]];
                if (fee > 1) {
                    // fee set to 1 to avoid the SSTORE initial gas cost
                    platformWalletFees[platformWallets[i]][tokens[j]] = 1;
                    transferToken(payable(platformWallets[i]), tokens[j], fee - 1);
                }
            }
        }
        emit ClaimedPlatformFees(platformWallets, tokens, msg.sender);
    }

    /// @dev approve/unapprove LPs usage on the particular tokens
    function approveAllowances(
        IERC20Ext[] calldata tokens,
        address[] calldata spenders,
        bool isReset
    ) external onlyAdmin {
        uint256 allowance = isReset ? 0 : MAX_ALLOWANCE;
        for (uint256 i = 0; i < tokens.length; i++) {
            for (uint256 j = 0; j < spenders.length; j++) {
                tokens[i].safeApprove(spenders[j], allowance);
            }
            getSetDecimals(tokens[i]);
        }

        emit ApprovedAllowances(tokens, spenders, isReset);
    }

    /// @dev get expected return including the fee
    /// @return destAmount expected dest amount
    /// @return expectedRate expected swap rate
    function getExpectedReturn(
        ISmartWalletImplementation.GetExpectedReturnParams calldata params
    ) external view override returns (uint256 destAmount, uint256 expectedRate) {
        if (params.feeBps >= BPS) return (0, 0); // platform fee is too high
        
        uint256 actualSrc = (params.feeMode == FeeMode.FROM_SOURCE) 
            ? params.srcAmount * (BPS - params.feeBps) / BPS : params.srcAmount;

        destAmount = ISwap(params.swapContract).getExpectedReturn(
            ISwap.GetExpectedReturnParams({
                srcAmount: actualSrc, 
                tradePath: params.tradePath,
                feeBps: params.feeMode == FeeMode.BY_PROTOCOL ? params.feeBps : 0,
                extraArgs: params.extraArgs
            })
        );

        if (params.feeMode == FeeMode.FROM_DEST) {
            destAmount = destAmount * (BPS - params.feeBps) / BPS;
        }

        expectedRate = calcRateFromQty(
            params.srcAmount,
            destAmount,
            getDecimals(IERC20Ext(params.tradePath[0])),
            getDecimals(IERC20Ext(params.tradePath[params.tradePath.length - 1]))
        );
    }

    /// @dev swap using particular swap contract
    /// @return destAmount actual dest amount
    function swap(
        ISmartWalletImplementation.SwapParams calldata params
    ) external payable override nonReentrant returns (uint256 destAmount) {
        {   
            // prevent stack too deep
            destAmount = swapInternal(
                params.swapContract,
                params.srcAmount,
                params.minDestAmount,
                params.tradePath,
                msg.sender,
                params.feeMode,
                params.feeBps,
                params.platformWallet,
                params.extraArgs
            );
        }
        emit Swap(
            msg.sender,
            params.swapContract,
            params.tradePath,
            params.srcAmount,
            destAmount,
            params.feeBps,
            params.platformWallet
        );
    }

    /// @dev swap then deposit to platform
    ///     if tradePath has only 1 token, don't need to do swap
    /// @return destAmount actual dest amount
    function swapAndDeposit(
        ISmartWalletImplementation.SwapAndDepositParams calldata params
    ) external payable override nonReentrant returns (uint256 destAmount) {
        require(params.tradePath.length >= 1, "invalid tradePath");
        require(supportedLendings.contains(params.lendingContract), "unsupported lending");

        
        if (params.tradePath.length == 1) {
            // just collect src token, no need to swap
            validateSourceAmount(params.tradePath[0], params.srcAmount);
            destAmount = safeTransferWithFee(
                msg.sender, 
                params.lendingContract, 
                params.tradePath[0], 
                params.srcAmount,
                // Not taking lending fee
                0, 
                params.platformWallet
            );
        } else {
            destAmount = swapInternal(
                params.swapContract,
                params.srcAmount,
                params.minDestAmount,
                params.tradePath,
                params.lendingContract,
                params.feeMode,
                params.feeBps,
                params.platformWallet,                    
                params.extraArgs
            );
        }

        // eth or token already transferred to the address
        ILending(params.lendingContract).depositTo(
            msg.sender, IERC20Ext(params.tradePath[params.tradePath.length - 1]), destAmount
        );
    
        emit SwapAndDeposit(
            msg.sender,
            params.swapContract,
            params.lendingContract,
            params.tradePath,
            params.srcAmount,
            destAmount,
            params.feeBps,
            params.platformWallet
        );
    }

    /// @dev withdraw token from Lending platforms (AAVE, COMPOUND)
    
    /// @return returnedAmount returns the amount withdrawn to the user
    function withdrawFromLendingPlatform(
        ISmartWalletImplementation.WithdrawFromLendingPlatformParams calldata params
    ) external override nonReentrant returns (uint256 returnedAmount) {
        require(supportedLendings.contains(params.lendingContract), "unsupported lending");

        IERC20Ext lendingToken = IERC20Ext(ILending(params.lendingContract).getLendingToken(params.token));
        require(lendingToken != IERC20Ext(0), "unsupported token");

        // AAVE aToken's transfer logic could have rounding errors
        uint256 tokenBalanceBefore = lendingToken.balanceOf(params.lendingContract);
        lendingToken.safeTransferFrom(msg.sender, params.lendingContract, params.amount);
        uint256 tokenBalanceAfter = lendingToken.balanceOf(params.lendingContract);

        returnedAmount = ILending(params.lendingContract).withdrawFrom(
            msg.sender,
            params.token,
            tokenBalanceAfter.sub(tokenBalanceBefore),
            params.minReturn
        );

        emit WithdrawFromLending(
            msg.sender,
            params.lendingContract,
            params.token,
            params.amount,
            params.minReturn,
            returnedAmount
        );
    }

    /// @dev swap and repay borrow for sender
    function swapAndRepay(
        ISmartWalletImplementation.SwapAndRepayParams calldata params
    ) external payable override nonReentrant returns (uint256 destAmount) {
        require(params.tradePath.length >= 1, "invalid tradePath");
        require(supportedLendings.contains(params.lendingContract), "unsupported lending");
        
        // use user debt value if debt is <= payAmount
        // user can pay all debt by putting really high payAmount as param
        uint256 actualPayAmount = checkUserDebt(
            params.lendingContract, params.tradePath[params.tradePath.length - 1], params.payAmount
        );
        
        if (params.tradePath.length == 1) {
            // just collect src token, no need to swap
            validateSourceAmount(params.tradePath[0], params.srcAmount);
            destAmount = safeTransferWithFee(
                msg.sender, 
                params.lendingContract, 
                params.tradePath[0],
                params.srcAmount,
                // Not taking repay fee
                0, 
                params.platformWallet
            );
        } else {
            destAmount = swapInternal(
                params.swapContract,
                params.srcAmount,
                actualPayAmount,
                params.tradePath,
                params.lendingContract,
                params.feeMode,
                params.feeBps,
                params.platformWallet,                    
                params.extraArgs
            );
        }
        {
            ILending(params.lendingContract).repayBorrowTo(
                msg.sender,
                IERC20Ext(params.tradePath[params.tradePath.length - 1]),
                destAmount,
                actualPayAmount,
                abi.encodePacked(params.rateMode)
            );
        }

        emit SwapAndRepay(
            msg.sender,
            params.swapContract,
            params.lendingContract,
            params.tradePath,
            params.srcAmount,
            destAmount,
            actualPayAmount,
            params.feeBps,
            params.platformWallet
        );
    }

    function swapInternal(
        address payable swapContract,
        uint256 srcAmount,
        uint256 minDestAmount,
        address[] calldata tradePath,
        address payable recipient,
        FeeMode feeMode,
        uint256 platformFee,
        address payable platformWallet,
        bytes calldata extraArgs
    ) internal returns (uint256 destAmount) {
        require(supportedSwaps.contains(swapContract), "unsupported swap");
        require(tradePath.length >= 2, "invalid tradePath");
        require(platformFee < BPS, "high platform fee");

        validateSourceAmount(tradePath[0], srcAmount);

        uint256 actualSrcAmount = safeTransferWithFee(
            msg.sender, 
            swapContract, 
            tradePath[0], 
            srcAmount,
            feeMode == FeeMode.FROM_SOURCE ? platformFee : 0,
            platformWallet
        );

        {
            // to avoid stack too deep
            // who will receive the swapped token
            address _recipient = feeMode == FeeMode.FROM_DEST ? address(this) : recipient;
            destAmount = ISwap(swapContract).swap(
                ISwap.SwapParams({
                    srcAmount: actualSrcAmount,
                    minDestAmount: minDestAmount,
                    tradePath: tradePath,
                    recipient: _recipient,
                    feeBps: feeMode == FeeMode.BY_PROTOCOL ? platformFee : 0,
                    feeReceiver: platformWallet,
                    extraArgs: extraArgs
                })
            );
        }

        if (feeMode == FeeMode.FROM_DEST) {
            destAmount = safeTransferWithFee(
                address(this), 
                recipient,
                tradePath[tradePath.length - 1], 
                destAmount, 
                platformFee, 
                platformWallet
            );         
        }
    }

    function validateSourceAmount(
        address srcToken,
        uint256 srcAmount
    ) internal {
        if (srcToken == address(ETH_TOKEN_ADDRESS)) {
            require(msg.value == srcAmount, "wrong msg value");
        } else {
            require(msg.value == 0, "bad msg value");
        }
    }

    function transferToken(
        address payable to,
        IERC20Ext token,
        uint256 amount
    ) internal {
        if (amount == 0) return;
        if (token == ETH_TOKEN_ADDRESS) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "transfer failed");
        } else {
            token.safeTransfer(to, amount);
        }
    }

    function safeTransferWithFee(
        address payable from,
        address payable to,
        address token,
        uint256 amount,
        uint256 platformFeeBps,
        address payable platformWallet
    ) internal returns (uint256 amountTransferred) {
        uint256 fee = amount.mul(platformFeeBps).div(BPS);
        uint256 amountAfterFee = amount.sub(fee);
        IERC20Ext tokenErc = IERC20Ext(token);

        if (tokenErc == ETH_TOKEN_ADDRESS) {
            (bool success, ) = to.call{value: amountAfterFee}("");
            require(success, "transfer failed");
            amountTransferred = amountAfterFee;
        } else {
            uint256 balanceBefore = tokenErc.balanceOf(to);
            if (from != address(this)) {
                // case transfer from another address, need to transfer fee to this proxy contract
                tokenErc.safeTransferFrom(from, to, amountAfterFee);
                tokenErc.safeTransferFrom(from, address(this), fee);
            } else {
                tokenErc.safeTransfer(to, amountAfterFee);
            }
            amountTransferred = tokenErc.balanceOf(to).sub(balanceBefore);
        }

        addFeeToPlatform(platformWallet, tokenErc, fee);
    }

    function addFeeToPlatform(
        address payable platformWallet,
        IERC20Ext token,
        uint256 amount
    ) internal {
        if (amount > 0) {
            require(supportedPlatformWallets.contains(platformWallet), "unsupported platform");
            platformWalletFees[platformWallet][token] = platformWalletFees[platformWallet][token].add(amount);
        }
    }

    function checkUserDebt(
        address payable lendingContract,
        address token,
        uint256 amount
    ) internal returns (uint256) {
        uint256 debt = ILending(lendingContract).getUserDebtCurrent(token, msg.sender);
        return debt >= amount ? amount : debt;
    }
}
