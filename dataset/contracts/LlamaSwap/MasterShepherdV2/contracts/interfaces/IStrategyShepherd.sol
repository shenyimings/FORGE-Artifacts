// SPDX-License-Identifier: WTFPL License
pragma solidity >=0.6.0;

interface IStrategyShepherd {
    // Total want tokens managed by stratfegy    
    function lpLockedTotal() external view returns (uint256);
        
    // Lp token compounding function
    function earn() external;

    // Transfer LP tokens from MasterShepherd to strategy
    function deposit(uint256 _lpAmount, address _account)
        external
        returns (uint256);

    // Transfer LP tokens from strategy back to MasterShepherd
    function withdraw(uint256 _lpAmount, address _account)
        external
        returns (uint256);

    //Owner can drain tokens that are sent here by mistake
    function drainStuckToken(address _token) external;
}