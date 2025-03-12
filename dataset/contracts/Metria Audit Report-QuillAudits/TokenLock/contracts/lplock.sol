// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenLock is Ownable {
    using SafeERC20 for IERC20; 
    address public beneficiary;
    uint256 public constant unlockTime = 1788546600;

    constructor(address _beneficiary) Ownable(msg.sender) {
        beneficiary = _beneficiary;
    }

    function isUnlocked() public view returns (bool) {
        return block.timestamp > unlockTime;
        
    }

    function updateBeneficiary(address _beneficiary) public onlyOwner {
        beneficiary = _beneficiary;
    }

    function claim(address _tokenAddr, uint256 _amount) public onlyOwner {
        require(isUnlocked(), "Tokens cannot be transferred while locked.");
        IERC20(_tokenAddr).safeTransfer(beneficiary, _amount); 
    }
}
