// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@solarity/solidity-lib/libs/arrays/ArrayHelper.sol";
import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";

import "../../../interfaces/gov/IGovPool.sol";

import "../../../libs/utils/TokenBalance.sol";

library GovPoolCredit {
    using SafeERC20 for IERC20;
    using ArrayHelper for uint256[];
    using DecimalsConverter for *;
    using TokenBalance for address;

    function setCreditInfo(
        IGovPool.CreditInfo storage creditInfo,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external {
        require(
            tokens.length == amounts.length,
            "GPC: Number of tokens and amounts are not equal"
        );

        uint256 length = creditInfo.tokenList.length;

        for (uint256 i = 0; i < length; i++) {
            delete creditInfo.tokenInfo[creditInfo.tokenList[i]].monthLimit;
        }

        creditInfo.tokenList = tokens;

        for (uint256 i = 0; i < tokens.length; i++) {
            address currentToken = tokens[i];
            require(currentToken != address(0), "GPC: Token address could not be zero");

            creditInfo.tokenInfo[currentToken].monthLimit = amounts[i];
        }
    }

    function transferCreditAmount(
        IGovPool.CreditInfo storage creditInfo,
        address[] calldata tokens,
        uint256[] calldata amounts,
        address destination
    ) external {
        uint256 tokensLength = tokens.length;
        require(amounts.length == tokensLength, "GPC: Number of tokens and amounts are not equal");

        for (uint256 i = 0; i < tokensLength; i++) {
            address currentToken = tokens[i];
            uint256 currentAmount = amounts[i];
            uint256 tokenCredit = _getCreditBalanceForToken(creditInfo, currentToken);

            require(
                currentAmount <= tokenCredit,
                "GPC: Current credit permission < amount to withdraw"
            );

            creditInfo.tokenInfo[currentToken].timestamps.push(block.timestamp);
            uint256[] storage history = creditInfo.tokenInfo[currentToken].cumulativeAmounts;

            history.push(currentAmount + (history.length == 0 ? 0 : history[history.length - 1]));

            currentToken.sendFunds(destination, currentAmount);
        }
    }

    function getCreditInfo(
        IGovPool.CreditInfo storage creditInfo
    ) external view returns (IGovPool.CreditInfoView[] memory info) {
        uint256 infoLength = creditInfo.tokenList.length;
        info = new IGovPool.CreditInfoView[](infoLength);

        mapping(address => IGovPool.TokenCreditInfo) storage tokenInfo = creditInfo.tokenInfo;

        for (uint256 i = 0; i < infoLength; i++) {
            address currentToken = creditInfo.tokenList[i];
            uint256 monthLimit = tokenInfo[currentToken].monthLimit;

            info[i] = IGovPool.CreditInfoView({
                token: currentToken,
                monthLimit: monthLimit,
                currentWithdrawLimit: _getCreditBalanceForToken(creditInfo, currentToken)
            });
        }
    }

    function _getCreditBalanceForToken(
        IGovPool.CreditInfo storage creditInfo,
        address token
    ) internal view returns (uint256) {
        IGovPool.TokenCreditInfo storage tokenInfo = creditInfo.tokenInfo[token];
        uint256[] storage amounts = tokenInfo.cumulativeAmounts;
        uint256 historyLength = amounts.length;

        uint256 index = tokenInfo.timestamps.upperBound(_monthAgo());
        uint256 amountWithdrawn;

        if (index == historyLength) {
            return tokenInfo.monthLimit;
        }

        amountWithdrawn = amounts[historyLength - 1] - (index == 0 ? 0 : amounts[index - 1]);

        return
            amountWithdrawn >= tokenInfo.monthLimit ? 0 : tokenInfo.monthLimit - amountWithdrawn;
    }

    function _monthAgo() private view returns (uint256) {
        return block.timestamp - 30 days;
    }
}
