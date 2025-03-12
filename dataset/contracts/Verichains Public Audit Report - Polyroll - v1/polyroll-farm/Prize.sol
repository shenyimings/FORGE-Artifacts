// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";

// Contract for storing prize pool from yield farm lottery
contract Prize is Ownable {
    using SafeERC20 for IERC20;

    address public masterChef;

    constructor() public {}

    function setMasterChef(address _masterChef) external onlyOwner {
        masterChef = _masterChef;
    }
    
    modifier onlyMasterChef {
        require(msg.sender == masterChef, "Only MasterChef can call function");
        _;
    }

    function transferPrize(address _recipient, IERC20 _tokenAddress, uint256 _amount) external onlyMasterChef {
        IERC20(_tokenAddress).safeTransfer(_recipient, _amount);
    }
}
