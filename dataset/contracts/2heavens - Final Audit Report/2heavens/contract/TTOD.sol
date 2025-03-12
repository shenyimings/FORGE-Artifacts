// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./HeirAccount.sol";


// Factory contract for creating TTOD contracts
contract TTODFactory {

    // Accounts array
    Accounts[] public ttodArray;
    // Heir event
    event HeirSet(uint indexed ttodindex, address heir);
    // Claim event
    event ClaimInitiated(uint indexed ttodindex, address heir);
    // Account claimed event
    event AccountClaimed(uint indexed ttodindex, address newOwner);
    // Account stop claim event
    event AccountStopClaim(uint indexed ttodindex, address Owner);
    //Event to freeze
    event AccountFrozen(uint indexed ttodindex, address frozenAccount);
    //Event to unfreeze
    event AccountUnFrozen(uint indexed ttodindex, address unFrozenAccount);

 
    function createTTOD( address payable _feeAddress, uint _transferFee) public returns(address) {
       Accounts ttod = new Accounts(payable(msg.sender), _feeAddress, _transferFee);    
       ttodArray.push(ttod);
       return address(ttod);
    }

    // Function to set the heir and claimDelay
    function ttodSetHeir(uint256 _ttodindex, address payable _heir, uint _claimDelay) public {
        ttodArray[_ttodindex].setHeir(_heir, _claimDelay, msg.sender);
        emit HeirSet(_ttodindex, _heir);
        }
    // Function for the heir to start the claim process
    function ttodInitiateClaim(uint256 _ttodindex) public {
        ttodArray[_ttodindex].initiateClaim(msg.sender);
        emit ClaimInitiated(_ttodindex, msg.sender);
    }

    // Function for the heir to claim the account
    function ttodClaim(uint256 _ttodindex) public  {
        ttodArray[_ttodindex].claim(msg.sender);
        emit AccountClaimed(_ttodindex, msg.sender);
        }

    // Function to cancel the claim of account
    function ttodStopClaim(uint256 _ttodindex) public {
        ttodArray[_ttodindex].stopClaim(msg.sender);
        emit AccountStopClaim(_ttodindex, msg.sender);
    }

    // Function to freeze the account
    function ttodFreeze(uint256 _ttodindex) public {
        ttodArray[_ttodindex].freeze(msg.sender);
        emit AccountFrozen(_ttodindex, msg.sender);
    }

    // Function to unfreeze the account
    function ttodUnfreeze(uint256 _ttodindex) public {
        ttodArray[_ttodindex].unfreeze(msg.sender);
        emit AccountUnFrozen(_ttodindex, msg.sender);
    }


    // Function to withdraw Celo or ERC20
    function ttodWithdraw(uint256 _ttodindex, bool _isCelo, uint _amount,  address _ERC20Address) public payable {
        ttodArray[_ttodindex].withdraw(_isCelo, _amount, _ERC20Address, msg.sender);
    }

    // Function to transfer Celo or ERC20
    function ttodTransferFunds(uint256 _ttodindex, bool _isCelo, address payable _recipient, uint _amount, address _ERC20Address) public payable {
        ttodArray[_ttodindex].transferFunds(_isCelo, _recipient, _amount, _ERC20Address, msg.sender);
    }

    // View to return the balance
    function ttodBalance(uint256 _ttodindex, bool _isCelo, address _ERC20Address) public view returns(uint) {
        return ttodArray[_ttodindex].balanceOf(_isCelo, _ERC20Address);
    }

    // View to return the owner
    function ttodReturnOwner(uint256 _ttodindex) public view returns(address){
        return ttodArray[_ttodindex].returnOwner();
    }

    // View to return the heir  
     function ttodReturnHeir(uint256 _ttodindex) public view returns(address){
        return ttodArray[_ttodindex].returnHeir();
    }

    // View to return the deployer
    function ttodReturnDeployer(uint256 _ttodindex) public view returns(address){
        return ttodArray[_ttodindex].returnDeployer();
    }


    // Function to return the transfer fee of the account
    function ttodReturnTransferFee(uint _ttodindex) public view returns(uint){
        return ttodArray[_ttodindex].returnTransferFee();
    }   

    // Return the deployer
    function findDeployer(address _deployer) public view returns (uint256[] memory) {
    uint256[] memory resultArray = new uint256[](ttodArray.length);
    uint256 index = 0;
    for (uint256 i = 0; i < ttodArray.length; i++) {
        if (ttodArray[i].returnDeployer() == _deployer) {
            resultArray[index] = i;
            index++;
        }
    }
    return resultArray;
    }

    // Return the owner
    function findOwner(address _owner) public view returns (uint256[] memory) {
    uint256[] memory resultArray = new uint256[](ttodArray.length);
    uint256 index = 0;
    for (uint256 i = 0; i < ttodArray.length; i++) {
        if (ttodArray[i].returnOwner() == _owner) {
            resultArray[index] = i;
            index++;
        }
    }
    return resultArray;
    }

    // Return the heir
    function findHeir(address _heir) public view returns (uint256[] memory) {
    uint256[] memory resultArray = new uint256[](ttodArray.length);
    uint256 index = 0;
    for (uint256 i = 0; i < ttodArray.length; i++) {
        if (ttodArray[i].returnHeir() == _heir) {
            resultArray[index] = i;
            index++;
        }
    }
    return resultArray;
    }
 
}

