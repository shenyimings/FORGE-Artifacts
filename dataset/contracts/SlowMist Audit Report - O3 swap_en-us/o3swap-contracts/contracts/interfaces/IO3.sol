// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.0;

import "../libs/token/ERC20/IERC20.sol";

interface IO3 is IERC20 {
    function getUnlockFactor(address token) external view returns (uint256);
    function getUnlockBlockGap(address token) external view returns (uint256);

    function totalUnlocked() external view returns (uint256);
    function unlockedOf(address account) external view returns (uint256);
    function lockedOf(address account) external view returns (uint256);

    function getStaked(address token) external view returns (uint256);
    function getUnlockSpeed(address staker, address token) external view returns (uint256);
    function claimableUnlocked(address token) external view returns (uint256);

    function setUnlockFactor(address token, uint256 _factor) external;
    function setUnlockBlockGap(address token, uint256 _blockGap) external;

    function stake(address token, uint256 amount) external returns (bool);
    function unstake(address token, uint256 amount) external returns (bool);
    function claimUnlocked(address token) external returns (bool);

    function setAuthorizedMintCaller(address caller) external;
    function removeAuthorizedMintCaller(address caller) external;

    function mintUnlockedToken(address to, uint256 amount) external;
    function mintLockedToken(address to, uint256 amount) external;
}
