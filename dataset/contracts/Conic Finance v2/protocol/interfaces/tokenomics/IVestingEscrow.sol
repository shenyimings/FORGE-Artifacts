// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IVestingEscrow {
    event Fund(address indexed recipient, uint256 reward);
    event Claim(address indexed user, uint256 amount);
    event SupplyInitialized(uint256 amount);

    function setUnallocatedSupply() external;

    function setupVesting(
        address[] calldata _recipient,
        uint256[] calldata _amount
    ) external returns (bool);

    function vestedSupply() external view returns (uint256);

    function lockedSupply() external view returns (uint256);

    function vestedOf(address _recipient) external view returns (uint256);

    function balanceOf(address _recipient) external view returns (uint256);

    function lockedOf(address _recipient) external view returns (uint256);

    function claim() external;
}
