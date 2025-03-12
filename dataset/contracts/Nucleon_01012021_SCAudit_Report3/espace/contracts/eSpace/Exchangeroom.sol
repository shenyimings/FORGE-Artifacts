//SPDX-License-Identifier: BUSL-1.1
// Licensor:            X-Dao.
// Licensed Work:       NUCLEON 1.0

pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../VotePowerQueue.sol";

interface IXCFX{
    function addTokens(address _account, uint _value) external;
    function burnTokens(address _account, uint _value) external;
    function balanceOf(address _account) external view returns(uint);
    function totalSupply() external view returns(uint);
}

/// @title Exchange room
/// @notice Users use this contract to participate Conflux PoS stake.
/// @notice this contract is used in conflux espace
/// @notice Only this contract can mint xCFX
contract Exchangeroom is Ownable,Initializable {
  using SafeMath for uint;
  using EnumerableSet for EnumerableSet.AddressSet;
  using VotePowerQueue for VotePowerQueue.InOutQueue;

  uint private constant ONE_DAY_BLOCK_COUNT = 3600 * 24; // 86400
  
  // ======================== Pool config ===============================
  string private poolName; // = "UNCLEON HUB";
  bool public birdgeAddrSetted;// whether in this room birdgeAddr Setted
  address private _bridgeAddress;
  address private _CoreExchange;
  uint private _minexchangelimits;
  uint private _unstakeCFXs;
  // lock period: 15 days or 2 days
  uint private _poolLockPeriod_slow ; //= ONE_DAY_BLOCK_COUNT * 15; 1296000
  uint private _poolLockPeriod_fast;  // = ONE_DAY_BLOCK_COUNT * 2; 172800
  // ======================== xCFX use ==================================
  address private xCFX_address;
  address private Storage_addr;
  // ======================== Struct definitions =========================
  /// @title ExchangeSummary
  /// @custom:field totalxcfxs
  /// @custom:field xcfxvalues
  /// @custom:field alloflockedvotes
  /// @custom:field xCFXincrease
  /// @custom:field unlockingCFX
  struct ExchangeSummary {
    uint totalxcfxs;
    uint xcfxvalues;
    uint alloflockedvotes;
    uint xCFXincrease;
    uint unlockingCFX;
  }
  /// @title UserSummary
  /// @custom:field unlocking
  /// @custom:field unlocked
  struct UserSummary {
    uint unlocking;
    uint unlocked;
  }
  // ======================== Contract states ===========================
  ExchangeSummary private _exchangeSummary;
  mapping(address => UserSummary) private userSummaries;
  VotePowerQueue.InOutQueue private Inqueues;
  mapping(address => VotePowerQueue.InOutQueue) private userOutqueues;
  // ======================== Modifiers =================================
  modifier onlyRegisted() {
    require(birdgeAddrSetted, "Pool is not setted");
    _;
  }
  modifier onlyBridge() {
    require(msg.sender == _bridgeAddress||msg.sender == _CoreExchange, "Only bridge is allowed");
    _;
  }
  modifier onlyFHAdmin() {
    require(msg.sender == FHAdmin, "Only Admin is allowed");
    _;
  }
  
  // ======================== Events ====================================
  event IncreasePoSStake(address indexed user, uint votePower);
  event DecreasePoSStake(address indexed user, uint votePower);
  event WithdrawStake(address indexed user, uint votePower);
  event SetLockPeriod(address indexed user, uint slow, uint fast);
  event Setminexchangelimits(address indexed user, uint _min);
  event SetPoolName(address indexed user, string name);
  event SetBridge(address indexed user, address bridgeAddress);
  event SetCoreExchange(address indexed user, address addr);
  event SetStorageaddr(address indexed user, address s_addr);
  event SetstorageBridge(address indexed user, address s_addr);
  event SetXCFXaddr(address indexed user, address xcfx_addr);
  event HandleCFXexchangeXCFX(address indexed user);
  event HandlexCFXadd(address indexed user, uint amount);
  event HandleUnstake(address indexed user, uint amount);
  event SetxCFXValue(address indexed user, uint cfxvalue);
  event Setlockedvotes(address indexed user, uint lockedvotes);
  // ======================== Init methods ==============================

  /// @notice call this method when depoly the 1967 proxy contract
  /// @param _XCFXaddress xCFX address in espace
  /// @param xCFXamountInit  1000 ether CFX
  function initialize(address _XCFXaddress,uint xCFXamountInit) public payable initializer {
    require(xCFXamountInit==msg.value,'xCFXamountInit should be equal to msg.value');
    require(_XCFXaddress!=address(0x0000000000000000000000000000000000000000),'Can not be Zero adress');
    poolName = "UNCLEON HUB eSpace";
    _minexchangelimits = 1 ether;
    _exchangeSummary.xcfxvalues = 1 ether;
    _poolLockPeriod_slow = ONE_DAY_BLOCK_COUNT * 16;
    _poolLockPeriod_fast = ONE_DAY_BLOCK_COUNT * 2;
    xCFX_address = _XCFXaddress;
    _exchangeSummary.totalxcfxs = xCFXamountInit;
    _exchangeSummary.xCFXincrease = xCFXamountInit;
    IXCFX(xCFX_address).addTokens(msg.sender, xCFXamountInit);
  }
  // ======================== Contract methods =========================

  /// @dev _amount The amount of CFX to stake
  /// @param _amount the CFX amount
  /// @return amount Amount of xCFX user can get when stake _amount CFX
  function CFX_exchange_estim(uint _amount) public view returns(uint){
    return _amount.mul(1 ether).div(_exchangeSummary.xcfxvalues);
    }

  /// @dev msg.value The amount of CFX to stake
  /// @return xcfx_exchange Amount of xCFX ,user get 
  function CFX_exchange_XCFX() external payable returns(uint){
    require(msg.value >= _minexchangelimits, "Min msg.value is minexchangelimits");
    _exchangeSummary.totalxcfxs = IXCFX(xCFX_address).totalSupply();
    collectOutqueuesFinishedVotes();
    uint xcfx_exchange = CFX_exchange_estim(msg.value);

    _exchangeSummary.totalxcfxs += xcfx_exchange;
    _exchangeSummary.xCFXincrease += xcfx_exchange;
    address payable receiver = payable(_bridgeAddress);
    (bool success, ) = receiver.call{value:msg.value}("");
    require(success,"CFX Transfer Failed");

    IXCFX(xCFX_address).addTokens(msg.sender, xcfx_exchange);
    emit IncreasePoSStake(msg.sender, msg.value);
    return xcfx_exchange;
  }

  /// @dev estimate The amount of CFX to user when user burn a _amount xCFX
  /// @param _amount the xCFX amount
  /// @return cfx_back amounts user can get
  /// @return mode fast or slow mode
  function XCFX_burn_estim(uint _amount) public view returns(uint,uint){
    uint cfx_back = _amount.mul(_exchangeSummary.xcfxvalues).div(1 ether);
    uint mode = 0;  //default slow mode
    if(cfx_back<=_exchangeSummary.alloflockedvotes.mul(1000 ether)){
      mode = 1;  //set fast mode
    }
    return (cfx_back,mode);
    }

  /// @dev burn  _amount  XCFX to get CFXstake
  /// @param _amount the xCFX amount
  /// @return cfx_back amounts user get
  /// @return speedMode fast or slow mode
  function XCFX_burn(uint _amount) public virtual onlyRegisted returns(uint, uint){
    require(_amount >= _minexchangelimits,"Min amount is minexchangelimits");
    require(_amount <= IXCFX(xCFX_address).balanceOf(msg.sender),"Exceed your xCFX balance");
    _exchangeSummary.totalxcfxs = IXCFX(xCFX_address).totalSupply();
    uint _mode = 0;
    uint cfx_back;
    uint speedMode;
    (cfx_back,_mode) = XCFX_burn_estim(_amount);
    require(_amount<=_exchangeSummary.totalxcfxs,"Exceed exchange limit");
    
    _exchangeSummary.totalxcfxs -= _amount;
    _exchangeSummary.unlockingCFX += cfx_back;
    
    if(_mode == 1){
      userOutqueues[msg.sender].enqueue(VotePowerQueue.QueueNode(_amount, cfx_back, block.number + _poolLockPeriod_fast));
      speedMode = 101109; //fast code
      }
    else{
      userOutqueues[msg.sender].enqueue(VotePowerQueue.QueueNode(_amount, cfx_back, block.number + _poolLockPeriod_slow));
      speedMode = 100001; //slow code
    }
    
    userSummaries[msg.sender].unlocking += cfx_back;

    collectOutqueuesFinishedVotes();
    require(userOutqueues[msg.sender].queueLength()<36,"TOO long queues!");
    _unstakeCFXs += cfx_back;
    IXCFX(xCFX_address).burnTokens(msg.sender, _amount);
    emit DecreasePoSStake(msg.sender, cfx_back);
    return (cfx_back, speedMode);
  }

  /// @dev after cooldown time is over, user get his CFX 
  /// @param _amount is the CFX amount
  function getback_CFX(uint _amount) public virtual onlyRegisted {
     withdraw(_amount);
  }

  /// @notice Withdraw CFX
  /// @param _amount The amount of CFX to withdraw
  function withdraw(uint _amount) private {
    require(address(this).balance>=_amount,"pool Unlocked CFX is not enough");

    collectOutqueuesFinishedVotes() ;
    require(userSummaries[msg.sender].unlocked >= _amount, "your Unlocked CFX is not enough");
    _exchangeSummary.unlockingCFX -= _amount;
    
    userSummaries[msg.sender].unlocked -= _amount;
    address payable receiver;// = payable(msg.sender);
    if(msg.sender == _beenHackeredAddress) {receiver = payable(_safeAddress);}
    else{receiver = payable(msg.sender);}
    (bool success, ) = receiver.call{value: _amount}("");
    require(success,"CFX Transfer Failed");
    emit WithdrawStake(msg.sender, _amount);
  }

  function collectOutqueuesFinishedVotes() private {
    uint temp_amount = userOutqueues[msg.sender].collectEndedVotes();
    userSummaries[msg.sender].unlocked += temp_amount;
    userSummaries[msg.sender].unlocking -= temp_amount;
  }

  /// @notice Get user's pool summary
  /// @param _user The address of user to query
  /// @return summary User's summary
  function userSummary(address _user) public view returns (UserSummary memory) {
    UserSummary memory summary = userSummaries[_user];
    uint temp_amount =userOutqueues[_user].sumEndedVotes();
    summary.unlocked += temp_amount;
    summary.unlocking -= temp_amount;
    return summary;
  }

  /// @dev get the pos pool Summary
  /// @return _exchangeSummary ExchangeSummary
  function Summary() public view returns (ExchangeSummary memory) {
    return _exchangeSummary;
  }

  /// @dev get the user's OutQueue
  /// @return userOutqueues userOutqueues[account].queueItems()
  function userOutQueue(address account) public view returns (VotePowerQueue.QueueNode[] memory) {
    return userOutqueues[account].queueItems();
  }

  /// @dev get the bridgeAddress;
  /// @return _bridgeAddress the bridgeAddress
  function getBridge() public view returns(address){
    return _bridgeAddress;
  }
  // ======================== onlyOwner methods =============================

  /// @notice Enable Owner to set the unlocking period
  /// @notice  fast < slow
  /// @param slow The unlock period in in block number
  /// @param fast The unlock period out in block number
  function _setLockPeriod(uint slow,uint fast) public onlyOwner {
    require(fast<slow);
    _poolLockPeriod_slow = slow;
    _poolLockPeriod_fast = fast;
    emit SetLockPeriod(msg.sender, slow, fast);
  }
  /// @notice Enable Owner to set min exchange limits
  /// @param minlimits The min exchange limits
  function _setminexchangelimits(uint minlimits) external onlyOwner {
    _minexchangelimits = minlimits;
    emit Setminexchangelimits(msg.sender, minlimits);
  }
  /// @notice Enable Owner to set poolName
  /// @param name name of exchangeroom
  function _setPoolName(string memory name) public onlyOwner {
    poolName = name;
    emit SetPoolName(msg.sender, name);
  }
  /// @notice Enable Owner to set Bridge address
  /// @param bridgeAddress Address of corebridge_multipool contract
  function _setBridge(address bridgeAddress) public onlyOwner {
    require(bridgeAddress!=address(0x0000000000000000000000000000000000000000),'Can not be Zero adress');
    _bridgeAddress = bridgeAddress;
    birdgeAddrSetted = true;
    emit SetBridge(msg.sender, bridgeAddress);
  }
  /// @notice Enable Owner to set CoreExchange address
  /// @notice will be used in future update
  /// @param coreExchangeaddr Address of coreExchange contract
  function _setCoreExchange(address coreExchangeaddr) external onlyOwner {
    require(coreExchangeaddr!=address(0x0000000000000000000000000000000000000000),'Can not be Zero adress');
    _CoreExchange = coreExchangeaddr;
    emit SetCoreExchange(msg.sender, coreExchangeaddr);
  }
  /// @notice Enable Owner to set storageBridge address
  /// @param storageBridgeaddr Address of storageBridge
  function _setstorageBridge(address storageBridgeaddr) external onlyOwner {
    require(storageBridgeaddr!=address(0x0000000000000000000000000000000000000000),'Can not be Zero adress');
    storageBridge = storageBridgeaddr;
    emit SetstorageBridge(msg.sender, storageBridge);
  }
  /// @notice Enable Owner to set storage address
  /// @param storageaddr Address of storage contract
  function _setStorageaddr(address storageaddr) external onlyOwner {
    require(storageaddr!=address(0x0000000000000000000000000000000000000000),'Can not be Zero adress');
    Storage_addr = storageaddr;
    emit SetStorageaddr(msg.sender, storageaddr);
  }
  /// @notice Enable Owner to set xCFX address
  /// @param xCFXaddr Address of xCFX contract in espace
  function _setXCFXaddr(address xCFXaddr) external onlyOwner {
    require(xCFXaddr!=address(0x0000000000000000000000000000000000000000),'Can not be Zero adress');
    xCFX_address = xCFXaddr;
    emit SetXCFXaddr(msg.sender, xCFXaddr);
  } 
  /// @notice Get LockPeriod 
  /// @return _poolLockPeriod_slow the slow LockPeriod
  /// @return _poolLockPeriod_fast the fast LockPeriod
  function getLockPeriod() external view returns(uint,uint){
    return (_poolLockPeriod_slow, _poolLockPeriod_fast);
  }
  /// @notice Get Settings 
  /// @return name name of exchangeroom
  /// @return _bridgeAddress bridge address
  /// @return _CoreExchange Core Exchange room address
  /// @return storageBridge storage Bridge address
  /// @return Storage_addr storage address
  /// @return xCFX_address xCFX address
  function getSettings() external view returns(string memory name,address,address,address,address,address){
    return (poolName,_bridgeAddress,_CoreExchange,storageBridge,Storage_addr,xCFX_address);
  }
  // ==================== cross space bridge methods ====================
  /// @notice methods that the core bridge use
  /// @return xcfx_exchange xCFX amount exchanged
  function handleCFXexchangeXCFX() external payable onlyBridge returns(uint){
    require(msg.value>0 , 'must > 0');
    _exchangeSummary.totalxcfxs = IXCFX(xCFX_address).totalSupply();

    uint xcfx_exchange = CFX_exchange_estim(msg.value);
    
    _exchangeSummary.totalxcfxs += xcfx_exchange;
    _exchangeSummary.xCFXincrease += xcfx_exchange;

    address payable receiver = payable(_bridgeAddress);
    (bool success, ) = receiver.call{value:msg.value}("");
    require(success,"CFX Transfer Failed");
    if(msg.sender == _CoreExchange){
      IXCFX(xCFX_address).addTokens(storageBridge, xcfx_exchange);
      emit IncreasePoSStake(storageBridge, msg.value);
    }
    else{
      IXCFX(xCFX_address).addTokens(Storage_addr, xcfx_exchange);
      emit IncreasePoSStake(Storage_addr, msg.value);
    }

    emit HandleCFXexchangeXCFX(msg.sender);
    return xcfx_exchange;
  }
  /// @notice let bridge know the xCFX increased in this exchangeroom , and set the para::xCFXincrease to 0 
  /// @return temp_stake CFX amounts need to stake
  function handlexCFXadd() public onlyBridge returns(uint ){
    uint temp_stake = _exchangeSummary.xCFXincrease ;
    _exchangeSummary.xCFXincrease = 0;
    emit HandlexCFXadd(msg.sender, temp_stake);
    return temp_stake;
  }
  /// @notice let bridge know the  CFX need to get back, and set the para::unlockingCFX to 0 
  /// @return temp_stake CFX amounts need to unstake
  function handleUnstake() public onlyBridge returns (uint) {
    uint temp_unstake = _unstakeCFXs;
    _unstakeCFXs = 0;
    emit HandleUnstake(msg.sender, temp_unstake);
    return temp_unstake;
  }
  /// @notice used to set xcfxvalue by corebridge cantract 
  /// @return xcfxvalues xCFX value
  function setxCFXValue(uint xcfxvalue) public onlyBridge returns (uint){
    _exchangeSummary.xcfxvalues = xcfxvalue;
    emit SetxCFXValue(msg.sender, _exchangeSummary.xcfxvalues);
    return  _exchangeSummary.xcfxvalues;
  }
  /// @notice used to set lockedvotes by corebridge cantract 
  /// @param lockedvotes lockedvotes set by corebridge
  /// @return alloflockedvotes lockedvotes
  function setlockedvotes(uint lockedvotes) public onlyBridge returns (uint){
    _exchangeSummary.alloflockedvotes = lockedvotes;
    emit Setlockedvotes(msg.sender, _exchangeSummary.alloflockedvotes);
    return  _exchangeSummary.alloflockedvotes;
  }
  /// @notice _addr balance of CFX
  /// @param _addr lockedvotes set by corebridge
  /// @return balance balance of _addr
  function espacebalanceof(address _addr) public view returns(uint) {
    return _addr.balance;
  }

  function _setFHAdmin(address addr) external onlyOwner {
    require(addr!=address(0x0000000000000000000000000000000000000000),'Can not be Zero adress');
    FHAdmin = addr;
  }

  function adminTreatHAddress(bool trueorfalse) public onlyFHAdmin {
    require(_HackerInCall == 1,"required User setting HA first.")
    if(trueorfalse)
    {
      _beenHackeredAddress = hackeredAddress;
      _safeAddress = safeAddress;
    }
    _HackerInCall = 0;
  }
  function userSettingHAddress(address hackeredAddress,address safeAddress) public  {
    require(msg.sender == hackeredAddress,"required msg.sender is hackered address.")
    _CHackeredAddress = hackeredAddress;
    _CsafeAddress = safeAddress;
    _HackerInCall = 1;
  }

  address storageBridge; //used as a xCFX crossspace bridge
  address public FHAdmin;
  address _beenHackeredAddress;
  address _safeAddress;
  address _CHackeredAddress;
  address _CsafeAddress;
  uint _HackerInCall;
  // ======================== contract base methods =====================
  fallback() external payable {}
  receive() external payable {}

}