// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '../interfaces/IERC20.sol';
import '../access/Adminnable.sol';

contract ElectionPoll is Adminnable, ReentrancyGuard {
  address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
  IERC20 public voteToken;
  address public receiveAddress;
  address public factory;
  string public name;

  uint256 public startBlock; // start block
  uint256 public endBlock; // end block
  uint256 public closeBlock = 115792089237316195423570985008687907853269984665640564039457584007913129639934;
  bool public init;

  uint256 public minimumToken;
  uint256 public maximumToken;
  bool public burnType;
  bool public multiType;
  uint8 public burnPercent = 100;

  // shold be VoteReceive
  VoteReceive[] private voteHashMessage;
  mapping(address => VoteReceive[]) public voterReceive;
  mapping(address => uint256) public lockAmountOf;
  uint256 public voterCount;
  uint256 public hashMessageCount;

  // need voter address
  struct VoteReceive {
    address voter;
    bytes32 message; // hash message of voter
    uint256 amount;
  }

  modifier onlyVoteTime() {
    require(init == true, 'ElectionPoll: poll is not ready!');
    require(block.number > startBlock, 'ElectionPoll: not in vote time!');
    require(block.number < endBlock, 'ElectionPoll: poll is finished!');
    require(closeBlock > block.number, 'ElectionPoll: poll is set close by admin!');
    _;
  }

  modifier onlyBeforeStart() {
    require(block.number < startBlock, 'ElectionPoll: poll is started!');
    _;
  }

  modifier onlyFinished() {
    require(init && (block.number > endBlock || closeBlock + 1 <= block.number), 'poll is not finished!');
    _;
  }

  event Initialize(
    uint256 _timeStart,
    uint256 _timeEnd,
    uint256 _min,
    uint256 _max,
    bool indexed _burnType,
    bool indexed _multiType,
    uint8 _burnPercent
  );

  event Voted(address indexed _voter, uint256 _amount, bytes32 _hash);
  event Transfer(address indexed _to, uint256 _amount);
  event Burn(address indexed _poll, address indexed _token, uint256 _amount);

  constructor(
    IAdminManage _admin,
    IERC20 _voteToken,
    address _receiveAddress,
    string memory _name
  ) Adminnable(_admin) {
    factory = msg.sender;
    receiveAddress = _receiveAddress;
    voteToken = _voteToken;
    name = _name;
  }

  function initialize(
    uint256 _startBlock,
    uint256 _endBlock,
    uint256 _minimumToken,
    uint256 _maximumToken,
    bool _burnType,
    bool _multiType,
    uint8 _burnPercent
  ) external {
    require(msg.sender == factory, 'ElectionPoll [initialize]: only factory can init ElectionPoll.');
    require(init == false, 'ElectionPoll [initialize]: you can init Poll only 1 time.');
    require(_endBlock > _startBlock, 'ElectionPoll [initialize]: endBlock should more then startBlock.');
    require(_burnPercent <= 100, 'ElectionPoll [initialize]: endBlock should more then startBlock.');

    init = true;
    startBlock = _startBlock;
    endBlock = _endBlock;
    minimumToken = _minimumToken;
    maximumToken = _maximumToken;
    burnType = _burnType;
    multiType = _multiType;
    burnPercent = _burnPercent;

    emit Initialize(startBlock, endBlock, minimumToken, maximumToken, burnType, multiType, burnPercent);
  }

  function editPollVoteTime(uint256 _startBlock, uint256 _endBlock) external onlyAdmin onlyBeforeStart {
    require(endBlock > _startBlock, 'ElectionPoll [editPollVoteTime]: endBlock should more then startBlock.');

    startBlock = _startBlock;
    endBlock = _endBlock;
  }

  function directClosePoll() external onlyAdmin {
    closeBlock = block.number;
  }

  function isFinished() public view returns (bool) {
    return init && (block.number > endBlock || closeBlock + 1 <= block.number);
  }

  function getVoter(address _voter) external view returns (VoteReceive[] memory) {
    return voterReceive[_voter];
  }

  function getHashMessage(uint256 _index) external view returns (VoteReceive memory) {
    return voteHashMessage[_index];
  }

  function burnToken() external onlyAdmin onlyFinished returns (bool) {
    require(burnType, 'ElectionPoll [burnToken]: require ElectionPoll of burn type.');

    uint256 lockedBalance = voteToken.balanceOf(address(this));
    uint256 burnAmount = ((lockedBalance * 1000) / 100) * burnPercent; // add 3 digit

    // transfer burn amount to burn address
    assert(voteToken.transfer(BURN_ADDRESS, burnAmount / 1000));

    uint256 remain = voteToken.balanceOf(address(this));

    // transfer remain to receive wallet
    assert(voteToken.transfer(receiveAddress, remain));

    emit Burn(address(this), address(voteToken), burnAmount / 1000);

    return true;
  }

  function withdrawFor(address _toaddress) external onlyFinished nonReentrant returns (bool) {
    // only burnType can withdraw when finished
    if (burnType == false) {
      _withdrawFor(_toaddress);
      return true;
    }

    // anyone can withdraw if direct close
    require(
      closeBlock + 1 <= block.number,
      'ElectionPoll [withdrawFor]: cannot withdraw from ElectionPoll of Burn type.'
    );
    _withdrawFor(_toaddress);

    return true;
  }

  function unsafeLoopWithdraw(address[] memory _addressList) external onlyFinished nonReentrant returns (bool) {
    if (burnType == false) {
      for (uint256 i = 0; i < _addressList.length; i++) {
        _withdrawFor(_addressList[i]);
      }
      return true;
    }

    require(
      closeBlock + 1 <= block.number,
      'ElectionPoll [withdrawFor]: cannot withdraw from ElectionPoll of Burn type.'
    );
    for (uint256 i = 0; i < _addressList.length; i++) {
      _withdrawFor(_addressList[i]);
    }

    return true;
  }

  function vote(bytes32 _message, uint256 _amount) external onlyVoteTime nonReentrant returns (bool) {
    // check voter
    if (multiType) {
      require(
        lockAmountOf[msg.sender] + _amount <= maximumToken,
        'ElectionPoll [vote]: can not vote more then max limit.'
      );
    } else {
      require(lockAmountOf[msg.sender] == 0, 'ElectionPoll [vote]: already voted.');
    }

    require(voteToken.balanceOf(msg.sender) >= _amount, 'ElectionPoll [vote]: require balanceOf token to vote');

    require(_amount >= minimumToken && _amount <= maximumToken, 'ElectionPoll [vote]: amount not in require range.');
    _vote(msg.sender, _message, _amount);

    return true;
  }

  function _vote(
    address _voter,
    bytes32 _hash,
    uint256 _amount
  ) private {
    assert(voteToken.transferFrom(_voter, address(this), _amount));

    // if frist vote save to count
    if (voterReceive[_voter].length == 0) {
      voterCount++;
    }

    // save vote data
    VoteReceive memory voteReceive = VoteReceive({voter: msg.sender, message: _hash, amount: _amount});
    voterReceive[_voter].push(voteReceive);
    lockAmountOf[_voter] += _amount;
    voteHashMessage.push(voteReceive);
    hashMessageCount++;

    emit Voted(_voter, _amount, _hash);
  }

  function _withdrawFor(address _toaddress) private {
    uint256 lockAmount = lockAmountOf[_toaddress];

    lockAmountOf[_toaddress] = 0;
    assert(voteToken.transfer(_toaddress, lockAmount));

    // transfer to owner of locked token
    emit Transfer(_toaddress, lockAmount);
  }
}
