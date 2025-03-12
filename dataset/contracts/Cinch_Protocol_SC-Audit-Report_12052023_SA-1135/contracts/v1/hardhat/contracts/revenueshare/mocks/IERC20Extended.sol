// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/// @dev Putting this interface file inside the `mocks` folder to indicated that this is only used inside the mock contracts
interface IERC20Extended {
    function decimals() external view returns (uint8);
}
