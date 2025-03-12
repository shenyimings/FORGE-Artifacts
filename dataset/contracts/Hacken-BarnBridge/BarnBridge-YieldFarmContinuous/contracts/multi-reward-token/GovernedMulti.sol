// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract GovernedMulti is Ownable {
    IERC20[] public rewardTokens;
    IERC20 public poolToken;

    uint256 public numRewardTokens;
    mapping(address => address) public rewardSources;
    mapping(address => uint256) public rewardRatesPerSecond;

    mapping(address => uint256) public lastSoftPullTs;

    function approveNewRewardToken(address token) public {
        require(msg.sender == owner(), "only owner can call");
        require(!isApprovedToken(token), "token already approved");
        require(token != address(poolToken), "reward token and pool token must be different");

        rewardTokens.push(IERC20(token));
        numRewardTokens++;
    }

    function setRewardSource(address token, address src) public {
        require(msg.sender == owner(), "only owner can call");
        require(src != address(0), "source cannot be 0x0");
        require(isApprovedToken(token), "token not approved");

        rewardSources[token] = src;
    }

    function setRewardRatePerSecond(address token, uint256 rate) public {
        require(msg.sender == owner(), "only owner can call");
        require(isApprovedToken(token), "token not approved");

        // pull everything due until now to not be affected by the change in rate
        pullRewardFromSource(token);

        rewardRatesPerSecond[token] = rate;

        // it's the first time the rate is set which is equivalent to starting the rewards
        if (lastSoftPullTs[token] == 0) {
            lastSoftPullTs[token] = block.timestamp;
        }
    }

    function isApprovedToken(address token) public view returns (bool) {
        // the number of reward tokens should not be very big and the approve operation should not be very frequent
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (address(rewardTokens[i]) == token) {
                return true;
            }
        }

        return false;
    }

    function pullRewardFromSource(address token) public virtual;
}
