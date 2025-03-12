// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Vesting is Ownable {
    using SafeERC20 for IERC20;

    event AmountRevoked(uint256 amountRemaining);
    event RecipientTransferred(address oldRecipient, address newRecipient);
    event AmountClaimed(uint256 claimed, uint256 amountRemaining);

    address public recipient;
    address public immutable mnt;
    uint256 public immutable start;
    uint256 public immutable cliffTimestamp;
    uint256 public immutable vestDuration;
    uint256 public immutable amount;
    bool public immutable canBeRevoked;

    uint256 public amountRemaining;

    modifier onlyRecipient() {
        require(msg.sender == recipient, 'Not Allowed');
        _;
    }

    constructor(
        address _mnt,
        address _recipient,
        uint256 _start,
        uint256 _cliffDuration,
        uint256 _vestDuration,
        uint256 _amount,
        bool _canBeRevoked
    ) {
        require(_mnt != address(0), "mnt zero address");
        require(_recipient != address(0), "recipient zero address");
        require(_start > 0, "start 0");
        require(_amount > 0, "amount 0");
        require(_vestDuration > 0, "duration 0");
        mnt = _mnt;
        recipient = _recipient;
        start = _start;
        cliffTimestamp = _start + _cliffDuration;
        vestDuration = _vestDuration;
        amount = _amount;
        amountRemaining = _amount;

        canBeRevoked = _canBeRevoked;
    }

    function revoke() external onlyOwner {
        require(canBeRevoked, "Cannot be revoked");
        emit AmountRevoked(amountRemaining);
        amountRemaining = 0;
    }

    function withdraw(address _token) external onlyOwner {
        uint256 contractBalance = IERC20(_token).balanceOf(address(this));
        require(contractBalance > 0, "Contract balance is already 0");
        if (_token == mnt) {
            require(contractBalance > amountRemaining, "Nothing to withdraw");
            uint256 safeAmount = contractBalance - amountRemaining;
            IERC20(_token).safeTransfer(msg.sender, safeAmount);
        } else {
            IERC20(_token).safeTransfer(msg.sender, contractBalance);
        }
    }

    function getTotalAmountVested() public view returns (uint256) {
        if (cliffTimestamp >= block.timestamp) {
            return 0;
        }
        uint256 vestTime = block.timestamp - cliffTimestamp;
        uint256 amountVested = amount * vestTime / vestDuration;
        if (amountVested > amount) {
            amountVested = amount;
        }
        return amountVested;
    }

    function getAmountClaimable() public view returns (uint256) {
        uint256 totalVested = getTotalAmountVested();
        uint256 amountPaid = amount - amountRemaining;
        return totalVested - amountPaid;
    }

    function claim() external onlyRecipient {
        uint256 claimable = getAmountClaimable();
        require(claimable > 0, "Nothing to claim");
        amountRemaining -= claimable;
        IERC20(mnt).safeTransfer(recipient, claimable);
        emit AmountClaimed(claimable, amountRemaining);
    }

    function transferRecipient(address _newRecipient) external onlyRecipient {
        emit RecipientTransferred(recipient, _newRecipient);
        require(_newRecipient != address(0), "recipient zero address");
        recipient = _newRecipient;
    }
}
