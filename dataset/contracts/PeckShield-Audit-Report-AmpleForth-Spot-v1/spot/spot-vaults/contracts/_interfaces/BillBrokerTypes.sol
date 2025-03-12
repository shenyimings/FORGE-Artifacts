// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/// @notice A data structure to define a geometric Line with two points.
struct Line {
    /// @notice x-coordinate of the first point.
    uint256 x1;
    /// @notice y-coordinate of the first point.
    uint256 y1;
    /// @notice x-coordinate of the second point.
    uint256 x2;
    /// @notice y-coordinate of the second point.
    uint256 y2;
}

/// @notice A data structure to define a numeric Range.
struct Range {
    /// @notice Lower bound of the range.
    uint256 lower;
    /// @notice Upper bound of the range.
    uint256 upper;
}

/// @notice A data structure to store various fees associated with BillBroker operations.
struct BillBrokerFees {
    /// @notice The percentage fee charged for minting BillBroker LP tokens.
    uint256 mintFeePerc;
    /// @notice The percentage fee charged for burning BillBroker LP tokens.
    uint256 burnFeePerc;
    /// @notice Range of fee percentages for swapping from perp tokens to USD.
    Range perpToUSDSwapFeePercs;
    /// @notice Range of fee percentages for swapping from USD to perp tokens.
    Range usdToPerpSwapFeePercs;
    /// @notice The percentage of the swap fees that goes to the protocol.
    uint256 protocolSwapSharePerc;
}

/// @notice A data structure to represent the BillBroker's reserve state.
struct ReserveState {
    /// @notice The reserve USD token balance.
    uint256 usdBalance;
    /// @notice The reserve perp token balance.
    uint256 perpBalance;
    /// @notice The price of USD tokens in dollars (or some common denomination).
    uint256 usdPrice;
    /// @notice The price of perp tokens in dollars (or some common denomination).
    uint256 perpPrice;
}
