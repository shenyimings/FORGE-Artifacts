pragma solidity ^0.6.6;

import "../interfaces/IEchodexFarm.sol";
import "../interfaces/IERC20.sol";

contract ReentrantHarvestTest {
    IEchodexFarm echodexFarm;
    IERC20 lpToken;
    uint poolId = 0;
    uint loop = 1;

    constructor (address _echodexFarm, address _lpToken) public {
        echodexFarm = IEchodexFarm(_echodexFarm);
        lpToken = IERC20(_lpToken);
    }

    function stake() public {
        // aprove lp token
        lpToken.approve(address(echodexFarm), 1 * 10**18);
        // stake token
        echodexFarm.stake(poolId, 1 * 10**18);
    }

    function reentrantHarvest () public {
        echodexFarm.harvest(poolId);
    }

    receive() external payable {
        if(address(echodexFarm).balance >= 2584800 * 10**18) {
            echodexFarm.harvest(poolId);
        }
    }
}