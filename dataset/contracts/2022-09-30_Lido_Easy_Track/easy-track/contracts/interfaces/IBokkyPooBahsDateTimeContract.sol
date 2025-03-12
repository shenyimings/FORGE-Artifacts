// SPDX-FileCopyrightText: 2022 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

/// @author zuzueeka
/// @notice Interface of methods from BokkyPooBahsDateTimeContract to deal with dates
interface IBokkyPooBahsDateTimeContract {
    function timestampToDate(uint256 timestamp)
        external
        pure
        returns (
            uint256 year,
            uint256 month,
            uint256 day
        );

    function timestampFromDate(
        uint256 year,
        uint256 month,
        uint256 day
    ) external pure returns (uint256 timestamp);

    function addMonths(uint256 timestamp, uint256 _months)
        external
        pure
        returns (uint256 newTimestamp);
}
