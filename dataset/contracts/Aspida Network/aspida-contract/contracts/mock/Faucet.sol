// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/**
 * @title Aspida's ether Faucet
 * @author Aspida engineer
 */
abstract contract Faucet {
    uint256 public allocateAmount;

    mapping(address => uint256) public userAllocates;

    function _setAllocateAmountInternal(uint256 _allocateAmount) internal virtual {
        require(_allocateAmount != allocateAmount, "_setAllocateAmountInternal: Cannot set the same value");
        allocateAmount = _allocateAmount;
    }

    function allocateTo() public virtual returns (uint256) {
        uint256 _allocateAmount;
        if (allocateAmount > userAllocates[msg.sender]) {
            _allocateAmount = allocateAmount - userAllocates[msg.sender];
            userAllocates[msg.sender] += _allocateAmount;
        }
        return _allocateAmount;
    }
}
