// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IDCAInvestable } from "./IDCAInvestable.sol";
import { SwapLib } from "../libraries/SwapLib.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

interface IDCAStrategy is IDCAInvestable {
    error TooSmallDeposit();
    error PositionsLimitReached();
    error NothingToInvest();
    error NothingToWithdraw();

    event Deposit(address indexed sender, uint256 amount, uint256 amountSplit);
    event Invest(
        uint256 depositAmountSpent,
        uint256 bluechipReceived,
        uint256 investedAt,
        uint256 historicalIndex
    );
    event Withdraw(
        address indexed sender,
        uint256 withdrawnDeposit,
        uint256 withdrawnBluechip
    );
    event StatusChanged(
        BluechipInvestmentState indexed prevStatus,
        BluechipInvestmentState indexed newStatus
    );

    struct DCAStrategyInitArgs {
        DepositFee depositFee;
        address dcaInvestor;
        TokenInfo depositTokenInfo;
        uint256 investmentPeriod;
        uint256 lastInvestmentTimestamp;
        uint256 minDepositAmount;
        uint16 positionsLimit;
        SwapLib.Router router;
        address[] depositToBluechipSwapPath;
        address[] bluechipToDepositSwapPath;
    }

    struct DepositFee {
        address feeReceiver;
        uint16 fee; // .0000 number
    }

    struct TokenInfo {
        IERC20Upgradeable token;
        uint8 decimals;
    }

    struct Position {
        uint256 depositAmount;
        uint8 amountSplit;
        uint256 investedAt;
        uint256 investedAtHistoricalIndex;
    }

    struct DCADepositor {
        Position[] positions;
    }

    enum BluechipInvestmentState {
        Investing,
        Withdrawn,
        EmergencyExited
    }

    function invest() external;

    function canInvest() external view returns (bool);

    function depositorInfo(address depositor)
        external
        view
        returns (DCADepositor memory);

    function getInvestAmountAt(uint8 index) external view returns (uint256);

    function currentInvestQueueIndex() external view returns (uint8);

    function getHistoricalGaugeAt(uint256 index)
        external
        view
        returns (uint256, uint256);

    function currentDCAHistoryIndex() external view returns (uint256);
}
