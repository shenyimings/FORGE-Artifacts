// SPDX-License-Identifier: MIT

/*------------------------------------------------------------------------------------------
████████████████████████████████████████████████████████████████████████████████████████████
█─▄─▄─█▄─▄▄▀█─▄▄─█▄─▄▄─█▄─▄█─▄▄▄─██▀▄─██▄─▄█████▄─▄▄─█▄─▄█▄─▀█▄─▄██▀▄─██▄─▀█▄─▄█─▄▄▄─█▄─▄▄─█
███─████─▄─▄█─██─██─▄▄▄██─██─███▀██─▀─███─██▀████─▄████─███─█▄▀─███─▀─███─█▄▀─██─███▀██─▄█▀█
▀▀▄▄▄▀▀▄▄▀▄▄▀▄▄▄▄▀▄▄▄▀▀▀▄▄▄▀▄▄▄▄▄▀▄▄▀▄▄▀▄▄▄▄▄▀▀▀▄▄▄▀▀▀▄▄▄▀▄▄▄▀▀▄▄▀▄▄▀▄▄▀▄▄▄▀▀▄▄▀▄▄▄▄▄▀▄▄▄▄▄▀
-------------------------------------------------------------------------------------------*/

pragma solidity >=0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Operable.sol";

// Tropical Finance Timelock

abstract contract TimeLock is Ownable, Operable {
    uint unlockAtBlock = 0;
    uint mintUnlockAtBlock = 0;

    modifier timeLock() {
        require(block.number >= unlockAtBlock, "Tropical::TimeLock: Function is timelocked");
        _;
    }

    modifier mintLock() {
        require(block.number >= mintUnlockAtBlock, "Tropical::TimeLock: Function is timelocked");
        _;
    }

    function lockTime(uint _unlockAtBlock) public onlyOperator timeLock {
        unlockAtBlock = _unlockAtBlock;
    }

    function lockMint(uint _mintUnlockAtBlock) public onlyOwner mintLock {
        mintUnlockAtBlock = _mintUnlockAtBlock;
    }
    
    function getUnlockAtBlock() public view returns (uint) {
        return unlockAtBlock;
    }

    function getMintUnlockAtBlock() public view returns (uint) {
        return mintUnlockAtBlock;
    }

}