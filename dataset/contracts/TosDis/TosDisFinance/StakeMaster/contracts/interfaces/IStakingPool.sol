pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStakingPool {
    
    function getUserInfo(address user)
        external
        view
        returns (uint256, uint256);
    
}
