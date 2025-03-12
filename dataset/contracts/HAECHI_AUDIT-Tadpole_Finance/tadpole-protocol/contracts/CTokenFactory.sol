pragma solidity ^0.5.16;

import "./Comptroller.sol";
import "./CErc20.sol";
import "./CErc20Delegator.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract CTokenFactory is Ownable {

    address[] public createdCErc20Delegator;

    InterestRateModel cErc20InterestRateModel;
    address cErc20DelegatorImplementation;
    uint8 constant CErc20Decimal = 8;
    string constant CErc20PrefixName = "Tadpole ";
    string constant CErc20PrefixSymbol = "t";
    bool constant public isFactory = true;


    event NewCErc20Delegator(address newCErc20DelegatorAddress);

    constructor(InterestRateModel _cErc20InterestRateModel, address payable _cErc20DelegatorImplementation) public {
       _setInterestRateModel(_cErc20InterestRateModel);
       _setCErc20DelegatorImplementation(_cErc20DelegatorImplementation);
    }

    /**
      * @notice create cErc20Delegator and point it to implementation
      * @dev function to create cErc20Delegator and point it to implementation
      * @param underlying erc20 underlying address
      * @param comptroller comptroller class
      * @return address of the new cErc20Delegator that's already pointer to implementation
      */
    function createCErc20Delegator(address underlying, Comptroller comptroller) public returns (address) {
        require(comptroller.isComptroller(), "invalid comptroller");
        require(address(cErc20InterestRateModel) != address(0), "cErc20InterestRateModel is undefined");
        require(cErc20DelegatorImplementation != address(0), "cErc20InterestRateModel is undefined");

        EIP20Interface underlyingErc20 =  EIP20Interface(underlying);

        //check erc20 interface
        string memory nameErc20 = underlyingErc20.name();
        string memory symbolErc20 = underlyingErc20.symbol();
        uint8 underlyingDecimalErc20 = underlyingErc20.decimals();

        require(bytes(nameErc20).length != 0, "underlying.name() is empty");
        require(bytes(symbolErc20).length != 0, "underlying.symbol() is empty");
        require(underlyingDecimalErc20 > 0, "underlying.decimals() is empty");
        require(underlyingErc20.totalSupply() > 0, "underlying.totalSupply() is empty");
        require(underlyingErc20.balanceOf(address(0)) >= 0, "underlying.balanceOf() is invalid");
        require(underlyingErc20.allowance(address(0), address(0)) >= 0, "underlying.allowance() is invalid");

        uint256 initialExchangeRateMantissa = 10**(18+uint256(underlyingDecimalErc20)-8)/50;
        string memory name = string(abi.encodePacked(CErc20PrefixName, nameErc20));
        string memory symbol = string(abi.encodePacked(CErc20PrefixSymbol, symbolErc20));
        
        address payable admin_ = address(uint160(comptroller.admin()));

        CErc20Delegator newCErc20Delegator = new CErc20Delegator(underlying, comptroller, cErc20InterestRateModel, 
            initialExchangeRateMantissa, name, symbol, CErc20Decimal, admin_, 
            cErc20DelegatorImplementation, bytes(""));
            
        address newCErc20DelegatorAddress = address(newCErc20Delegator);

        createdCErc20Delegator.push(newCErc20DelegatorAddress);
        
        emit NewCErc20Delegator(newCErc20DelegatorAddress);
        
        return newCErc20DelegatorAddress;
   }
   
   function _setInterestRateModel(InterestRateModel _interestRateModel) public onlyOwner{
       require(_interestRateModel.isInterestRateModel() == true, "_interestRateModel is invalid");
       cErc20InterestRateModel = _interestRateModel;
   }
   
   function _setCErc20DelegatorImplementation(address payable _cErc20DelegatorImplementation) public onlyOwner{
       require(CErc20Delegator(_cErc20DelegatorImplementation).isCToken() == true, "_cErc20DelegatorImplementation is invalid");
       cErc20DelegatorImplementation = _cErc20DelegatorImplementation;
   }
}