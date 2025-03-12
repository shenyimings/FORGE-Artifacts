// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TimeLockedWallet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract TimeLockedWalletFactory is Ownable {

    mapping(address => address[]) wallets;
    address public _tokenAddress;
    address public _tlwAddress;

    constructor(address tokenAddress, address tlwAddress) {
        setTokenAddress(tokenAddress);
        setTLWAddress(tlwAddress);
    }

    function getWallets(address user) public view onlyOwner returns (address[] memory) {
        return wallets[user];
    }

    function setTokenAddress(address tokenAddress) public onlyOwner {
        _tokenAddress = tokenAddress;
    }

    function setTLWAddress(address tlwAddress) public onlyOwner {
        _tlwAddress = tlwAddress;
    }

    function newTimeLockedWallet(address owner, uint amount,
        uint numberOfPeriods, uint firstUnlockTime, uint periodDuration) public returns (address wallet) {
        _validateNewTimeLockedWallet(owner, amount, numberOfPeriods, firstUnlockTime, periodDuration);
        ERC20 token = ERC20(_tokenAddress);
        require(amount <= token.allowance(msg.sender, address(this)), "This factory contract should be approved to spend :amount of tokens");

        wallet = Clones.clone(_tlwAddress);
        require(token.transferFrom(msg.sender, wallet, amount), "Token transfer failed");
        TimeLockedWallet(wallet).initialize(owner, _tokenAddress, amount, numberOfPeriods, firstUnlockTime, periodDuration);

        wallets[msg.sender].push(wallet);
        if (msg.sender != owner) {
            wallets[owner].push(wallet);
        }
        emit Created(wallet, msg.sender, owner, amount, firstUnlockTime);
    }

    function _validateNewTimeLockedWallet(address owner, uint amount,
        uint numberOfPeriods, uint firstUnlockTime, uint periodDuration) private view {
        require(!Address.isContract(owner), "Owner should be externally-owned account and not a contract");
        require(amount > 0, "Amount should be at least 1");
        require(numberOfPeriods > 0, "There should be at least 1 unlock time");
        require(firstUnlockTime > block.timestamp, "Unlock time should be in the future");
        require(periodDuration >= 1 minutes, "Duration between periods should be at least 1 minute");
    }

    event Created(address wallet, address from, address to, uint amount, uint unlockTime);

}
