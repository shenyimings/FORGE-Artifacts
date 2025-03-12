// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IMasterRadpie } from "../IMasterRadpie.sol";

interface IMasterRadpieReader is IMasterRadpie {

    struct RadpiePoolInfo {
        address stakingToken; // Address of staking token contract to be staked.
        address receiptToken; // Address of receipt token contract represent a staking position
        uint256 allocPoint; // How many allocation points assigned to this pool. Penpies to distribute per second.
        uint256 lastRewardTimestamp; // Last timestamp that Penpies distribution occurs.
        uint256 accPenpiePerShare; // Accumulated Penpies per share, times 1e12. See below.
        uint256 totalStaked;
        address rewarder;
        bool    isActive;         
    }

    function tokenToPoolInfo(address) external view returns (RadpiePoolInfo memory);

    function legacyRewarders(address) external view returns (address);

    function legacyRewarderClaimed(address, address) external view returns (bool);
    
    function vlRadpie() external view returns (address);

}