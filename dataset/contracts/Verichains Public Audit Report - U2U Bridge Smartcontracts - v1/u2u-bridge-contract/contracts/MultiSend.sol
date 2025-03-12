// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface Bridge{
    function lockToken(
        address token,
        address toAccount,
        uint256 amount
    ) external;
}

contract MultiSend is Ownable  {

    function approve(address token ,address contractBridge, uint256 amount) external onlyOwner() {
        ERC20(token).approve(contractBridge, amount);
    }

    function multiSend(address token, address bridgeAdd, address[] memory toAdd, uint256 amount)  external onlyOwner {
        Bridge bridge1 = Bridge(bridgeAdd);
        for(uint256 i=0;i<toAdd.length;i++){
           bridge1.lockToken(token, toAdd[i], amount);
        }

    }

}