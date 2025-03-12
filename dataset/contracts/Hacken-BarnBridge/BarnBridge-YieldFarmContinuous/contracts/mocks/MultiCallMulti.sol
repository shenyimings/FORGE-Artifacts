// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.6;

import "../multi-reward-token/PoolMulti.sol";

contract MultiCallMulti {
    function call_pullRewardFromSource(address rewards) public {
        PoolMulti r = PoolMulti(rewards);

        r.pullRewardFromSource_allTokens();
        r.pullRewardFromSource_allTokens();
        r.pullRewardFromSource_allTokens();
    }
}
