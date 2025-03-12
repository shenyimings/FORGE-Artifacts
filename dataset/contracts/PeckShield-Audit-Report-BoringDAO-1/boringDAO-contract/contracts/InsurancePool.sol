// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InsurancePool is Ownable {
    IERC20 public tokenContract;

    function setTokenContract(IERC20 _tokenContract) public onlyOwner {
        tokenContract = _tokenContract;
    }

    function transfer(address to, uint256 amount) public onlyOwner {
        tokenContract.transfer(to, amount);
        emit InsurancePoolTransfer(address(this), to, amount);
    }

    event InsurancePoolTransfer(
        address indexed from,
        address indexed to,
        uint256 amount
    );
}
