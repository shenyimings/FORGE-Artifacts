// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

contract PrivateSaleTokenDistributor is Ownable2StepUpgradeable {
    IERC20 public token;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public totalAmount;
    mapping (address beneficiary => uint256 claimAmount) public claimableAmounts;

    event CanClaim(address indexed beneficiary, uint256 amount);
    event HasClaimed(address indexed beneficiary, uint256 amount);
    event Swept(address receiver, uint256 amount);

    constructor(IERC20 _token, uint256 _startTime, uint256 _endTime) {
        _transferOwnership(_msgSender());

        token = _token;
        startTime = _startTime;
        endTime = _endTime;
    }

    function setClaimableAmounts(address[] calldata users, uint256[] calldata amounts) onlyOwner external {
        uint256 usersLength = users.length;
        require(usersLength == amounts.length, "setClaimableAmounts: User and amount list lengths must match!");
        
        uint256 totalClaimableAmount = 0;
        for (uint256 i = 0; i < usersLength; ) {
            address user = users[i];
            uint256 amount = amounts[i];
            claimableAmounts[user] = amount;
            emit CanClaim(user, amount);
            unchecked {
                totalClaimableAmount = totalClaimableAmount + amount;
                i += 1;
            }
        }

        require(token.balanceOf(address(this)) >= totalClaimableAmount, "Total claimable amount does not match");
        totalAmount = totalClaimableAmount;
    }

    function claim() external {
        require(block.timestamp >= startTime, "Tokens cannot be claimed yet");
        require(block.timestamp < endTime, "Distribution has ended");
        uint256 claimableAmount = claimableAmounts[_msgSender()];

        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "No tokens to claim");

        require(token.transfer(_msgSender(), claimableAmount), "Token transfer failed");
        claimableAmounts[_msgSender()] = 0;

        emit HasClaimed(_msgSender(), claimableAmount);
    }

    /**
    * @dev Transfer tokens from the contract to a given address.
    */
    function sweep() onlyOwner external {
        require(block.timestamp > endTime, "sweep: Cannot sweep before claim end time!");

        uint256 leftovers = token.balanceOf(address(this));
        require(leftovers != 0, "TokenDistributor: no leftovers");

        require(token.transfer(owner(), leftovers), "TokenDistributor: fail token transfer");

        emit Swept(owner(), leftovers);
    }
}