// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract Accounts {
    // The address of the owner of the contract
    address payable public owner;
    // The address of the beneficiary
    address payable public beneficiary;
    // Timestamp of when the delay started
    uint public InitiatedAt;
    // The number of days the beneficiary needs to wait before being able to withdraw all the money
    uint public delay;
    // The fee to pay
    uint fee;
    // Transfer fee for each account
    uint transferFee;
    // Address to receive the fee
    address payable feeAddress;
     // The address of the ERC20 token contract
    address payable public ERC20Token;
    // IERC20
    IERC20 public ERC20;
    //SafeMath for overflow and underflow protection
    using SafeMath for uint;
    // Reentrancy protection 
    bool public mutex = false;
    //balance of ERC20 token
    uint public tokenBalance;
    // Freeze account
    bool public frozen = false;
    // Mapping for the specified ERC20 token to the provided amount
    mapping (address => uint) public withdrawLimit;
    // Deposit event
    event Deposit(address indexed contractAddress, address indexed from, uint amount);



      constructor(address payable _owner, address payable _feeAddress, uint _transferFee) {
        owner = _owner;
        transferFee = _transferFee;
        feeAddress = _feeAddress;
    }

    // Function to set the beneficiary and the time to withdraw all the money
    function setBeneficiary(address payable _beneficiary, uint _delay, address _sender) public {
        require(owner == _sender, "Only the owner can set the beneficiary.");
        require(!mutex, "The function is already in execution.");
        mutex = true;
        beneficiary = _beneficiary;
        delay = _delay;
        mutex = false;
        InitiatedAt = block.timestamp;
    }


    // Function to set the amount that the beneficiary can withdraw
    function setWithdrawLimit(address _sender, uint _amount, address _ERC20Address) public {
    require(_sender == owner, "Only the owner can set the withdrawal limit.");
    withdrawLimit[_ERC20Address] = _amount;
}


    // Function to freeze the account
    function freeze(address _sender) public {
        require(_sender == owner, "Only the owner can freeze the account.");
        frozen = true;
    }

    // Function to unfreeze the account
    function unfreeze(address _sender) public {
        require(_sender == owner, "Only the owner can unfreeze the account.");
        frozen = false;
     }


    // Function to withdraw the funds
    function withdraw(bool _isCelo, uint _amount, address _ERC20Address, address _sender) public payable {
        require(_sender == owner || _sender == beneficiary, "Only the owner or the beneficiary can withdraw funds.");
        if (_sender == beneficiary) {
            require(_amount <= withdrawLimit[_ERC20Address] || (InitiatedAt + delay) < block.timestamp, "The withdrawal amount exceeds the limit or delay has not passed yet.");
        }
        require(!frozen, "Account is frozen, cannot withdraw funds.");

        if (_isCelo) {
            require(address(this).balance > 0, "There are no funds to withdraw.");
            require(_amount <= address(this).balance, "Insufficient funds.");
            require(!mutex, "The function is already in execution.");
            mutex = true;
            fee = _amount.mul(transferFee).div(100);
            owner.transfer(_amount.sub(fee));
            feeAddress.transfer(fee);
            withdrawLimit[_ERC20Address] -= _amount;
            mutex = false;
         } else {

        ERC20 = IERC20(_ERC20Address);
        require(ERC20.balanceOf(address(this)) > 0, "There are no funds to withdraw.");
        require(_amount <= ERC20.balanceOf(address(this)), "Insufficient funds.");
        require(!mutex, "The function is already in execution.");
        mutex = true;
        fee = _amount.mul(transferFee).div(100);
        ERC20.transfer(owner, _amount.sub(fee));
        ERC20.transfer(feeAddress, fee);
        withdrawLimit[_ERC20Address] -= _amount;
        mutex = false;
         }
    }

    // Function to transfer the funds
    function transferFunds(bool _isCelo, address payable _recipient, uint _amount, address _ERC20Address, address _sender) public payable {
        require(_sender == owner || _sender == beneficiary, "Only the owner or the beneficiary can withdraw funds.");
        if (_sender == beneficiary) {
            require(_amount <= withdrawLimit[_ERC20Address] || (InitiatedAt + delay) < block.timestamp , "The withdrawal amount exceeds the limit or delay has not passed yet.");
        }
        require(!frozen, "Account is frozen, cannot withdraw funds.");
       if (_isCelo) {
            require(_amount <= address(this).balance, "Insufficient funds.");
            require(!mutex, "The function is already in execution.");
            mutex = true;
            fee = _amount.mul(transferFee).div(100);
            _recipient.transfer(_amount.sub(fee));
            feeAddress.transfer(fee);
            withdrawLimit[_ERC20Address] -= _amount;
            mutex = false;
        } else {
            ERC20 = IERC20(_ERC20Address);
            require(_amount <= ERC20.balanceOf(address(this)), "Insufficient funds.");
            require(!mutex, "The function is already in execution.");
            mutex = true;
            fee = _amount.mul(transferFee).div(100);
            ERC20.transfer(_recipient, _amount.sub(fee));
            ERC20.transfer(feeAddress, fee);
            withdrawLimit[_ERC20Address] -= _amount;
            mutex = false;
        }
    }

    // Function for the balance of the account
    function balanceOf(bool _isCelo, address _ERC20Address) public view returns(uint) {
    if (_isCelo) {
        return address(this).balance;
    } else {
        return IERC20(_ERC20Address).balanceOf(address(this));
           }
    }

    // Function to return the owner of the account
    function returnOwner() public view returns(address){
        return owner;
    }

     // Function to return the beneficiary of the account   
    function returnBeneficiary() public view returns(address){
        return beneficiary;
    }

    // Function to return the withdraw limit for each token
    function getWithdrawLimit(address _ERC20Address) public view returns (uint) {
        return withdrawLimit[_ERC20Address];
    }

    // Function to return the delay of the account   
    function returnDelay() public view returns(uint){
        return delay;
    }


    // Function to return the timestamp when initiate the delay
    function returnInitiateAt() public view returns(uint){
        return InitiatedAt;
    }   

    // Function to return the transfer fee of the account
    function returnTransferFee() public view returns(uint){
        return transferFee;
    }   

    
    //Fallback function
    fallback () external payable {
        emit Deposit(address(this), msg.sender, msg.value);
    } 

    //Receive function
    receive () external payable {
        emit Deposit(address(this), msg.sender, msg.value);
    }
 
}

