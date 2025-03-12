// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract InvestorLogin is Initializable, UUPSUpgradeable, OwnableUpgradeable{

    /*
        It saves bytecode to revert on custom errors instead of using require
        statements. We are just declaring these errors for reverting with upon various
        conditions later in this contract. Thanks, Chiru Labs!
    */
    error inputConnectedWalletAddress();
    error addressAlreadyRegistered();
    
    mapping(address => bool) private isInvestor;
    address[] private pushInvestors;

    function initialize() external initializer{
      ///@dev as there is no constructor, we need to initialise the OwnableUpgradeable explicitly
       __Ownable_init();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function addInvestor(address _ad) external{
        if(msg.sender != _ad){ revert inputConnectedWalletAddress();}
        if(isInvestor[_ad] == true){ revert addressAlreadyRegistered();}
        isInvestor[_ad] = true;
        pushInvestors.push(_ad);
    }

    function verifyInvestor(address _ad) external view returns(bool condition){
        if(isInvestor[_ad]){
            return true;
        }else{
            return false;
        }
    }

    function getAllInvestorAddress() external view returns(address[] memory){
        return pushInvestors;
    }
}