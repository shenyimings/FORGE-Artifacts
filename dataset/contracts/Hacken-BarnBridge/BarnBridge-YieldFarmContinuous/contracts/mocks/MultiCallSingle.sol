// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.6;

import "../single-reward-token/PoolSingle.sol";

contract MultiCallSingle {
    function call_pullRewardFromSource(address rewards) public {
        PoolSingle r = PoolSingle(rewards);

        r.pullRewardFromSource();
        r.pullRewardFromSource();
        r.pullRewardFromSource();
    }
}
