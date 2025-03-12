// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract TimeLockedWallet is Initializable {

    struct LockBoxStruct {
        uint amount;
        uint unlockTime;
        bool paid;
    }

    address public _owner;
    address public _tokenAddress;
    LockBoxStruct[] public _lockBoxes;

    function initialize(address owner, address tokenAddress, uint amount,
        uint numberOfPeriods, uint firstUnlockTime, uint periodDuration) public initializer {
        _validateInitialize(owner, tokenAddress, amount, numberOfPeriods, firstUnlockTime);
        _owner = owner;
        _tokenAddress = tokenAddress;
        uint periodAmount = amount / numberOfPeriods;
        for (uint i = 0; i < numberOfPeriods; i++) {
            LockBoxStruct memory box;
            box.amount = periodAmount;
            box.unlockTime = firstUnlockTime + i * periodDuration;
            box.paid = false;
            _lockBoxes.push(box);
        }
        LockBoxStruct storage lastBox = _lockBoxes[numberOfPeriods - 1];
        lastBox.amount = lastBox.amount + amount % numberOfPeriods;
    }

    function lockedAmount() public view returns (uint amount) {
        for (uint i = 0; i < _lockBoxes.length; i++) {
            LockBoxStruct memory box = _lockBoxes[i];
            if (box.paid == false) {
                amount = amount + box.amount;
            }
        }
        return amount;
    }

    function readyToWithdraw() public view returns (uint amount) {
        for (uint i = 0; i < _lockBoxes.length; i++) {
            LockBoxStruct memory box = _lockBoxes[i];
            if (box.unlockTime <= block.timestamp && box.paid == false) {
                amount = amount + box.amount;
            }
        }
        return amount;
    }

    function withdraw() public {
        for (uint i = 0; i < _lockBoxes.length; i++) {
            LockBoxStruct storage box = _lockBoxes[i];
            if (box.unlockTime <= block.timestamp && box.paid == false) {
                box.paid = true;
                ERC20 token = ERC20(_tokenAddress);
                SafeERC20.safeTransfer(token, _owner, box.amount);
                emit Withdrawal(box.amount);
                return;
            }
        }
        revert("Nothing to withdraw");
    }

    function _validateInitialize(address owner, address tokenAddress, uint amount,
        uint numberOfPeriods, uint firstUnlockTime) private view {
        require(!Address.isContract(owner), "Owner should be externally-owned account and not a contract");
        require(ERC20(tokenAddress).balanceOf(address(this)) == amount, "Amount of tokens should already be transferred to this locked contract");
        require(numberOfPeriods > 0, "There should be at least 1 unlock time");
        require(firstUnlockTime > block.timestamp, "Unlock time should be in the future");
    }

    event Withdrawal(uint amount);

}
