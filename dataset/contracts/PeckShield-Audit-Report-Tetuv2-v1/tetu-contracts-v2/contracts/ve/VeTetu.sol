// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../openzeppelin/ReentrancyGuard.sol";
import "../openzeppelin/SafeERC20.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IERC20Metadata.sol";
import "../interfaces/IERC721Metadata.sol";
import "../interfaces/IVeTetu.sol";
import "../interfaces/IERC721Receiver.sol";
import "../interfaces/IController.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IPlatformVoter.sol";
import "../interfaces/ISmartVault.sol";
import "../lib/FixedPointMathLib.sol";
import "../proxy/ControllableV3.sol";
import "./VeTetuLogo.sol";

/// @title Voting escrow NFT for multiple underlying tokens.
///        Based on Curve/Solidly contract.
/// @author belbix
contract VeTetu is ControllableV3, ReentrancyGuard, IERC721, IERC721Metadata, IVeTetu {
  using SafeERC20 for IERC20;
  using FixedPointMathLib for uint;
  using FixedPointMathLib for int128;

  // Only for internal usage
  struct DepositInfo {
    address stakingToken;
    uint tokenId;
    uint value;
    uint unlockTime;
    uint lockedAmount;
    uint lockedDerivedAmount;
    uint lockedEnd;
    DepositType depositType;
  }

  // Only for internal usage
  struct CheckpointInfo {
    uint tokenId;
    uint oldDerivedAmount;
    uint newDerivedAmount;
    uint oldEnd;
    uint newEnd;
  }

  enum TimeLockType {
    UNKNOWN,
    ADD_TOKEN,
    WHITELIST_TRANSFER
  }

  // *************************************************************
  //                        CONSTANTS
  // *************************************************************

  /// @dev Version of this contract. Adjust manually on each code modification.
  string public constant VE_VERSION = "1.1.1";
  uint internal constant WEEK = 1 weeks;
  uint internal constant MAX_TIME = 16 weeks;
  int128 internal constant I_MAX_TIME = 16 weeks;
  uint internal constant MULTIPLIER = 1 ether;
  uint internal constant WEIGHT_DENOMINATOR = 100e18;
  uint public constant MAX_ATTACHMENTS = 1;
  uint public constant GOV_ACTION_TIME_LOCK = 18 hours;

  string constant public override name = "veTETU";
  string constant public override symbol = "veTETU";

  /// @dev ERC165 interface ID of ERC165
  bytes4 internal constant _ERC165_INTERFACE_ID = 0x01ffc9a7;
  /// @dev ERC165 interface ID of ERC721
  bytes4 internal constant _ERC721_INTERFACE_ID = 0x80ac58cd;
  /// @dev ERC165 interface ID of ERC721Metadata
  bytes4 internal constant _ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;

  address internal constant _TETU_USDC_BPT = 0xE2f706EF1f7240b803AAe877C9C762644bb808d8;
  address internal constant _TETU_USDC_BPT_VAULT = 0x6922201f0d25Aba8368e7806642625879B35aB84;

  // *************************************************************
  //                        VARIABLES
  //                Keep names and ordering!
  //                 Add only in the bottom.
  // *************************************************************

  /// @dev Underlying tokens info
  address[] public override tokens;
  /// @dev token => weight
  mapping(address => uint) public tokenWeights;
  /// @dev token => is allowed for deposits
  mapping(address => bool) public isValidToken;
  /// @dev Current count of token
  uint public tokenId;
  /// @dev veId => stakingToken => Locked amount
  mapping(uint => mapping(address => uint)) public override lockedAmounts;
  /// @dev veId => Amount based on weights aka power
  mapping(uint => uint) public override lockedDerivedAmount;
  /// @dev veId => Lock end timestamp
  mapping(uint => uint) public override lockedEnd;

  // --- CHECKPOINTS LOGIC

  /// @dev Epoch counter. Update each week.
  uint public override epoch;
  /// @dev epoch -> unsigned point
  mapping(uint => Point) internal _pointHistory;
  /// @dev user -> Point[userEpoch]
  mapping(uint => Point[1000000000]) internal _userPointHistory;
  /// @dev veId -> Personal epoch counter
  mapping(uint => uint) public override userPointEpoch;
  /// @dev time -> signed slope change
  mapping(uint => int128) public slopeChanges;

  // --- LOCK

  /// @dev veId -> Attachments counter. With positive counter user unable to transfer NFT
  mapping(uint => uint) public override attachments;
  /// @dev veId -> votes counter. With votes NFT unable to transfer
  mapping(uint => uint) public override voted;

  // --- STATISTICS

  /// @dev veId -> Block number when last time NFT owner changed
  mapping(uint => uint) public ownershipChange;
  /// @dev Mapping from NFT ID to the address that owns it.
  mapping(uint => address) internal _idToOwner;
  /// @dev Mapping from NFT ID to approved address.
  mapping(uint => address) internal _idToApprovals;
  /// @dev Mapping from owner address to count of his tokens.
  mapping(address => uint) internal _ownerToNFTokenCount;
  /// @dev Mapping from owner address to mapping of index to tokenIds
  mapping(address => mapping(uint => uint)) internal _ownerToNFTokenIdList;
  /// @dev Mapping from NFT ID to index of owner
  mapping(uint => uint) public tokenToOwnerIndex;
  /// @dev Mapping from owner address to mapping of operator addresses.
  mapping(address => mapping(address => bool)) public ownerToOperators;

  /// @dev Mapping of interface id to bool about whether or not it's supported
  mapping(bytes4 => bool) internal _supportedInterfaces;

  // --- PERMISSIONS

  /// @dev Whitelisted contracts will be able to transfer NFTs
  mapping(address => bool) public isWhitelistedTransfer;
  /// @dev Time-locks for governance actions. Zero means not announced and should not processed.
  mapping(TimeLockType => uint) public govActionTimeLock;
  /// @dev underlying token => true if we can stake token to some place, false if paused
  mapping(address => bool) internal tokenFarmingStatus;

  // *************************************************************
  //                        EVENTS
  // *************************************************************

  event Deposit(
    address indexed stakingToken,
    address indexed provider,
    uint tokenId,
    uint value,
    uint indexed locktime,
    DepositType depositType,
    uint ts
  );
  event Withdraw(address indexed stakingToken, address indexed provider, uint tokenId, uint value, uint ts);
  event Merged(address indexed stakingToken, address indexed provider, uint from, uint to);
  event Split(uint parentTokenId, uint newTokenId, uint percent);
  event TransferWhitelisted(address value);
  event StakingTokenAdded(address value, uint weight);
  event GovActionAnnounced(uint _type, uint timeToExecute);

  // *************************************************************
  //                        INIT
  // *************************************************************

  /// @dev Proxy initialization. Call it after contract deploy.
  /// @param token_ Underlying ERC20 token
  /// @param controller_ Central contract of the protocol
  function init(address token_, uint weight, address controller_) external initializer {
    __Controllable_init(controller_);

    // the first token should have 18 decimals
    require(IERC20Metadata(token_).decimals() == uint8(18));
    _addToken(token_, weight);

    _pointHistory[0].blk = block.number;
    _pointHistory[0].ts = block.timestamp;

    _supportedInterfaces[_ERC165_INTERFACE_ID] = true;
    _supportedInterfaces[_ERC721_INTERFACE_ID] = true;
    _supportedInterfaces[_ERC721_METADATA_INTERFACE_ID] = true;

    // mint-ish
    emit Transfer(address(0), address(this), 0);
    // burn-ish
    emit Transfer(address(this), address(0), 0);
  }

  // *************************************************************
  //                        GOVERNANCE ACTIONS
  // *************************************************************

  function announceAction(TimeLockType _type) external {
    require(isGovernance(msg.sender), "FORBIDDEN");
    require(govActionTimeLock[_type] == 0 && _type != TimeLockType.UNKNOWN, "WRONG_INPUT");

    govActionTimeLock[_type] = block.timestamp + GOV_ACTION_TIME_LOCK;
    emit GovActionAnnounced(uint(_type), block.timestamp + GOV_ACTION_TIME_LOCK);
  }

  /// @dev Whitelist address for transfers. Removing from whitelist should be forbidden.
  function whitelistTransferFor(address value) external {
    require(isGovernance(msg.sender), "FORBIDDEN");
    require(value != address(0), "WRONG_INPUT");
    uint timeLock = govActionTimeLock[TimeLockType.WHITELIST_TRANSFER];
    require(timeLock != 0 && timeLock < block.timestamp, "TIME_LOCK");

    isWhitelistedTransfer[value] = true;
    govActionTimeLock[TimeLockType.WHITELIST_TRANSFER] = 0;

    emit TransferWhitelisted(value);
  }

  function addToken(address token, uint weight) external {
    require(isGovernance(msg.sender), "FORBIDDEN");
    uint timeLock = govActionTimeLock[TimeLockType.ADD_TOKEN];
    require(timeLock != 0 && timeLock < block.timestamp, "TIME_LOCK");

    _addToken(token, weight);
    govActionTimeLock[TimeLockType.ADD_TOKEN] = 0;
  }

  function _addToken(address token, uint weight) internal {
    require(token != address(0) && weight != 0, "WRONG_INPUT");
    _requireERC20(token);

    uint length = tokens.length;
    for (uint i; i < length; ++i) {
      require(token != tokens[i], "WRONG_INPUT");
    }

    tokens.push(token);
    tokenWeights[token] = weight;
    isValidToken[token] = true;

    emit StakingTokenAdded(token, weight);
  }

  function changeTokenFarmingAllowanceStatus(address _token, bool status) external {
    require(isGovernance(msg.sender), "FORBIDDEN");
    require(tokenFarmingStatus[_token] != status);
    tokenFarmingStatus[_token] = status;
  }

  // *************************************************************
  //                        VIEWS
  // *************************************************************

  /// @dev Return length of staking tokens.
  function tokensLength() external view returns (uint) {
    return tokens.length;
  }

  /// @dev Current block timestamp
  function blockTimestamp() external view returns (uint) {
    return block.timestamp;
  }

  /// @dev Voter should handle attach/detach and vote actions
  function voter() public view returns (address) {
    return IController(controller()).voter();
  }

  /// @dev Specific voter for control platform attributes.
  function platformVoter() public view returns (address) {
    return IController(controller()).platformVoter();
  }

  /// @dev Interface identification is specified in ERC-165.
  /// @param _interfaceID Id of the interface
  function supportsInterface(bytes4 _interfaceID) public view override(ControllableV3, IERC165) returns (bool) {
    return _supportedInterfaces[_interfaceID]
    || _interfaceID == InterfaceIds.I_VE_TETU
    || super.supportsInterface(_interfaceID);
  }

  /// @notice Get the most recently recorded rate of voting power decrease for `_tokenId`
  /// @param _tokenId token of the NFT
  /// @return Value of the slope
  function getLastUserSlope(uint _tokenId) external view returns (int128) {
    uint uEpoch = userPointEpoch[_tokenId];
    return _userPointHistory[_tokenId][uEpoch].slope;
  }

  /// @notice Get the timestamp for checkpoint `_idx` for `_tokenId`
  /// @param _tokenId token of the NFT
  /// @param _idx User epoch number
  /// @return Epoch time of the checkpoint
  function userPointHistoryTs(uint _tokenId, uint _idx) external view returns (uint) {
    return _userPointHistory[_tokenId][_idx].ts;
  }

  /// @dev Returns the number of NFTs owned by `_owner`.
  ///      Throws if `_owner` is the zero address. NFTs assigned to the zero address are considered invalid.
  /// @param _owner Address for whom to query the balance.
  function _balance(address _owner) internal view returns (uint) {
    return _ownerToNFTokenCount[_owner];
  }

  /// @dev Returns the number of NFTs owned by `_owner`.
  ///      Throws if `_owner` is the zero address. NFTs assigned to the zero address are considered invalid.
  /// @param _owner Address for whom to query the balance.
  function balanceOf(address _owner) external view override returns (uint) {
    return _balance(_owner);
  }

  /// @dev Returns the address of the owner of the NFT.
  /// @param _tokenId The identifier for an NFT.
  function ownerOf(uint _tokenId) public view override returns (address) {
    return _idToOwner[_tokenId];
  }

  /// @dev Get the approved address for a single NFT.
  /// @param _tokenId ID of the NFT to query the approval of.
  function getApproved(uint _tokenId) external view override returns (address) {
    return _idToApprovals[_tokenId];
  }

  /// @dev Checks if `_operator` is an approved operator for `_owner`.
  /// @param _owner The address that owns the NFTs.
  /// @param _operator The address that acts on behalf of the owner.
  function isApprovedForAll(address _owner, address _operator) external view override returns (bool) {
    return (ownerToOperators[_owner])[_operator];
  }

  /// @dev  Get token by index
  function tokenOfOwnerByIndex(address _owner, uint _tokenIndex) external view returns (uint) {
    return _ownerToNFTokenIdList[_owner][_tokenIndex];
  }

  /// @dev Returns whether the given spender can transfer a given token ID
  /// @param _spender address of the spender to query
  /// @param _tokenId uint ID of the token to be transferred
  /// @return bool whether the msg.sender is approved for the given token ID,
  ///              is an operator of the owner, or is the owner of the token
  function isApprovedOrOwner(address _spender, uint _tokenId) public view override returns (bool) {
    address owner = _idToOwner[_tokenId];
    bool spenderIsOwner = owner == _spender;
    bool spenderIsApproved = _spender == _idToApprovals[_tokenId];
    bool spenderIsApprovedForAll = (ownerToOperators[owner])[_spender];
    return spenderIsOwner || spenderIsApproved || spenderIsApprovedForAll;
  }

  function balanceOfNFT(uint _tokenId) public view override returns (uint) {
    // flash NFT protection
    if (ownershipChange[_tokenId] == block.number) {
      return 0;
    }
    return _balanceOfNFT(_tokenId, block.timestamp);
  }

  function balanceOfNFTAt(uint _tokenId, uint _t) external view returns (uint) {
    return _balanceOfNFT(_tokenId, _t);
  }

  function totalSupply() external view returns (uint) {
    return totalSupplyAtT(block.timestamp);
  }

  function balanceOfAtNFT(uint _tokenId, uint _block) external view returns (uint) {
    return _balanceOfAtNFT(_tokenId, _block);
  }

  function userPointHistory(uint _tokenId, uint _loc) external view override returns (Point memory) {
    return _userPointHistory[_tokenId][_loc];
  }

  function pointHistory(uint _loc) external view override returns (Point memory) {
    return _pointHistory[_loc];
  }

  // *************************************************************
  //                        VOTER ACTIONS
  // *************************************************************

  function _onlyVoters() internal view {
    require(msg.sender == voter() || msg.sender == platformVoter(), "NOT_VOTER");
  }

  /// @dev Increment the votes counter.
  ///      Should be called only once per any amount of votes from 1 voter contract.
  function voting(uint _tokenId) external override {
    _onlyVoters();

    // counter reflects only amount of voter contracts
    // restrictions for votes should be implemented on voter side
    voted[_tokenId]++;
  }

  /// @dev Decrement the votes counter. Call only once per voter.
  function abstain(uint _tokenId) external override {
    _onlyVoters();

    voted[_tokenId]--;
  }

  /// @dev Increment attach counter. Call it for each boosted gauge position.
  function attachToken(uint _tokenId) external override {
    // only central voter
    require(msg.sender == voter(), "NOT_VOTER");

    uint count = attachments[_tokenId];
    require(count < MAX_ATTACHMENTS, "TOO_MANY_ATTACHMENTS");
    attachments[_tokenId] = count + 1;
  }

  /// @dev Decrement attach counter. Call it for each boosted gauge position.
  function detachToken(uint _tokenId) external override {
    // only central voter
    require(msg.sender == voter(), "NOT_VOTER");

    attachments[_tokenId] = attachments[_tokenId] - 1;
  }

  /// @dev Remove all votes/attachments for given veID.
  function _detachAll(uint _tokenId, address owner) internal {
    IVoter(voter()).detachTokenFromAll(_tokenId, owner);
    IPlatformVoter(platformVoter()).detachTokenFromAll(_tokenId, owner);
  }

  // *************************************************************
  //                        NFT LOGIC
  // *************************************************************

  /// @dev Add a NFT to an index mapping to a given address
  /// @param _to address of the receiver
  /// @param _tokenId uint ID Of the token to be added
  function _addTokenToOwnerList(address _to, uint _tokenId) internal {
    uint currentCount = _balance(_to);

    _ownerToNFTokenIdList[_to][currentCount] = _tokenId;
    tokenToOwnerIndex[_tokenId] = currentCount;
  }

  /// @dev Remove a NFT from an index mapping to a given address
  /// @param _from address of the sender
  /// @param _tokenId uint ID Of the token to be removed
  function _removeTokenFromOwnerList(address _from, uint _tokenId) internal {
    // Delete
    uint currentCount = _balance(_from) - 1;
    uint currentIndex = tokenToOwnerIndex[_tokenId];

    if (currentCount == currentIndex) {
      // update ownerToNFTokenIdList
      _ownerToNFTokenIdList[_from][currentCount] = 0;
      // update tokenToOwnerIndex
      tokenToOwnerIndex[_tokenId] = 0;
    } else {
      uint lastTokenId = _ownerToNFTokenIdList[_from][currentCount];

      // Add
      // update ownerToNFTokenIdList
      _ownerToNFTokenIdList[_from][currentIndex] = lastTokenId;
      // update tokenToOwnerIndex
      tokenToOwnerIndex[lastTokenId] = currentIndex;

      // Delete
      // update ownerToNFTokenIdList
      _ownerToNFTokenIdList[_from][currentCount] = 0;
      // update tokenToOwnerIndex
      tokenToOwnerIndex[_tokenId] = 0;
    }
  }

  /// @dev Add a NFT to a given address
  function _addTokenTo(address _to, uint _tokenId) internal {
    // assume always call on new tokenId or after _removeTokenFrom() call
    // Change the owner
    _idToOwner[_tokenId] = _to;
    // Update owner token index tracking
    _addTokenToOwnerList(_to, _tokenId);
    // Change count tracking
    _ownerToNFTokenCount[_to] += 1;
  }

  /// @dev Remove a NFT from a given address
  ///      Throws if `_from` is not the current owner.
  function _removeTokenFrom(address _from, uint _tokenId) internal {
    require(_idToOwner[_tokenId] == _from, "NOT_OWNER");
    // Change the owner
    _idToOwner[_tokenId] = address(0);
    // Update owner token index tracking
    _removeTokenFromOwnerList(_from, _tokenId);
    // Change count tracking
    _ownerToNFTokenCount[_from] -= 1;
  }

  /// @dev Execute transfer of a NFT.
  ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
  ///      address for this NFT. (NOTE: `msg.sender` not allowed in internal function so pass `_sender`.)
  ///      Throws if `_to` is the zero address.
  ///      Throws if `_from` is not the current owner.
  ///      Throws if `_tokenId` is not a valid NFT.
  function _transferFrom(
    address _from,
    address _to,
    uint _tokenId,
    address _sender
  ) internal {
    require(isApprovedOrOwner(_sender, _tokenId), "NOT_OWNER");
    require(_to != address(0), "WRONG_INPUT");
    // from address will be checked in _removeTokenFrom()

    if (attachments[_tokenId] != 0 || voted[_tokenId] != 0) {
      _detachAll(_tokenId, _from);
    }

    if (_idToApprovals[_tokenId] != address(0)) {
      // Reset approvals
      _idToApprovals[_tokenId] = address(0);
    }
    _removeTokenFrom(_from, _tokenId);
    _addTokenTo(_to, _tokenId);
    // Set the block of ownership transfer (for Flash NFT protection)
    ownershipChange[_tokenId] = block.number;
    // Log the transfer
    emit Transfer(_from, _to, _tokenId);
  }

  /// @dev Transfers forbidden for veTETU
  function transferFrom(
    address,
    address,
    uint
  ) external pure override {
    revert("FORBIDDEN");
    //    _transferFrom(_from, _to, _tokenId, msg.sender);
  }

  function _isContract(address account) internal view returns (bool) {
    // This method relies on extcodesize, which returns 0 for contracts in
    // construction, since the code is only stored at the end of the
    // constructor execution.
    uint size;
    assembly {
      size := extcodesize(account)
    }
    return size > 0;
  }

  /// @dev Transfers the ownership of an NFT from one address to another address.
  ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the
  ///      approved address for this NFT.
  ///      Throws if `_from` is not the current owner.
  ///      Throws if `_to` is the zero address.
  ///      Throws if `_tokenId` is not a valid NFT.
  ///      If `_to` is a smart contract, it calls `onERC721Received` on `_to` and throws if
  ///      the return value is not `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`.
  /// @param _from The current owner of the NFT.
  /// @param _to The new owner.
  /// @param _tokenId The NFT to transfer.
  /// @param _data Additional data with no specified format, sent in call to `_to`.
  function safeTransferFrom(
    address _from,
    address _to,
    uint _tokenId,
    bytes memory _data
  ) public override {
    require(isWhitelistedTransfer[_to] || isWhitelistedTransfer[_from], "FORBIDDEN");

    _transferFrom(_from, _to, _tokenId, msg.sender);
    require(_checkOnERC721Received(_from, _to, _tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
  }


  /// @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
  /// The call is not executed if the target address is not a contract.
  ///
  /// @param _from address representing the previous owner of the given token ID
  /// @param _to target address that will receive the tokens
  /// @param _tokenId uint256 ID of the token to be transferred
  /// @param _data bytes optional data to send along with the call
  /// @return bool whether the call correctly returned the expected magic value
  ///
  function _checkOnERC721Received(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes memory _data
  ) private returns (bool) {
    if (_isContract(_to)) {
      try IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) returns (bytes4 retval) {
        return retval == IERC721Receiver.onERC721Received.selector;
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          revert("ERC721: transfer to non ERC721Receiver implementer");
        } else {
          /// @solidity memory-safe-assembly
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    } else {
      return true;
    }
  }

  /// @dev Transfers the ownership of an NFT from one address to another address.
  ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the
  ///      approved address for this NFT.
  ///      Throws if `_from` is not the current owner.
  ///      Throws if `_to` is the zero address.
  ///      Throws if `_tokenId` is not a valid NFT.
  ///      If `_to` is a smart contract, it calls `onERC721Received` on `_to` and throws if
  ///      the return value is not `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`.
  /// @param _from The current owner of the NFT.
  /// @param _to The new owner.
  /// @param _tokenId The NFT to transfer.
  function safeTransferFrom(
    address _from,
    address _to,
    uint _tokenId
  ) external override {
    safeTransferFrom(_from, _to, _tokenId, "");
  }

  /// @dev Set or reaffirm the approved address for an NFT. The zero address indicates there is no approved address.
  ///      Throws unless `msg.sender` is the current NFT owner, or an authorized operator of the current owner.
  ///      Throws if `_tokenId` is not a valid NFT. (NOTE: This is not written the EIP)
  ///      Throws if `_approved` is the current owner. (NOTE: This is not written the EIP)
  /// @param _approved Address to be approved for the given NFT ID.
  /// @param _tokenId ID of the token to be approved.
  function approve(address _approved, uint _tokenId) public override {
    address owner = _idToOwner[_tokenId];
    // Throws if `_tokenId` is not a valid NFT
    require(owner != address(0), "WRONG_INPUT");
    // Throws if `_approved` is the current owner
    require(_approved != owner, "IDENTICAL_ADDRESS");
    // Check requirements
    bool senderIsOwner = (owner == msg.sender);
    bool senderIsApprovedForAll = (ownerToOperators[owner])[msg.sender];
    require(senderIsOwner || senderIsApprovedForAll, "NOT_OWNER");
    // Set the approval
    _idToApprovals[_tokenId] = _approved;
    emit Approval(owner, _approved, _tokenId);
  }

  /// @dev Enables or disables approval for a third party ("operator") to manage all of
  ///      `msg.sender`'s assets. It also emits the ApprovalForAll event.
  ///      Throws if `_operator` is the `msg.sender`. (NOTE: This is not written the EIP)
  /// @notice This works even if sender doesn't own any tokens at the time.
  /// @param _operator Address to add to the set of authorized operators.
  /// @param _approved True if the operators is approved, false to revoke approval.
  function setApprovalForAll(address _operator, bool _approved) external override {
    // Throws if `_operator` is the `msg.sender`
    require(_operator != msg.sender, "IDENTICAL_ADDRESS");
    ownerToOperators[msg.sender][_operator] = _approved;
    emit ApprovalForAll(msg.sender, _operator, _approved);
  }

  /// @dev Function to mint tokens
  ///      Throws if `_to` is zero address.
  ///      Throws if `_tokenId` is owned by someone.
  /// @param _to The address that will receive the minted tokens.
  /// @param _tokenId The token id to mint.
  /// @return A boolean that indicates if the operation was successful.
  function _mint(address _to, uint _tokenId) internal returns (bool) {
    // Throws if `_to` is zero address
    require(_to != address(0), "WRONG_INPUT");
    _addTokenTo(_to, _tokenId);
    require(_checkOnERC721Received(address(0), _to, _tokenId, ''), "ERC721: transfer to non ERC721Receiver implementer");
    emit Transfer(address(0), _to, _tokenId);
    return true;
  }

  /// @notice Record global and per-user data to checkpoint
  function _checkpoint(CheckpointInfo memory info) internal {
    Point memory uOld;
    Point memory uNew;
    int128 oldDSlope = 0;
    int128 newDSlope = 0;
    uint _epoch = epoch;

    if (info.tokenId != 0) {
      // Calculate slopes and biases
      // Kept at zero when they have to
      if (info.oldEnd > block.timestamp && info.oldDerivedAmount > 0) {
        uOld.slope = int128(uint128(info.oldDerivedAmount)) / I_MAX_TIME;
        uOld.bias = uOld.slope * int128(int256(info.oldEnd - block.timestamp));
      }
      if (info.newEnd > block.timestamp && info.newDerivedAmount > 0) {
        uNew.slope = int128(uint128(info.newDerivedAmount)) / I_MAX_TIME;
        uNew.bias = uNew.slope * int128(int256(info.newEnd - block.timestamp));
      }

      // Read values of scheduled changes in the slope
      // oldLocked.end can be in the past and in the future
      // newLocked.end can ONLY by in the FUTURE unless everything expired: than zeros
      oldDSlope = slopeChanges[info.oldEnd];
      if (info.newEnd != 0) {
        if (info.newEnd == info.oldEnd) {
          newDSlope = oldDSlope;
        } else {
          newDSlope = slopeChanges[info.newEnd];
        }
      }
    }

    Point memory lastPoint = Point({bias : 0, slope : 0, ts : block.timestamp, blk : block.number});
    if (_epoch > 0) {
      lastPoint = _pointHistory[_epoch];
    }
    uint lastCheckpoint = lastPoint.ts;
    // initialLastPoint is used for extrapolation to calculate block number
    // (approximately, for *At methods) and save them
    // as we cannot figure that out exactly from inside the contract
    Point memory initialLastPoint = lastPoint;
    uint blockSlope = 0;
    // dblock/dt
    if (block.timestamp > lastPoint.ts) {
      blockSlope = (MULTIPLIER * (block.number - lastPoint.blk)) / (block.timestamp - lastPoint.ts);
    }
    // If last point is already recorded in this block, slope=0
    // But that's ok b/c we know the block in such case

    // Go over weeks to fill history and calculate what the current point is
    {
      uint ti = (lastCheckpoint / WEEK) * WEEK;
      // Hopefully it won't happen that this won't get used in 5 years!
      // If it does, users will be able to withdraw but vote weight will be broken
      for (uint i = 0; i < 255; ++i) {
        ti += WEEK;
        int128 dSlope = 0;
        if (ti > block.timestamp) {
          ti = block.timestamp;
        } else {
          dSlope = slopeChanges[ti];
        }
        lastPoint.bias = (lastPoint.bias - lastPoint.slope * int128(int256(ti - lastCheckpoint))).positiveInt128();
        lastPoint.slope = (lastPoint.slope + dSlope).positiveInt128();
        lastCheckpoint = ti;
        lastPoint.ts = ti;
        lastPoint.blk = initialLastPoint.blk + (blockSlope * (ti - initialLastPoint.ts)) / MULTIPLIER;
        _epoch += 1;
        if (ti == block.timestamp) {
          lastPoint.blk = block.number;
          break;
        } else {
          _pointHistory[_epoch] = lastPoint;
        }
      }
    }

    epoch = _epoch;
    // Now pointHistory is filled until t=now

    if (info.tokenId != 0) {
      // If last point was in this block, the slope change has been applied already
      // But in such case we have 0 slope(s)
      lastPoint.slope = (lastPoint.slope + (uNew.slope - uOld.slope)).positiveInt128();
      lastPoint.bias = (lastPoint.bias + (uNew.bias - uOld.bias)).positiveInt128();
    }

    // Record the changed point into history
    _pointHistory[_epoch] = lastPoint;

    if (info.tokenId != 0) {
      // Schedule the slope changes (slope is going down)
      // We subtract newUserSlope from [newLocked.end]
      // and add old_user_slope to [old_locked.end]
      if (info.oldEnd > block.timestamp) {
        // old_dslope was <something> - u_old.slope, so we cancel that
        oldDSlope += uOld.slope;
        if (info.newEnd == info.oldEnd) {
          oldDSlope -= uNew.slope;
          // It was a new deposit, not extension
        }
        slopeChanges[info.oldEnd] = oldDSlope;
      }

      if (info.newEnd > block.timestamp) {
        if (info.newEnd > info.oldEnd) {
          newDSlope -= uNew.slope;
          // old slope disappeared at this point
          slopeChanges[info.newEnd] = newDSlope;
        }
        // else: we recorded it already in oldDSlope
      }
      // Now handle user history
      uint userEpoch = userPointEpoch[info.tokenId] + 1;

      userPointEpoch[info.tokenId] = userEpoch;
      uNew.ts = block.timestamp;
      uNew.blk = block.number;
      _userPointHistory[info.tokenId][userEpoch] = uNew;
    }
  }

  // *************************************************************
  //                  DEPOSIT/WITHDRAW LOGIC
  // *************************************************************

  /// @dev Pull tokens to this contract and try to stake
  function _pullStakingToken(address _token, address _from, uint amount) internal {
    IERC20(_token).safeTransferFrom(_from, address(this), amount);

    // try to stake tokens if possible
    _stakeAvailableTokens(_token);
  }

  /// @dev Anyone can stake whitelisted tokens if they exist on this contract.
  function stakeAvailableTokens(address _token) external {
    _stakeAvailableTokens(_token);
  }

  /// @dev If allowed, stake given token available balance to suitable place for earn some profit
  function _stakeAvailableTokens(address _token) internal {
    if (tokenFarmingStatus[_token]) {
      if (_token == _TETU_USDC_BPT) {
        uint balance = IERC20(_token).balanceOf(address(this));
        if (balance != 0) {
          IERC20(_token).safeApprove(_TETU_USDC_BPT_VAULT, balance);
          ISmartVault(_TETU_USDC_BPT_VAULT).depositAndInvest(balance);
        }
      }
    }
  }

  /// @dev Unstake necessary amount, if possible
  function _unstakeTokens(address _token, uint amount) internal {
    uint tokenBalance = IERC20(_token).balanceOf(address(this));
    if (amount != 0 && amount > tokenBalance) {
      // withdraw only required amount
      amount -= tokenBalance;
      // no need to check whitelisting for withdraw
      if (_token == _TETU_USDC_BPT) {
        // add gap value for avoid rounding issues
        uint shares = amount * 1e18 / ISmartVault(_TETU_USDC_BPT_VAULT).getPricePerFullShare() + 1e18;
        uint sharesBalance = IERC20(_TETU_USDC_BPT_VAULT).balanceOf(address(this));
        shares = shares > sharesBalance ? sharesBalance : shares;
        ISmartVault(_TETU_USDC_BPT_VAULT).withdraw(shares);
      }
    }
  }

  /// @dev Anyone can withdraw all staked tokens if farming status = false
  function emergencyWithdrawStakedTokens(address _token) external {
    if (!tokenFarmingStatus[_token]) {
      if (_token == _TETU_USDC_BPT) {
        ISmartVault(_TETU_USDC_BPT_VAULT).exit();
      }
    }
  }

  /// @dev Transfer underlying token to recipient, unstake if need required amount
  function _transferUnderlyingToken(address _token, address recipient, uint amount) internal {
    _unstakeTokens(_token, amount);
    IERC20(_token).safeTransfer(recipient, amount);
  }

  /// @notice Deposit and lock tokens for a user
  function _depositFor(DepositInfo memory info) internal {

    uint newLockedDerivedAmount = info.lockedDerivedAmount;
    if (info.value != 0) {

      // calculate new amounts
      uint newAmount = info.lockedAmount + info.value;
      newLockedDerivedAmount = _calculateDerivedAmount(
        info.lockedAmount,
        info.lockedDerivedAmount,
        newAmount,
        tokenWeights[info.stakingToken],
        IERC20Metadata(info.stakingToken).decimals()
      );
      // update chain info
      lockedAmounts[info.tokenId][info.stakingToken] = newAmount;
      lockedDerivedAmount[info.tokenId] = newLockedDerivedAmount;
    }

    // Adding to existing lock, or if a lock is expired - creating a new one
    uint newLockedEnd = info.lockedEnd;
    if (info.unlockTime != 0) {
      lockedEnd[info.tokenId] = info.unlockTime;
      newLockedEnd = info.unlockTime;
    }

    // update checkpoint
    _checkpoint(CheckpointInfo(
        info.tokenId,
        info.lockedDerivedAmount,
        newLockedDerivedAmount,
        info.lockedEnd,
        newLockedEnd
      ));

    // move tokens to this contract, if necessary
    address from = msg.sender;
    if (info.value != 0 && info.depositType != DepositType.MERGE_TYPE) {
      _pullStakingToken(info.stakingToken, from, info.value);
    }

    emit Deposit(info.stakingToken, from, info.tokenId, info.value, newLockedEnd, info.depositType, block.timestamp);
  }

  function _calculateDerivedAmount(
    uint currentAmount,
    uint oldDerivedAmount,
    uint newAmount,
    uint weight,
    uint8 decimals
  ) internal pure returns (uint) {
    // subtract current derived balance
    // rounded to UP for subtracting closer to 0 value
    if (oldDerivedAmount != 0 && currentAmount != 0) {
      currentAmount = currentAmount.divWadUp(10 ** decimals);
      uint currentDerivedAmount = currentAmount.mulDivUp(weight, WEIGHT_DENOMINATOR);
      if (oldDerivedAmount > currentDerivedAmount) {
        oldDerivedAmount -= currentDerivedAmount;
      } else {
        // in case of wrong rounding better to set to zero than revert
        oldDerivedAmount = 0;
      }
    }

    // recalculate derived amount with new amount
    // rounded to DOWN
    // normalize decimals to 18
    newAmount = newAmount.divWadDown(10 ** decimals);
    // calculate the final amount based on the weight
    newAmount = newAmount.mulDivDown(weight, WEIGHT_DENOMINATOR);
    return oldDerivedAmount + newAmount;
  }

  /// @notice Record global data to checkpoint
  function checkpoint() external override {
    _checkpoint(CheckpointInfo(0, 0, 0, 0, 0));
  }

  function _lockInfo(address stakingToken, uint veId) internal view returns (
    uint _lockedAmount,
    uint _lockedDerivedAmount,
    uint _lockedEnd
  ) {
    _lockedAmount = lockedAmounts[veId][stakingToken];
    _lockedDerivedAmount = lockedDerivedAmount[veId];
    _lockedEnd = lockedEnd[veId];
  }

  function _incrementTokenIdAndGet() internal returns (uint){
    uint current = tokenId;
    tokenId = current + 1;
    return current + 1;
  }

  /// @notice Deposit `_value` tokens for `_to` and lock for `_lock_duration`
  /// @param _token Token for deposit. Should be whitelisted in this contract.
  /// @param _value Amount to deposit
  /// @param _lockDuration Number of seconds to lock tokens for (rounded down to nearest week)
  /// @param _to Address to deposit
  function _createLock(address _token, uint _value, uint _lockDuration, address _to) internal returns (uint) {
    require(_value > 0, "WRONG_INPUT");
    // Lock time is rounded down to weeks
    uint unlockTime = (block.timestamp + _lockDuration) / WEEK * WEEK;
    require(unlockTime > block.timestamp, "LOW_LOCK_PERIOD");
    require(unlockTime <= block.timestamp + MAX_TIME, "HIGH_LOCK_PERIOD");
    require(isValidToken[_token], "INVALID_TOKEN");

    uint _tokenId = _incrementTokenIdAndGet();
    _mint(_to, _tokenId);

    _depositFor(DepositInfo({
    stakingToken : _token,
    tokenId : _tokenId,
    value : _value,
    unlockTime : unlockTime,
    lockedAmount : 0,
    lockedDerivedAmount : 0,
    lockedEnd : 0,
    depositType : DepositType.CREATE_LOCK_TYPE
    }));
    return _tokenId;
  }

  /// @notice Deposit `_value` tokens for `_to` and lock for `_lock_duration`
  /// @param _token Token for deposit. Should be whitelisted in this contract.
  /// @param _value Amount to deposit
  /// @param _lockDuration Number of seconds to lock tokens for (rounded down to nearest week)
  /// @param _to Address to deposit
  function createLockFor(address _token, uint _value, uint _lockDuration, address _to)
  external nonReentrant override returns (uint) {
    return _createLock(_token, _value, _lockDuration, _to);
  }

  /// @notice Deposit `_value` tokens for `msg.sender` and lock for `_lock_duration`
  /// @param _value Amount to deposit
  /// @param _lockDuration Number of seconds to lock tokens for (rounded down to nearest week)
  function createLock(address _token, uint _value, uint _lockDuration) external nonReentrant returns (uint) {
    return _createLock(_token, _value, _lockDuration, msg.sender);
  }

  /// @notice Deposit `_value` additional tokens for `_tokenId` without modifying the unlock time
  /// @dev Anyone (even a smart contract) can deposit for someone else, but
  ///      cannot extend their locktime and deposit for a brand new user
  /// @param _token Token for deposit. Should be whitelisted in this contract.
  /// @param _tokenId ve token ID
  /// @param _value Amount of tokens to deposit and add to the lock
  function increaseAmount(address _token, uint _tokenId, uint _value) external nonReentrant override {
    require(_value > 0, "WRONG_INPUT");
    (uint _lockedAmount, uint _lockedDerivedAmount, uint _lockedEnd) = _lockInfo(_token, _tokenId);

    require(_lockedDerivedAmount > 0, "NFT_WITHOUT_POWER");
    require(_lockedEnd > block.timestamp, "EXPIRED");
    require(isValidToken[_token], "INVALID_TOKEN");

    _depositFor(DepositInfo({
    stakingToken : _token,
    tokenId : _tokenId,
    value : _value,
    unlockTime : 0,
    lockedAmount : _lockedAmount,
    lockedDerivedAmount : _lockedDerivedAmount,
    lockedEnd : _lockedEnd,
    depositType : DepositType.INCREASE_LOCK_AMOUNT
    }));
  }

  /// @notice Extend the unlock time for `_tokenId`
  /// @param _tokenId ve token ID
  /// @param _lockDuration New number of seconds until tokens unlock
  function increaseUnlockTime(uint _tokenId, uint _lockDuration) external nonReentrant returns (
    uint power,
    uint unlockDate
  )  {
    uint _lockedDerivedAmount = lockedDerivedAmount[_tokenId];
    uint _lockedEnd = lockedEnd[_tokenId];
    // Lock time is rounded down to weeks
    uint unlockTime = (block.timestamp + _lockDuration) / WEEK * WEEK;
    require(_lockedDerivedAmount > 0, "NFT_WITHOUT_POWER");
    require(_lockedEnd > block.timestamp, "EXPIRED");
    require(unlockTime > _lockedEnd, "LOW_UNLOCK_TIME");
    require(unlockTime <= block.timestamp + MAX_TIME, "HIGH_LOCK_PERIOD");
    require(isApprovedOrOwner(msg.sender, _tokenId), "NOT_OWNER");

    _depositFor(DepositInfo({
    stakingToken : address(0),
    tokenId : _tokenId,
    value : 0,
    unlockTime : unlockTime,
    lockedAmount : 0,
    lockedDerivedAmount : _lockedDerivedAmount,
    lockedEnd : _lockedEnd,
    depositType : DepositType.INCREASE_UNLOCK_TIME
    }));

    power = balanceOfNFT(_tokenId);
    unlockDate = lockedEnd[_tokenId];
  }

  /// @dev Merge two NFTs union their balances and keep the biggest lock time.
  function merge(uint _from, uint _to) external nonReentrant {
    require(attachments[_from] == 0 && voted[_from] == 0, "ATTACHED");
    require(_from != _to, "IDENTICAL_ADDRESS");
    require(_idToOwner[_from] == msg.sender && _idToOwner[_to] == msg.sender, "NOT_OWNER");

    uint lockedEndFrom = lockedEnd[_from];
    uint lockedEndTo = lockedEnd[_to];
    uint end = lockedEndFrom >= lockedEndTo ? lockedEndFrom : lockedEndTo;
    uint oldDerivedAmount = lockedDerivedAmount[_from];

    uint length = tokens.length;
    // we should use the old one for properly calculate checkpoint for the new ve
    uint newLockedEndTo = lockedEndTo;
    for (uint i; i < length; i++) {
      address stakingToken = tokens[i];
      uint _lockedAmountFrom = lockedAmounts[_from][stakingToken];
      if (_lockedAmountFrom == 0) {
        continue;
      }
      lockedAmounts[_from][stakingToken] = 0;

      _depositFor(DepositInfo({
      stakingToken : stakingToken,
      tokenId : _to,
      value : _lockedAmountFrom,
      unlockTime : end,
      lockedAmount : lockedAmounts[_to][stakingToken],
      lockedDerivedAmount : lockedDerivedAmount[_to],
      lockedEnd : newLockedEndTo,
      depositType : DepositType.MERGE_TYPE
      }));

      // set new lock time to the current end lock
      newLockedEndTo = end;

      emit Merged(stakingToken, msg.sender, _from, _to);
    }

    lockedDerivedAmount[_from] = 0;
    lockedEnd[_from] = 0;

    // update checkpoint
    _checkpoint(CheckpointInfo(
        _from,
        oldDerivedAmount,
        0,
        lockedEndFrom,
        lockedEndFrom
      ));

    _burn(_from);
  }

  /// @dev Split given veNFT. A new NFT will have a given percent of underlying tokens.
  /// @param _tokenId ve token ID
  /// @param percent percent of underlying tokens for new NFT with denominator 1e18 (1-(100e18-1)).
  function split(uint _tokenId, uint percent) external nonReentrant {
    require(attachments[_tokenId] == 0 && voted[_tokenId] == 0, "ATTACHED");
    require(_idToOwner[_tokenId] == msg.sender, "NOT_OWNER");
    require(percent != 0 && percent < 100e18, "WRONG_INPUT");

    uint _lockedDerivedAmount = lockedDerivedAmount[_tokenId];
    uint oldLockedDerivedAmount = _lockedDerivedAmount;
    uint _lockedEnd = lockedEnd[_tokenId];

    require(_lockedEnd > block.timestamp, "EXPIRED");

    // crete new NFT
    uint _newTokenId = _incrementTokenIdAndGet();
    _mint(msg.sender, _newTokenId);

    // migrate percent of locked tokens to the new NFT
    uint length = tokens.length;
    for (uint i; i < length; ++i) {
      address stakingToken = tokens[i];
      uint _lockedAmount = lockedAmounts[_tokenId][stakingToken];
      if (_lockedAmount == 0) {
        continue;
      }
      uint amountForNewNFT = _lockedAmount * percent / 100e18;
      require(amountForNewNFT != 0, "LOW_PERCENT");

      uint newLockedDerivedAmount = _calculateDerivedAmount(
        _lockedAmount,
        _lockedDerivedAmount,
        _lockedAmount - amountForNewNFT,
        tokenWeights[stakingToken],
        IERC20Metadata(stakingToken).decimals()
      );

      _lockedDerivedAmount = newLockedDerivedAmount;

      lockedAmounts[_tokenId][stakingToken] = _lockedAmount - amountForNewNFT;

      // increase values for new NFT
      _depositFor(DepositInfo({
      stakingToken : stakingToken,
      tokenId : _newTokenId,
      value : amountForNewNFT,
      unlockTime : _lockedEnd,
      lockedAmount : 0,
      lockedDerivedAmount : lockedDerivedAmount[_newTokenId],
      lockedEnd : _lockedEnd,
      depositType : DepositType.MERGE_TYPE
      }));
    }

    // update derived amount
    lockedDerivedAmount[_tokenId] = _lockedDerivedAmount;

    // update checkpoint
    _checkpoint(CheckpointInfo(
        _tokenId,
        oldLockedDerivedAmount,
        _lockedDerivedAmount,
        _lockedEnd,
        _lockedEnd
      ));

    emit Split(_tokenId, _newTokenId, percent);
  }

  /// @notice Withdraw all staking tokens for `_tokenId`
  /// @dev Only possible if the lock has expired
  function withdrawAll(uint _tokenId) external {
    uint length = tokens.length;
    for (uint i; i < length; ++i) {
      address token = tokens[i];
      if (lockedAmounts[_tokenId][token] != 0) {
        withdraw(token, _tokenId);
      }
    }
  }

  /// @notice Withdraw given staking token for `_tokenId`
  /// @dev Only possible if the lock has expired
  function withdraw(address stakingToken, uint _tokenId) public nonReentrant {
    require(isApprovedOrOwner(msg.sender, _tokenId), "NOT_OWNER");
    require(attachments[_tokenId] == 0 && voted[_tokenId] == 0, "ATTACHED");

    (uint oldLockedAmount, uint oldLockedDerivedAmount, uint oldLockedEnd) =
    _lockInfo(stakingToken, _tokenId);
    require(block.timestamp >= oldLockedEnd, "NOT_EXPIRED");
    require(oldLockedAmount > 0, "ZERO_LOCKED");


    uint newLockedDerivedAmount = _calculateDerivedAmount(
      oldLockedAmount,
      oldLockedDerivedAmount,
      0,
      tokenWeights[stakingToken],
      IERC20Metadata(stakingToken).decimals()
    );

    // if no tokens set lock to zero
    uint newLockEnd = oldLockedEnd;
    if (newLockedDerivedAmount == 0) {
      lockedEnd[_tokenId] = 0;
      newLockEnd = 0;
    }

    // update derived amount
    lockedDerivedAmount[_tokenId] = newLockedDerivedAmount;

    // set locked amount to zero, we will withdraw all
    lockedAmounts[_tokenId][stakingToken] = 0;

    // update checkpoint
    _checkpoint(CheckpointInfo(
        _tokenId,
        oldLockedDerivedAmount,
        newLockedDerivedAmount,
        oldLockedEnd,
        newLockEnd
      ));

    // Burn the NFT
    if (newLockedDerivedAmount == 0) {
      _burn(_tokenId);
    }

    _transferUnderlyingToken(stakingToken, msg.sender, oldLockedAmount);

    emit Withdraw(stakingToken, msg.sender, _tokenId, oldLockedAmount, block.timestamp);
  }

  // The following ERC20/minime-compatible methods are not real balanceOf and supply!
  // They measure the weights for the purpose of voting, so they don't represent
  // real coins.

  /// @notice Binary search to estimate timestamp for block number
  /// @param _block Block to find
  /// @param maxEpoch Don't go beyond this epoch
  /// @return Approximate timestamp for block
  function _findBlockEpoch(uint _block, uint maxEpoch) internal view returns (uint) {
    // Binary search
    uint _min = 0;
    uint _max = maxEpoch;
    for (uint i = 0; i < 128; ++i) {
      // Will be always enough for 128-bit numbers
      if (_min >= _max) {
        break;
      }
      uint _mid = (_min + _max + 1) / 2;
      if (_pointHistory[_mid].blk <= _block) {
        _min = _mid;
      } else {
        _max = _mid - 1;
      }
    }
    return _min;
  }

  /// @notice Get the current voting power for `_tokenId`
  /// @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
  /// @param _tokenId NFT for lock
  /// @param _t Epoch time to return voting power at
  /// @return User voting power
  function _balanceOfNFT(uint _tokenId, uint _t) internal view returns (uint) {
    uint _epoch = userPointEpoch[_tokenId];
    if (_epoch == 0) {
      return 0;
    } else {
      Point memory lastPoint = _userPointHistory[_tokenId][_epoch];
      require(_t >= lastPoint.ts, "WRONG_INPUT");
      lastPoint.bias -= lastPoint.slope * int128(int256(_t) - int256(lastPoint.ts));
      if (lastPoint.bias < 0) {
        lastPoint.bias = 0;
      }
      return uint(int256(lastPoint.bias));
    }
  }

  /// @dev Returns current token URI metadata
  /// @param _tokenId Token ID to fetch URI for.
  function tokenURI(uint _tokenId) external view override returns (string memory) {
    require(_idToOwner[_tokenId] != address(0), "TOKEN_NOT_EXIST");

    uint _lockedEnd = lockedEnd[_tokenId];
    return
    VeTetuLogo.tokenURI(
      _tokenId,
      uint(int256(lockedDerivedAmount[_tokenId])),
      block.timestamp < _lockedEnd ? _lockedEnd - block.timestamp : 0,
      _balanceOfNFT(_tokenId, block.timestamp)
    );
  }

  /// @notice Measure voting power of `_tokenId` at block height `_block`
  /// @dev Adheres to MiniMe `balanceOfAt` interface: https://github.com/Giveth/minime
  /// @param _tokenId User's wallet NFT
  /// @param _block Block to calculate the voting power at
  /// @return Voting power
  function _balanceOfAtNFT(uint _tokenId, uint _block) internal view returns (uint) {
    // Copying and pasting totalSupply code because Vyper cannot pass by
    // reference yet
    require(_block <= block.number, "WRONG_INPUT");

    // Binary search
    uint _min = 0;
    uint _max = userPointEpoch[_tokenId];
    for (uint i = 0; i < 128; ++i) {
      // Will be always enough for 128-bit numbers
      if (_min >= _max) {
        break;
      }
      uint _mid = (_min + _max + 1) / 2;
      if (_userPointHistory[_tokenId][_mid].blk <= _block) {
        _min = _mid;
      } else {
        _max = _mid - 1;
      }
    }

    Point memory uPoint = _userPointHistory[_tokenId][_min];

    uint maxEpoch = epoch;
    uint _epoch = _findBlockEpoch(_block, maxEpoch);
    Point memory point0 = _pointHistory[_epoch];
    uint dBlock = 0;
    uint dt = 0;
    if (_epoch < maxEpoch) {
      Point memory point1 = _pointHistory[_epoch + 1];
      dBlock = point1.blk - point0.blk;
      dt = point1.ts - point0.ts;
    } else {
      dBlock = block.number - point0.blk;
      dt = block.timestamp - point0.ts;
    }
    uint blockTime = point0.ts;
    if (dBlock != 0 && _block > point0.blk) {
      blockTime += (dt * (_block - point0.blk)) / dBlock;
    }

    uPoint.bias -= uPoint.slope * int128(int256(blockTime - uPoint.ts));
    return uint(uint128(uPoint.bias.positiveInt128()));
  }



  /// @notice Calculate total voting power at some point in the past
  /// @param point The point (bias/slope) to start search from
  /// @param t Time to calculate the total voting power at
  /// @return Total voting power at that time
  function _supplyAt(Point memory point, uint t) internal view returns (uint) {
    Point memory lastPoint = point;
    uint ti = (lastPoint.ts / WEEK) * WEEK;
    for (uint i = 0; i < 255; ++i) {
      ti += WEEK;
      int128 dSlope = 0;
      if (ti > t) {
        ti = t;
      } else {
        dSlope = slopeChanges[ti];
      }
      lastPoint.bias -= lastPoint.slope * int128(int256(ti - lastPoint.ts));
      if (ti == t) {
        break;
      }
      lastPoint.slope += dSlope;
      lastPoint.ts = ti;
    }
    return uint(uint128(lastPoint.bias.positiveInt128()));
  }

  /// @notice Calculate total voting power
  /// @dev Adheres to the ERC20 `totalSupply` interface for Aragon compatibility
  /// @return Total voting power
  function totalSupplyAtT(uint t) public view returns (uint) {
    uint _epoch = epoch;
    Point memory lastPoint = _pointHistory[_epoch];
    return _supplyAt(lastPoint, t);
  }

  /// @notice Calculate total voting power at some point in the past
  /// @param _block Block to calculate the total voting power at
  /// @return Total voting power at `_block`
  function totalSupplyAt(uint _block) external view override returns (uint) {
    require(_block <= block.number, "WRONG_INPUT");
    uint _epoch = epoch;
    uint targetEpoch = _findBlockEpoch(_block, _epoch);

    Point memory point = _pointHistory[targetEpoch];
    // it is possible only for a block before the launch
    // return 0 as more clear answer than revert
    if (point.blk > _block) {
      return 0;
    }
    uint dt = 0;
    if (targetEpoch < _epoch) {
      Point memory pointNext = _pointHistory[targetEpoch + 1];
      // next point block can not be the same or lower
      dt = ((_block - point.blk) * (pointNext.ts - point.ts)) / (pointNext.blk - point.blk);
    } else {
      if (point.blk != block.number) {
        dt = ((_block - point.blk) * (block.timestamp - point.ts)) / (block.number - point.blk);
      }
    }
    // Now dt contains info on how far are we beyond point
    return _supplyAt(point, point.ts + dt);
  }

  function _burn(uint _tokenId) internal {
    address owner = ownerOf(_tokenId);
    // Clear approval
    approve(address(0), _tokenId);
    // Remove token
    _removeTokenFrom(owner, _tokenId);
    emit Transfer(owner, address(0), _tokenId);
  }

}
