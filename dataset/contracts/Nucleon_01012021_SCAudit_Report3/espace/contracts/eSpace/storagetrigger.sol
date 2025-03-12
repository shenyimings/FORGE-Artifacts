//SPDX-License-Identifier: BUSL-1.1
// Licensor:            X-Dao.
// Licensed Work:       NUCLEON 1.01

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// import "systemstorage.sol";
interface iSystemStorage {
    function transferERC20byAmount( uint[] memory _amount      ,
                                    address[] memory _transferaddr,
                                    address          _ERC20address ) external;

}
interface iVeReward {
    function addEpoch(uint startTime, uint endTime, uint totalReward) external onlyAdmin2 returns(uint, uint);
}
///
///  @title System Storage in Conflux eSpace
///
contract storagetrigger is Ownable,Initializable {
// ======================== System Definition =================================
  address _adminAddress;
  address _triggerAddress;
  uint _InitialOffset;
  uint _lengthbySecond;
  uint private constant RATIO_BASE = 10000;

  address _storageAdress;
  address _ERC20Address;
  // ======================== Modifiers =================================
  modifier onlyAdmin() {
    require(msg.sender == _adminAddress, "Only Admin is allowed");
    _;
  }
  modifier onlyTrigger() {
    require(msg.sender == _triggerAddress, "Only trigger is allowed");
    _;
  }
   // ======================== init =================================
  function initialize() public initializer {
    _adminAddress = msg.sender;
  }
   // ======================== onlyOwner =================================
  function _setAdmin(address _admin) public onlyOwner{
    _adminAddress = _admin;
  }
  function _setbalanceAddress(address _balance) public onlyOwner{
    _balanceAddress = _balance;
  }
  function _settrigger(address _allow) public onlyOwner{
    _triggerAddress = _allow;
  }
  function _setUsingAddress(address addrERC20,address addrstorage) public onlyOwner{
    _ERC20Address = addrERC20;
    _storageAdress = addrstorage;
  }
  function _setTimeInterval(uint initialOffset,uint lengthBySecond) public onlyOwner{
    _InitialOffset = initialOffset;
    _lengthbySecond = lengthbySecond;
  }

function justDoIt() public onlyTrigger{
    uint erc20amount = IERC20(_ERC20address).balanceOf(address(_storageAdress))/2;
    uint timesnow =  block.timestamp;
    iSystemStorage(_storageAdress).transferERC20byAmount( [erc20amount], [_storageAdress],_ERC20address ) ;
    addEpoch(uint timesnow + _InitialOffset, _lengthbySecond, erc20amount);
  }
}