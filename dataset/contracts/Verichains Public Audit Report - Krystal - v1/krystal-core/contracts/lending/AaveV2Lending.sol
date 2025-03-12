// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/aave/IProtocolDataProvider.sol";
import "../interfaces/aave/IAaveLendingPoolV2.sol";
import "../interfaces/IWeth.sol";
import "../libraries/BytesLib.sol";
import "./BaseLending.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@kyber.network/utils-sc/contracts/IERC20Ext.sol";

contract AaveV2Lending is BaseLending {
    using SafeERC20 for IERC20Ext;
    using SafeMath for uint256;
    using BytesLib for bytes;

    struct AaveData {
        IProtocolDataProvider provider;
        IWeth weth;
        IAaveLendingPoolV2 lendingPoolV2;
        mapping(IERC20Ext => address) aTokensV2;
        uint16 referalCode;
    }

    AaveData public aaveData;

    constructor(address _admin) BaseLending(_admin) {}

    function updateAaveData(
        IProtocolDataProvider provider,
        IAaveLendingPoolV2 poolV2,
        uint16 referalCode,
        IWeth weth,
        IERC20Ext[] calldata tokens
    ) external onlyAdmin {
        require(provider != IProtocolDataProvider(0), "invalid_provider");
        require(poolV2 != IAaveLendingPoolV2(0), "invalid_poolV2");
        require(weth != IWeth(0), "invalid_weth");

        if (aaveData.provider != provider) {
            aaveData.provider = provider;
        }
        if (aaveData.lendingPoolV2 != poolV2) {
            aaveData.lendingPoolV2 = poolV2;
        }
        if (aaveData.referalCode != referalCode) {
            aaveData.referalCode = referalCode;
        }
        if (aaveData.weth != weth) {
            aaveData.weth = weth;
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i] == ETH_TOKEN_ADDRESS ? address(weth) : address(tokens[i]);
            // update data for pool v2
            try poolV2.getReserveData(token) returns (DataTypes.ReserveData memory data) {
                if (aaveData.aTokensV2[tokens[i]] != data.aTokenAddress) {
                    aaveData.aTokensV2[tokens[i]] = data.aTokenAddress;
                    safeApproveAllowance(address(poolV2), tokens[i]);
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
        if (token == ETH_TOKEN_ADDRESS) {
            // wrap eth -> weth, then deposit
            IWeth weth = aaveData.weth;
            weth.deposit{value: amount}();
            aaveData.lendingPoolV2.deposit(
                address(weth),
                amount,
                onBehalfOf,
                aaveData.referalCode
            );
        } else {
            aaveData.lendingPoolV2.deposit(
                address(token),
                amount,
                onBehalfOf,
                aaveData.referalCode
            );
        }
    }

    /// @dev withdraw from lending platforms
    ///     expect amount of aToken or cToken should already be in the contract
    function withdrawFrom(
        address payable onBehalfOf,
        IERC20Ext token,
        uint256 amount,
        uint256 minReturn
    ) external override onlyProxyContract returns (uint256 returnedAmount) {
        uint256 tokenBalanceBefore;
        uint256 tokenBalanceAfter;

        if (token == ETH_TOKEN_ADDRESS) {
            // withdraw weth, then convert to eth for user
            address weth = address(aaveData.weth);
            // withdraw underlying token from pool
            tokenBalanceBefore = IERC20Ext(weth).balanceOf(address(this));
            returnedAmount = aaveData.lendingPoolV2.withdraw(weth, amount, address(this));
            tokenBalanceAfter = IERC20Ext(weth).balanceOf(address(this));
            require(tokenBalanceAfter.sub(tokenBalanceBefore) >= returnedAmount, "invalid return");
            require(returnedAmount >= minReturn, "low returned amount");
            // convert weth to eth and transfer to sender
            IWeth(weth).withdraw(returnedAmount);
            (bool success, ) = onBehalfOf.call{value: returnedAmount}("");
            require(success, "transfer eth to sender failed");
        } else {
            // withdraw token directly to user's wallet
            tokenBalanceBefore = getBalance(token, onBehalfOf);
            returnedAmount = aaveData.lendingPoolV2.withdraw(address(token), amount, onBehalfOf);
            tokenBalanceAfter = getBalance(token, onBehalfOf);
            // valid received amount in user's wallet
            require(tokenBalanceAfter.sub(tokenBalanceBefore) >= returnedAmount, "invalid return");
            require(returnedAmount >= minReturn, "low returned amount");
        }
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

        uint256 rateMode = extraArgs.toUint256(0);

        if (token == ETH_TOKEN_ADDRESS) {
            IWeth weth = aaveData.weth;
            weth.deposit{value: payAmount}();
            require(
                aaveData.lendingPoolV2.repay(address(weth), payAmount, rateMode, onBehalfOf) ==
                    payAmount,
                "wrong paid amount"
            );
        } else {
            require(
                aaveData.lendingPoolV2.repay(address(token), payAmount, rateMode, onBehalfOf) ==
                    payAmount,
                "wrong paid amount"
            );
        }
    }

    function getLendingToken(IERC20Ext token) public view override returns (address) {
        return aaveData.aTokensV2[token];
    }

    /** @dev Calculate the current user debt and return
     */
    function getUserDebtCurrent(address _reserve, address _user)
        external
        view
        override
        returns (uint256 debt)
    {
        (, uint256 stableDebt, uint256 variableDebt, , , , , , ) = aaveData
        .provider
        .getUserReserveData(_reserve, _user);
        debt = stableDebt > 0 ? stableDebt : variableDebt;
    }
}
