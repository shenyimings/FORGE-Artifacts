// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import './DydxFlashloanBase.sol';
import './ICallee.sol';
import '../../../modules/FoldingAccount/FoldingAccountStorage.sol';

abstract contract DyDxFlashModule is ICallee, DydxFlashloanBase, FoldingAccountStorage {
    using SafeERC20 for IERC20;

    address public immutable SELF_ADDRESS;
    address public immutable SOLO; //0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e;

    constructor(address soloAddress) public {
        require(soloAddress != address(0), 'ICP0');
        SELF_ADDRESS = address(this);
        SOLO = soloAddress;
    }

    struct LoanData {
        address loanedToken;
        uint256 loanAmount;
        uint256 repayAmount;
        bytes data;
    }

    function getFlashLoan(
        address tokenToLoan,
        uint256 flashLoanAmount,
        bytes memory data
    ) internal {
        uint256 marketId = _getMarketIdFromTokenAddress(SOLO, tokenToLoan);
        uint256 repayAmount = _getRepaymentAmountInternal(flashLoanAmount);

        Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);
        operations[0] = _getWithdrawAction(marketId, flashLoanAmount);
        operations[1] = _getCallAction(
            abi.encode(
                LoanData({
                    loanedToken: tokenToLoan,
                    loanAmount: flashLoanAmount,
                    repayAmount: repayAmount,
                    data: data
                })
            )
        );
        operations[2] = _getDepositAction(marketId, repayAmount);

        Account.Info[] memory accountInfos = new Account.Info[](1);
        accountInfos[0] = _getAccountInfo();

        // @dev Force callback to this connector
        aStore().callbackTarget = SELF_ADDRESS;
        aStore().expectedCallbackSig = bytes4(keccak256('callFunction(address,(address,uint256),bytes)'));

        IERC20(tokenToLoan).safeIncreaseAllowance(SOLO, repayAmount);
        ISoloMargin(SOLO).operate(accountInfos, operations);
        IERC20(tokenToLoan).safeApprove(SOLO, 0);
    }

    function callFunction(
        address sender,
        Account.Info calldata,
        bytes calldata data
    ) external override {
        require(address(msg.sender) == SOLO, 'DFM1');
        require(sender == address(this), 'DFM2');
        require(aStore().callbackTarget == SELF_ADDRESS, 'DFM3');

        // @dev Clear forced callback to this connector
        delete aStore().callbackTarget;
        delete aStore().expectedCallbackSig;

        LoanData memory loanData = abi.decode(data, (LoanData));
        useFlashLoan(loanData.loanedToken, loanData.loanAmount, loanData.repayAmount, loanData.data);
    }

    function useFlashLoan(
        address loanToken,
        uint256 loanAmount,
        uint256 repayAmount,
        bytes memory data
    ) internal virtual;
}
