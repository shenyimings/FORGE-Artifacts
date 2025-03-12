// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IArkenSmithy {
    struct PoolInfo {
        uint256 lastRewardBlock;
        uint256 endRewardBlock; // zero means no end block
        uint256 accumulatedArken;
        uint256 arkenPerBlock;
    }

    function poolsCount() external view returns (uint256);

    function pendingArken(uint256 _pid) external view returns (uint256 amount);

    function lastRewardBlock(uint256 _pid) external view returns (uint256);

    function arkenPerBlock(uint256 _pid) external view returns (uint256);

    function endRewardBlock(uint256 _pid) external view returns (uint256);

    function massUpdatePools() external;

    function updatePool(uint256 _pid) external returns (PoolInfo memory pool);

    function withdraw(
        address _to,
        uint256 _pid,
        uint256 _amount
    ) external;

    function getReward(
        uint256 pid,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns (uint256 amount);

    function getRewardPerBlock(uint256 pid, uint256 blockNumber)
        external
        view
        returns (uint256 amount);
}
