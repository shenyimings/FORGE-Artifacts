//SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Signature.sol";

/// @title The voting engine onchain interface
/// @author Noah Jelich
/// @notice A significant part of the voting logic is implemented offchain, with gasless user signatures
/// @dev The interface interacts with the offchain backend by publishing events, and receiving signed messages by the owner
contract VotingEngine is Initializable, PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable, Signature {
  event Deposited(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);

  event VoteProposed(uint256 indexed proposal, uint256 rewards);
  event VoteResolved(uint256 indexed proposal, string ipfs);

  /// @notice interface for the list token
  IERC20 public list;

  /// @notice nonces to prevent double withdrawals
  mapping(address => uint256) public nonceMap;
  /// @notice utility mapping to make reading the withdrawn amount easier
  mapping(address => uint256) public withdrawn;

  /// @notice simple counter to provide unique ids to each voter - skipped ids dont matter
  uint256 internal _voteCounter;
  /// @notice mapping of voting id to an ipfs hash with the vote results (signed lister data, signed votes)
  mapping(uint256 => string) internal _voteResolutionHash;

  /// @notice Initialize the upgradeable contract
  /// @param listContractAddress_ The address where the LIST utility contract is deployed
  function initialize(address listContractAddress_) external initializer {
    __Context_init_unchained();
    __Pausable_init_unchained();
    __Ownable_init_unchained();
    __ReentrancyGuard_init_unchained();

    list = IERC20(listContractAddress_);
    _voteCounter = 0;

    _pause();
  }

  /// @dev makes the contract pausable
  function togglePause() external onlyOwner {
    if (paused()) {
      _unpause();
    } else {
      _pause();
    }
  }

  /// @notice allows the users to withdraw their deposited funds and earnings from the offchain system
  /// @dev the receiver is provided as a variable to allow withdrawing to the burn address and such
  /// @param amount wei amount of list tokens to be withdrawn
  /// @param nonce nonce of the withdrawal, to prevent double withdrawals
  /// @param receiver the address to receive the funds
  /// @param signature owner signature validating the withdrawal
  function withdrawFor(
    uint256 amount,
    uint256 nonce,
    address receiver,
    bytes calldata signature
  ) external whenNotPaused nonReentrant {
    require(verify(owner(), receiver, amount, nonce, signature), "Invalid signature");

    // Current nonce has to match this one to avoid double withdrawals
    require(nonceMap[receiver] == nonce, "Invalid nonce");

    nonceMap[receiver]++;
    withdrawn[receiver] += amount;

    emit Withdrawn(_msgSender(), amount);

    list.transfer(receiver, amount);
  }

  /// @notice a simple deposit function for getting funds detected by the offchain system
  /// @param amount wei amount of list tokens to be deposited
  function deposit(uint256 amount) external whenNotPaused {
    list.transferFrom(_msgSender(), address(this), amount);

    emit Deposited(_msgSender(), amount);
  }

  /// @notice called by the lister when proposing a vote
  /// @dev  main use is to assign a vote id on chain and take funds, rewards processing is done offchain (rewards are withdrawn with withdrawFor or kept in the system)
  /// @param rewardAmount wei amount of the lister reward
  function proposeVote(uint256 rewardAmount) external whenNotPaused {
    uint256 voteId = _voteCounter;

    list.transferFrom(_msgSender(), address(this), rewardAmount);

    _voteCounter++;
    emit VoteProposed(voteId, rewardAmount);
  }

  /// @notice links a vote id to an ipfs hash (at which all the vote data is) permanently
  /// @dev  this provides the immutability of the offchain voting system, since IPFS hashes are CIDs, and thus guarantee the validity of the data
  /// @param id id of the vote generated during proposeVote
  /// @param ipfs ipfs hash at which the vote data is
  function resolveVote(uint256 id, string memory ipfs) external onlyOwner {
    require(keccak256(bytes(_voteResolutionHash[id])) == keccak256(bytes("")), "alreadyResolved");
    _voteResolutionHash[id] = ipfs;

    emit VoteResolved(id, ipfs);
  }

  /// @notice view for inspecting the ipfs hash by vote id
  /// @param id id of the vote generated during proposeVote
  /// @return ipfs hash at which the vote data is
  function getVoteState(uint256 id) external view returns (string memory ipfs) {
    return _voteResolutionHash[id];
  }
}
