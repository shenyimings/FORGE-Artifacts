pragma solidity ^0.5.16;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/ownership/Ownable.sol";
import "./CErc20.sol";
import "./InterestRateModel.sol";

contract CollateralModel is Ownable{

    bool public isCollateralModel = true;

    struct collateralSetup{
        uint collateral;
        bool isSet;
    }
    
    mapping(address => collateralSetup) public collateralSetups;
    
    constructor(uint _defaultCollateral) public{
        
        _setCollateralInternal(address(0), _defaultCollateral);
        
    }
    
    function _setCollateral(address _ctokenAddress, uint _collateral) public onlyOwner{
        
        _setCollateralInternal(_ctokenAddress, _collateral);
    }
    
    function _deleteCollateral(address _ctokenAddress) public onlyOwner{
        delete collateralSetups[_ctokenAddress];
    }
    
    function _setCollateralInternal(address _ctokenDelegatorAddress, uint _collateral) internal{
            
        if(_ctokenDelegatorAddress != address(0)){
            CDelegatorInterface cDelegator = CDelegatorInterface(_ctokenDelegatorAddress);
            cDelegator.implementation(); //sanity check
            
            CErc20 cErc20 = CErc20(_ctokenDelegatorAddress);
            require(cErc20.isCToken() == true, "implementation address is invalid");
        }
        
        
        require(_collateral <= 0.9e18, "collateral is too big");
        
        collateralSetups[_ctokenDelegatorAddress] = collateralSetup(_collateral, true);
    }
    
    function getCollateral(address _ctokenAddress) public view returns (uint){
        if(collateralSetups[_ctokenAddress].isSet) return collateralSetups[_ctokenAddress].collateral;
        else return collateralSetups[address(0)].collateral;
    }
    
    
}