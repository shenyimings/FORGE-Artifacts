// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStakingPool {
    function asset() external returns (IERC20);
}

contract StakingTester {
    using Address for address;
    address public stakingPool;

    constructor(address _stakingPool) {
        stakingPool = _stakingPool;
    }

    function syncTwiceInSameBlock() external {
        stakingPool.functionCall(abi.encodeWithSignature("sync()"));
        stakingPool.functionCall(abi.encodeWithSignature("sync()"));
    }

    function stakeAndRestake(
        uint256 amount,
        uint256 stakePeriod,
        uint256 restakePeriod
    ) external {
        IStakingPool _stakingPool = IStakingPool(stakingPool);
        IERC20 asset = _stakingPool.asset();

        asset.approve(stakingPool, type(uint256).max);

        stakingPool.functionCall(
            abi.encodeWithSignature(
                "stake(uint256,uint256)",
                amount,
                stakePeriod
            )
        );
        stakingPool.functionCall(
            abi.encodeWithSignature(
                "restake(uint256,uint256)",
                0,
                restakePeriod
            )
        );
    }

    function votingWeight(address) external pure returns (uint256) {
        return 10 ^ 8 ether;
    }
}
