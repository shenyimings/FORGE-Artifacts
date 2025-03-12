pragma solidity ^0.4.24;

import "./SideToken.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./HashUtils.sol";
import "./TokenVesting.sol";

contract SideBridge is Ownable {
  using SafeMath for uint256;
  using HashUtils for uint256;

  uint8 constant MAX_AUTHORITIES_NUMBER = 255;

  uint256 public mainChainId;
  address public mainBridge;
  uint256 public sideChainId;

  address public operator;

  // Number of authorities signatures required to withdraw the money
  // Must be less than number of authorities
  uint256 public requiredSignatures;

  // Contract authorities
  mapping (address => bool) public authorities;
  mapping(bytes32 => uint8) public changeAuthorityCount;
  mapping(bytes32 => mapping (address => bool)) public changeAuthoritySignedHistory;

  mapping (bytes32 => SideTokenInfo) sideTokens;

  mapping (bytes32 => DepositInfo) deposits;
  mapping (bytes32 => mapping (address => StakeInfo)) stakes;
  mapping (address => TokenVesting[]) vests;

  uint256 redeemNonce;
  mapping (bytes32 => RedeemInfo) redeems;

  bool isPaused = false;

  mapping (bytes32 => ConfirmInfo) pauseRequests;
  mapping (bytes32 => ConfirmInfo) resumeRequests;

  event SideTokenMinted(bytes32 sideTokenId, bytes32 depositId, address beneficiary, uint256 amountST, string tokenSymbol);
  event SideTokenRegistered(bytes32 sideTokenId, address sideToken);
  event SideTokenAcknowledged(bytes32 sideTokenId);
  event SideTokenStaked(bytes32 sideTokenId, address staker, uint256 amount);
  event SideTokenUnstaked(bytes32 sideTokenId, address recipient, uint256 amount);
  event SideTokenVested(address tokenVest, bytes32 sideTokenId, address recipient, uint256 amount, uint256 start, uint256 cliff, uint256 duration, uint256 interval);
  event SideTokenRedeemed(bytes32 redeemId, bytes32 sideTokenId, address owner, uint256 amount);
  event SideTokenRedeemConfirmed(bytes32 redeemId, bytes32 sideTokenId, address owner, uint256 amount);

  event ActionApproved(string action, address from, address to, uint256 amount);

  event AuthorityChanged(address oldAuthority, address newAuthority, bytes32 changeId, uint8 changeAuthorityCount);

  event SideBridgePaused(bytes32 mainBridgeTxHash);
  event SideBridgeResumed(bytes32 mainBridgeTxHash);

  enum SideTokenStatus {
    NotRegistered,
    SideChainRegistered,
    MainChainRegistered
  }

  struct SideTokenInfo {
    SideToken sideToken;
    address sideTokenAddress;
    uint256 conversionRate;
    uint8 conversionRateDecimals;
    SideTokenStatus status;
  }

  struct DepositInfo {
    bytes32 sideTokenId;
    address beneficiary;
    uint256 amountST;
    uint8 signedCount;
    mapping (address => bool) signed;
    bool deposited;
  }

  struct StakeInfo {
    uint256 amount;
  }

  struct RedeemInfo {
    bytes32 sideTokenId;
    address owner;
    uint256 amount;
    uint8 confirmedCount;
    bool confirmed;
  }

  struct ConfirmInfo {
    uint8 confirmedCount;
    bool confirmed;

    mapping(address => bool) authoritySigned;
  }

  modifier onlyAuthority() {
    require(authorities[msg.sender]);
    _;
  }

  modifier onlyOperator() {
    require(msg.sender == operator);
    _;
  }

  modifier onlyWhenAlive() {
    require(!isPaused);
    _;
  }

  constructor(uint256 _mainChainId, address _mainBridge, uint256 _sideChainId, uint256 _requiredSignatures, address[] _authorities) public {
    require(_mainChainId > 0 );
    require(_sideChainId > 0 );
    require(_mainChainId != _sideChainId );
    require(_mainBridge != address(0));
    require(_authorities.length <= MAX_AUTHORITIES_NUMBER);

    require(_requiredSignatures <= _authorities.length);
    require(_requiredSignatures > (_authorities.length / 2) );

    mainBridge = _mainBridge;
    mainChainId = _mainChainId;
    sideChainId = _sideChainId;

//    owner = msg.sender;
    operator = msg.sender;

    requiredSignatures = _requiredSignatures;

    for (uint8 i = 0; i < _authorities.length; i++) {
      authorities[_authorities[i]] = true;
    }
  }

  function pauseBridge(bytes32 _pauseTxHash) external onlyAuthority() {
    ConfirmInfo storage pauseConfirmInfo = pauseRequests[_pauseTxHash];

    if (pauseConfirmInfo.confirmedCount == 0) {
      pauseConfirmInfo.confirmedCount = 0;
      pauseConfirmInfo.confirmed = false;
    }

    if (pauseConfirmInfo.authoritySigned[msg.sender] == false) {
      pauseConfirmInfo.authoritySigned[msg.sender] = true;
      pauseConfirmInfo.confirmedCount++;
    }

    if (pauseConfirmInfo.confirmed) {
      return;
    }

    if (pauseConfirmInfo.confirmedCount >= requiredSignatures) {
      isPaused = true;

      pauseConfirmInfo.confirmed = true;
      emit SideBridgePaused(_pauseTxHash);
    }
  }

  function resumeBridge(bytes32 _resumeTxHash) external onlyAuthority() {
    ConfirmInfo storage resumeConfirmInfo = resumeRequests[_resumeTxHash];

    if (resumeConfirmInfo.confirmedCount == 0) {
      resumeConfirmInfo.confirmedCount = 0;
      resumeConfirmInfo.confirmed = false;
    }

    if (resumeConfirmInfo.authoritySigned[msg.sender] == false) {
      resumeConfirmInfo.authoritySigned[msg.sender] = true;
      resumeConfirmInfo.confirmedCount++;
    }

    if (resumeConfirmInfo.confirmed) {
      return;
    }

    if (resumeConfirmInfo.confirmedCount >= requiredSignatures) {
      isPaused = false;

      resumeConfirmInfo.confirmed = true;
      emit SideBridgeResumed(_resumeTxHash);
    }
  }

  function registerSideToken(bytes32 _sideTokenId, address _sideToken, uint256 _conversionRate, uint8 _conversionRateDecimals) onlyOperator() external {
    require(_sideToken != address(0));
    SideToken sideToken = SideToken(_sideToken);

    bytes32 sideTokenId = hashSideTokenId(sideChainId, sideToken.name(), sideToken.symbol(), _conversionRate, _conversionRateDecimals);

    require(sideTokenId == _sideTokenId);

    sideTokens[_sideTokenId] = SideTokenInfo(sideToken, _sideToken, _conversionRate, _conversionRateDecimals, SideTokenStatus.SideChainRegistered);

    sideToken.setSideTokenId(sideTokenId);

    emit SideTokenRegistered(_sideTokenId, _sideToken);
  }

  function acknowledgeSideToken(bytes32 _sideTokenId) onlyOperator() external {
    require(sideTokens[_sideTokenId].status == SideTokenStatus.SideChainRegistered);

    sideTokens[_sideTokenId].status = SideTokenStatus.MainChainRegistered;

    emit SideTokenAcknowledged(_sideTokenId);
  }

  function deposit(bytes32 _sideTokenId, bytes32 _depositId, uint256 _depositCount, address _beneficiary, uint256 _amountMT, uint256 _amountST, bytes32 _transactionHash) onlyAuthority() public {
    require(_beneficiary != address(0));

    SideToken sideToken = sideTokens[_sideTokenId].sideToken;

    require(sideToken != address(0), "sideToken is 0");
    require(sideTokens[_sideTokenId].status == SideTokenStatus.MainChainRegistered, "sideToken is not registered");

    require(_amountST > 0);

    bytes32 depositId = keccak256(abi.encodePacked(_depositCount, _sideTokenId, _beneficiary, _amountMT, _amountST));

    require(depositId == _depositId, "depositId mismatched");

    DepositInfo storage _deposit = deposits[depositId];

    if ( deposits[depositId].signedCount == 0 ) {
      // for First signer, create deposit structure
      _deposit.sideTokenId = _sideTokenId;
      _deposit.beneficiary = _beneficiary;
      _deposit.amountST = _amountST;
      _deposit.signedCount = 1;
      _deposit.signed[msg.sender] = true;
      _deposit.deposited = false;
    }
    else {
      // From the second signers, update signedCount
      require(_deposit.deposited == false);
      require(_deposit.signed[msg.sender] == false);

      _deposit.signedCount++;
      _deposit.signed[msg.sender] = true;

      if ( _deposit.signedCount >= requiredSignatures ) {
        // the number of signer is greater than equal to requiredSigners, mint the deposit
        _deposit.deposited = true;
        sideToken.mint(_beneficiary, _amountST);

        emit SideTokenMinted(_sideTokenId, _depositId, _beneficiary, _amountST, sideToken.symbol());
      }
    }
  }

  function stake(bytes32 _sideTokenId, address _staker, uint256 _amount) onlyWhenAlive external {
    SideTokenInfo storage sideTokenInfo = sideTokens[_sideTokenId];

    require(sideTokenInfo.sideTokenAddress == msg.sender );

    SideToken sideToken = sideTokenInfo.sideToken;

    sideToken.transferFrom(_staker, address(this), _amount);

    StakeInfo storage _stake = stakes[_sideTokenId][_staker];

    _stake.amount = _stake.amount.add(_amount);

    emit SideTokenStaked(_sideTokenId, _staker, _amount);
  }

  function unstake(bytes32 _sideTokenId, address _recipient, uint256 _amount) onlyWhenAlive external {
    SideTokenInfo storage sideTokenInfo = sideTokens[_sideTokenId];

    require(sideTokenInfo.sideTokenAddress == msg.sender );

    StakeInfo storage staked = stakes[_sideTokenId][_recipient];

    require(staked.amount >= _amount);

    SideToken sideToken = sideTokenInfo.sideToken;

    sideToken.transfer(_recipient, _amount);
    staked.amount = staked.amount.sub(_amount);

    emit SideTokenUnstaked(_sideTokenId, _recipient, _amount);
  }

  function vest(bytes32 _sideTokenId, address _vester, uint256 _amount, uint256 _cliff, uint256
    _duration, uint256 _interval) onlyWhenAlive external {
    SideTokenInfo storage sideTokenInfo = sideTokens[_sideTokenId];

    require(sideTokenInfo.sideTokenAddress == msg.sender );

    SideToken sideToken = sideTokenInfo.sideToken;

    TokenVesting tokenVest = new TokenVesting(sideToken, _vester, _amount, block.timestamp, _cliff, _duration, _interval);

    vests[_vester].push(tokenVest);

    sideToken.transferFrom(_vester, tokenVest, _amount);

    emit SideTokenVested(address(tokenVest), _sideTokenId, _vester, _amount, block.timestamp, _cliff, _duration, _interval);
  }

  function redeem(bytes32 _sideTokenId, address _owner, uint256 _amount) onlyWhenAlive external {
    SideTokenInfo storage sideTokenInfo = sideTokens[_sideTokenId];

    require(sideTokenInfo.sideTokenAddress == msg.sender );

    uint256 conversionRate = sideTokenInfo.conversionRate;
    uint8 conversionRateDecimals = sideTokenInfo.conversionRateDecimals;

    uint256 redeemAmountInMT = _amount.div(conversionRate).mul(10 ** uint256(conversionRateDecimals));
    uint256 redeemAmountInPt = redeemAmountInMT.mul(conversionRate).div(10 ** uint256(conversionRateDecimals));

    require(redeemAmountInPt == _amount);

    bytes32 redeemId = keccak256(abi.encodePacked(redeemNonce,_sideTokenId,_owner,_amount));
    redeemNonce++;

    SideToken sideToken = SideToken(sideTokenInfo.sideTokenAddress);
    sideToken.transferFrom(_owner, address(this), _amount);

    redeems[redeemId] = RedeemInfo(_sideTokenId, _owner, _amount, 0, false);

    emit SideTokenRedeemed(redeemId, _sideTokenId, _owner, _amount);
  }

  function confirmRedeem(bytes32 redeemId) external onlyAuthority() {
    RedeemInfo storage redeemInfo = redeems[redeemId];

    require(redeemInfo.amount > 0);

    if (redeemInfo.confirmed == false) {
      redeemInfo.confirmedCount++;

      if (redeemInfo.confirmedCount >= requiredSignatures) {
        redeemInfo.confirmed = true;

        bytes32 sideTokenId = redeemInfo.sideTokenId;
        address owner = redeemInfo.owner;
        uint256 amount = redeemInfo.amount;

        SideTokenInfo storage sideTokenInfo = sideTokens[sideTokenId];

        SideToken sideToken = SideToken(sideTokenInfo.sideTokenAddress);

        sideToken.transfer(sideTokenInfo.sideTokenAddress, amount);
        sideToken.burn(amount);

        delete redeems[redeemId];

        emit SideTokenRedeemConfirmed(redeemId, sideTokenId, owner, amount);
      }
    }
  }

  function changeAuthority(bytes32 _changeId, address _oldAuthority, address _newAuthority) external onlyAuthority() {
    require(_oldAuthority != address(0));
    require(_newAuthority != address(0));
    require(!changeAuthoritySignedHistory[_changeId][msg.sender]); // allow once for one authority


    changeAuthoritySignedHistory[_changeId][msg.sender] = true;
    changeAuthorityCount[_changeId]++;

    if (authorities[_newAuthority] == false
    && changeAuthorityCount[_changeId] >= requiredSignatures) {
      authorities[_oldAuthority] = false;
      authorities[_newAuthority] = true;

      emit AuthorityChanged(_oldAuthority, _newAuthority, _changeId, changeAuthorityCount[_changeId]);
    }
  }

  function stakedAmount(bytes32 _sideTokenId, address _staker) external view returns (uint256) {
    return stakes[_sideTokenId][_staker].amount;
  }

  function hashSideTokenId(uint256 _sideChainId, string _name, string _symbol, uint256 _conversionRate, uint8 _conversionRateDecimals) public view returns (bytes32 sideTokenId) {
    return HashUtils.hashSideTokenId(mainBridge, address(this), _sideChainId, _name, _symbol, _conversionRate, _conversionRateDecimals);
  }

  function vestCount(address _vester) external view returns(uint256) {
    return vests[_vester].length;
  }

  function vestInfo(address _vester, uint256 index) external view returns (address) {
    return address(vests[_vester][index]);
  }
}
