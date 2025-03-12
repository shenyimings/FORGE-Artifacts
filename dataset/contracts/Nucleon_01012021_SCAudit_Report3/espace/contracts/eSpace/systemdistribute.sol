//SPDX-License-Identifier: BUSL-1.1
// Licensor:            X-Dao.
// Licensed Work:       NUCLEON 1.0

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

///
///  @title System Storage in Conflux eSpace
///
contract systemdistribute is Ownable,Initializable {
  // ======================== System Definition =================================
  using SafeMath for uint;
  address _adminAddress;
  address _balanceAddress;
  uint _allowance;
  uint public constant tranferInterval = 2592000;//86,400 1 days;2,592,000 30 days
  uint public lastTransferTime;
  address[] public _receiveAddrs;
  uint[] public _receiveAmount;
  // ======================== Modifiers =================================
  modifier onlyAdmin() {
    require(msg.sender == _adminAddress, "Only Admin is allowed");
    _;
  }
   // ======================== init =================================
  function initialize(uint _lastTransferTime) public initializer {
    _adminAddress = msg.sender;
    lastTransferTime = _lastTransferTime;
  }
   // ======================== onlyOwner =================================
  function _setAdmin(address _admin) public onlyOwner{
    _adminAddress = _admin;
  }
  function _setbalanceAddress(address _balance) public onlyOwner{
    _balanceAddress = _balance;
  }
  function _setallow(uint _allow) public onlyOwner{
    _allowance = _allow;
  }
  function _setAccounts(uint[] memory _amount, address[] memory _addr) public onlyOwner{
    _receiveAddrs = _addr;
    _receiveAmount = _amount;
  }
  // ======================== private =================================
  function transferERC20(address _ERC20address,address _recipient,uint _amount) private onlyAdmin {
    require(IERC20(_ERC20address).balanceOf(address(this))>=_amount,"exceed the storage ERC20 balance");
    IERC20(_ERC20address).transfer( _recipient, _amount);
  }

  // ======================== public =================================
  function transferERC20byAmount(address _ERC20address) public onlyAdmin {
    require(block.timestamp > lastTransferTime+tranferInterval,"Time is not arrived.");
    require(_allowance==1080,"Requires specific permissions"); 
    require(_receiveAddrs.length==_receiveAmount.length,"The number of addresses and amount need to be the same");
    lastTransferTime = lastTransferTime+tranferInterval;
    uint transferAmountSum;
    uint StorageBalance = IERC20(_ERC20address).balanceOf(address(this));
    for(uint i=0;i<_receiveAddrs.length;i++){
        transferAmountSum += _receiveAmount[i];
    }
    require(transferAmountSum<=StorageBalance,"Needs: transferAmountSum<=StorageBalance"); 
    for(uint i=0;i<_receiveAddrs.length;i++){
        transferERC20( _ERC20address, _receiveAddrs[i], _receiveAmount[i]);
    }

  }

  // ======================== contract base methods =====================
  fallback() external payable {}
  receive() external payable {}
}