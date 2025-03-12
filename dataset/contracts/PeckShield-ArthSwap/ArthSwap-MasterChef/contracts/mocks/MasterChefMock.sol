// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "boring-solidity/contracts/libraries/BoringERC20.sol";
import {MasterChef} from "../MasterChef.sol";

contract MasterChefMock is MasterChef {
    constructor(
        IERC20 _ARSW,
        uint64 originBlock,
        uint256 blockPeriod
    ) public MasterChef(_ARSW) {
        ARTHSWAP_ORIGIN_BLOCK = originBlock;
        BLOCK_PER_PERIOD = blockPeriod;
    }

    function calculateAdditionalAccARSWPerShareTest(
        uint128 accARSWPerShare,
        uint64 lastRewardBlock,
        uint64 allocPoint,
        uint256 currentBlock,
        uint256 lpSupply
    ) external view returns (uint256 additionalAccARSWPerShare) {
        PoolInfo memory pool = PoolInfo(
            accARSWPerShare,
            lastRewardBlock,
            allocPoint
        );
        return calculateAdditionalAccARSWPerShare(pool, currentBlock, lpSupply);
    }

    function setTotalAllocPoint(uint256 point) public {
        totalAllocPoint = point;
    }

    function setOriginBlock(uint64 originBlock) public {
        ARTHSWAP_ORIGIN_BLOCK = originBlock;
    }

    function exposedCheckPoolDuplicate(IERC20 lpToken) public view {
        checkPoolDuplicate(lpToken);
    }
}
