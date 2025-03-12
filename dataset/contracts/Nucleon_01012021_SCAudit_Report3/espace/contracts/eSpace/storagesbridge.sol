//SPDX-License-Identifier: BUSL-1.1
// Licensor:            X-Dao.
// Licensed Work:       NUCLEON 1.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
interface IERC20crossIneSpace{
   function lockToken(address _token, address _cfxAccount,uint _amount) external;
}
interface IExchangeroom{
    function XCFX_burn(uint _amount) external returns (uint,uint);
    function getback_CFX(uint _amount) external ;
}
///
///  @title System Storage in Conflux eSpace
///
contract storagesbridge is Ownable,Initializable {
  // ======================== System Definition =================================
  using SafeMath for uint;
  address _balanceAddress;
  uint _allowance;
  address bridgeeSpacesideaddr; //espace address
  address eSpaceExchange;
  address CoreExchange;// use CoreExchange addr 0x version tansfered by conflux scan
  uint private constant RATIO_BASE = 10000;
  address CoreExchangeEspace;// use CoreExchange Espace addr
  address xCFXaddr;// xCFX Espace addr
  // ======================== Modifiers =================================
  modifier onlyCoreExchange() {
    require(msg.sender == CoreExchangeEspace, "Only CoreExchange is allowed");
    _;
  }
   // ======================== init =================================
  function initialize() public initializer {
  }
   // ======================== onlyOwner =================================
  function _setxCFXaddr(address _xCFXaddr) public onlyOwner{
    xCFXaddr = _xCFXaddr;
  }
  function _seteSpaceExchange(address _eSpaceExchange) public onlyOwner{
    eSpaceExchange = _eSpaceExchange;
  }
  function _setCoreExchange(address _CoreExchange) public onlyOwner{
    CoreExchange = _CoreExchange;
  }
  function _setCoreExchangeEspace(address _CoreExchangeeEspace) public onlyOwner{
    CoreExchangeEspace = _CoreExchangeeEspace;
  }
  function _setbridgeeSpacesideaddr(address _bridgeeSpacesideaddr) public onlyOwner{
    bridgeeSpacesideaddr = _bridgeeSpacesideaddr;
  }

  // ======================== CoreExchange used functions =============================
  function handlelock(uint _amount) external onlyCoreExchange returns(uint){
    IERC20(xCFXaddr).approve(bridgeeSpacesideaddr,_amount);
    IERC20crossIneSpace(bridgeeSpacesideaddr).lockToken(xCFXaddr, CoreExchange, _amount) ;
    return _amount;
  }
  function handlexCFXburn(uint _amount) external onlyCoreExchange returns(uint, uint){
    return IExchangeroom(eSpaceExchange).XCFX_burn( _amount);
  }
  function handlegetbackCFX(uint _amount) external onlyCoreExchange returns(uint) {
    IExchangeroom(eSpaceExchange).getback_CFX(_amount);
    transferCFX(CoreExchangeEspace, _amount);
    return _amount;
  }
  
  // ======================== contract base methods =====================
  function transferCFX(address _address, uint _value) internal{
    (bool success, ) = address(uint160(_address)).call{value:_value}("");
    require(success,"CFX Transfer Failed");
  }
  
  fallback() external payable {}
  receive() external payable {}
}