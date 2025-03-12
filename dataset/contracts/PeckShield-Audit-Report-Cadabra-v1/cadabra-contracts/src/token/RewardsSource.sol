// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;
import {IRewardsSource} from "../interfaces/IRewardsSource.sol";
import "openzeppelin/interfaces/IERC20.sol";

interface IAbraStaking {
    function abra() external view returns (address);
}

/**
 * @dev used by AbraStaking to distribute rewards among holders of ve-token.
 */
contract RewardsSource is IRewardsSource {
    IERC20 public immutable ABRA;
    address public immutable staking;
    
    modifier onlyStaking {
        require(msg.sender == staking, 'RewardsSource: onlyStaking');
        _;
    }

    constructor(address _staking) {
        staking = _staking;
        ABRA = IERC20(IAbraStaking(_staking).abra());
    }
    
    function previewRewards() public view returns(uint) {
        return ABRA.balanceOf(address(this));
    }

    function collectRewards() external onlyStaking() {
        ABRA.transfer(staking, previewRewards());
    }
    
}