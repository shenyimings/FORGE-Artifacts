// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;
import "./Context.sol";
import "./Ownable.sol";
import "./IBNBHPool.sol";
import "./IBEP20.sol";

contract BNBHPool is Context, IBNBHPool, Ownable {
    
    address public bnbHeroAddress;
    string public name;
    constructor () {
        name = "BNBHPool";
    }
    event UpdatedBNBHeroAddress(address account);
    receive() external payable {}

    function setBNBHeroAddress(address account) external onlyOwner{
        bnbHeroAddress = account;
        emit UpdatedBNBHeroAddress(account);
    }
    function claimBNB(address account, uint256 amount) external override {
        require(_msgSender() == bnbHeroAddress, "You are not allowed to call this function");
        require(amount <= address(this).balance, "Amount is exceeded");
        (bool success, ) = payable(account).call{value: amount}("");
        require(success == true, "Transfer failed.");
    }
}