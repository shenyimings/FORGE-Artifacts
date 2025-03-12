// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LaunchTestNet is ERC20Snapshot, Ownable {
        
    using SafeERC20 for ERC20;
            
    uint private constant MAX_SUPPLY = 3_000_000e18;
    uint private constant MAX_PER_ADDRESS = 10_000e18;

    constructor() ERC20("svLAUNCH_TN", "svLaunchTN") {
        _mint(address(this), MAX_SUPPLY);
    }
    
    mapping(address => uint) public faucetMap;
    
    function getFromFaucet() external {
        
        require(faucetMap[msg.sender] < MAX_PER_ADDRESS, "Exceeded max amount per address");
        uint amount = uint(keccak256(abi.encodePacked(MAX_PER_ADDRESS, msg.sender, block.difficulty, block.timestamp))) % MAX_PER_ADDRESS;
       
        uint balance = balanceOf(address(this));
        require(amount <= balance, "Insufficient tokens left");
        
        ERC20(address(this)).safeTransfer(msg.sender, amount); 
        
        faucetMap[msg.sender] += amount;
    }
    

    function snapshot() external returns (uint256) {
        return _snapshot();
    }
}