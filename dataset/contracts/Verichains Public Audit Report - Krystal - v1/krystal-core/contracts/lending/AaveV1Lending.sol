// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/aave/IAaveLendingPoolV1.sol";
import "../interfaces/aave/ILendingPoolCore.sol";
import "./BaseLending.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@kyber.network/utils-sc/contracts/IERC20Ext.sol";

contract AaveV1Lending is BaseLending {
    using SafeERC20 for IERC20Ext;
    using SafeMath for uint256;

    struct AaveData {
        IAaveLendingPoolV1 lendingPoolV1;
        mapping(IERC20Ext => address) aTokensV1;
        uint16 referalCode;
    }

    AaveData public aaveData;

    constructor(address _admin) BaseLending(_admin) {}

    function updateAaveData(
        IAaveLendingPoolV1 poolV1,
        address lendingPoolCoreV1,
        uint16 referalCode,
        IERC20Ext[] calldata tokens
    ) external onlyAdmin {
        require(poolV1 != IAaveLendingPoolV1(0), "invalid_poolV1");
        require(lendingPoolCoreV1 != address(0), "invalid_lendingPoolCoreV1");

        if (aaveData.lendingPoolV1 != poolV1) {
            aaveData.lendingPoolV1 = poolV1;
        }
        if (aaveData.referalCode != referalCode) {
            aaveData.referalCode = referalCode;
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            try
                ILendingPoolCore(poolV1.core()).getReserveATokenAddress(address(tokens[i]))
            returns (address aToken) {
                if (aaveData.aTokensV1[tokens[i]] != aToken) {
                    aaveData.aTokensV1[tokens[i]] = aToken;
                    safeApproveAllowance(lendingPoolCoreV1, tokens[i]);
                }
            } catch {}
        }
    }

    /// @dev deposit to lending platforms
    ///     expect amount of token should already be in the contract
    function depositTo(
        address payable onBehalfOf,
        IERC20Ext token,
        uint256 amount
    ) external override onlyProxyContract {
        require(getBalance(token, address(this)) >= amount, "low balance");
        IERC20Ext aToken = IERC20Ext(aaveData.aTokensV1[token]);
        require(aToken != IERC20Ext(0), "aToken not found");

        // deposit and compute received aToken amount
        uint256 aTokenBalanceBefore = aToken.balanceOf(address(this));
        aaveData.lendingPoolV1.deposit{value: token == ETH_TOKEN_ADDRESS ? amount : 0}(
            address(token),
            amount,
            aaveData.referalCode
        );
        uint256 aTokenBalanceAfter = aToken.balanceOf(address(this));
        // transfer all received aToken back to the sender
        aToken.safeTransfer(onBehalfOf, aTokenBalanceAfter.sub(aTokenBalanceBefore));
    }

    /// @dev withdraw from lending platforms
    ///     expect amount of aToken or cToken should already be in the contract
    function withdrawFrom(
        address payable onBehalfOf,
        IERC20Ext token,
        uint256 amount,
        uint256 minReturn
    ) external override onlyProxyContract returns (uint256 returnedAmount) {
        address lendingToken = getLendingToken(token);
        uint256 tokenBalanceBefore = getBalance(token, address(this));
        IAToken(lendingToken).redeem(amount);
        uint256 tokenBalanceAfter = getBalance(token, address(this));
        returnedAmount = tokenBalanceAfter.sub(tokenBalanceBefore);
        require(returnedAmount >= minReturn, "low returned amount");
        // transfer token to user
        transferToken(onBehalfOf, token, returnedAmount);
    }

    /// @dev repay borrows to lending platforms
    ///     expect amount of token should already be in the contract
    ///     if amount > payAmount, (amount - payAmount) will be sent back to user
    function repayBorrowTo(
        address payable onBehalfOf,
        IERC20Ext token,
        uint256 amount,
        uint256 payAmount,
        bytes calldata extraArgs
    ) external override onlyProxyContract {
        require(amount >= payAmount, "invalid pay amount");
        require(getBalance(token, address(this)) >= amount, "bad token balance");

        if (amount > payAmount) {
            // transfer back token
            transferToken(payable(onBehalfOf), token, amount - payAmount);
        }

        aaveData.lendingPoolV1.repay{value: token == ETH_TOKEN_ADDRESS ? payAmount : 0}(
            address(token),
            payAmount,
            onBehalfOf
        );
    }

    function getLendingToken(IERC20Ext token) public view override returns (address) {
        return aaveData.aTokensV1[token];
    }

    /** @dev Calculate the current user debt and return
     */
    function getUserDebtCurrent(address _reserve, address _user)
        external
        view
        override
        returns (uint256 debt)
    {
        uint256 originationFee;
        (, debt, , , , , originationFee, , , ) = aaveData.lendingPoolV1.getUserReserveData(
            _reserve,
            _user
        );
        debt = debt.add(originationFee);
    }
}
