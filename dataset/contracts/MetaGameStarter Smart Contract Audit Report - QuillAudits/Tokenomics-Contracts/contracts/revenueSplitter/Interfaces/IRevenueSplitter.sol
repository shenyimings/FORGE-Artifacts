// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


interface IRevenueSplitter {

    struct Shareholder {
        address account;
        uint256 shares;
    }

    /// @dev reverts on baseToken as input
    /// @dev reverts if token has no swapping path defined (`_swappingPaths[token]`)
    function distributeMany(IERC20[] memory tokens) external;

    /// @dev reverts on baseToken as input
    /// @dev reverts if token has no swapping path defined (`_swappingPaths[token]`)
    function distributeSingle(address token) external;

    /// @dev distributes all base tokens to the baseTokenReceivers
    function distributeBaseToken() external;

    //// owner functionality ////
    function addRawTokenReceiver(Shareholder memory shareholder) external;
    function addBaseTokenReceiver(Shareholder memory shareholder) external;
    function updateRawTokenReceiver(uint256 index, Shareholder memory shareholder) external;
    function updateBaseTokenReceiver(uint256 index, Shareholder memory shareholder) external;
    function removeRawTokenReceiver(uint256 index) external;
    function removeBaseTokenReceiver(uint256 index) external;
    /// @dev set the uniswap swapping path for token => baseToken
    function setSwappingPath(address token, bytes memory path) external;

    //// view ////

    function balanceOfToken(address token) external view returns(uint256);
    function getAllBaseTokenReceiver() external view returns(Shareholder[] memory);
    function getAllRawTokenReceiver() external view returns(Shareholder[] memory);
}