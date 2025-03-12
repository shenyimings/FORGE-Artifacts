// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../utils/BlueBerryErrors.sol" as Errors;
import "../utils/BlueBerryConst.sol" as Constants;

/**
 * @author BlueberryProtocol
 * @title BaseAdapter
 * @notice Base Adapter Contract which interacts with external oracle services
 */
abstract contract BaseAdapter is Ownable {
    /// @dev Mapping from token address to time gaps
    mapping(address => uint256) public timeGaps;

    event SetTimeGap(address token, uint256 gap);

    /// @notice Set time gap of price feed for each token
    /// @param tokens List of remapped tokens to set time gap
    /// @param gaps List of time gaps to set to
    function setTimeGap(
        address[] calldata tokens,
        uint256[] calldata gaps
    ) external onlyOwner {
        if (tokens.length != gaps.length) revert Errors.INPUT_ARRAY_MISMATCH();
        for (uint256 idx = 0; idx < tokens.length; idx++) {
            if (gaps[idx] > Constants.MAX_TIME_GAP)
                revert Errors.TOO_LONG_DELAY(gaps[idx]);
            if (gaps[idx] < Constants.MIN_TIME_GAP)
                revert Errors.TOO_LOW_MEAN(gaps[idx]);
            if (tokens[idx] == address(0)) revert Errors.ZERO_ADDRESS();
            timeGaps[tokens[idx]] = gaps[idx];
            emit SetTimeGap(tokens[idx], gaps[idx]);
        }
    }
}
