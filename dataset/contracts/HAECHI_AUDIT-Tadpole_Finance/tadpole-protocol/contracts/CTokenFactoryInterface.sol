pragma solidity ^0.5.16;

import "./Comptroller.sol";
import "./CErc20.sol";
import "./CErc20Delegator.sol";

interface CTokenFactoryInterface {



    event NewCErc20Delegator(address newCErc20DelegatorAddress);
    
    function isFactory() external returns (bool);

    function createCErc20Delegator(address underlying, Comptroller comptroller) external returns (address);
   
   function _setInterestRateModel(InterestRateModel _interestRateModel) external ;
   
   function _setCErc20DelegatorImplementation(address payable _cErc20DelegatorImplementation) external ;
}