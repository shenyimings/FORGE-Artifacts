//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './IRewardToken.sol';

contract TEAK is ERC20, IRewardToken {
  // There are 3 admins, each a gnosis multisig wallet
  address[] private _adminsArray;
  mapping(address => bool) private _admins;
  // Minters are be contracts that can mint for staking $KANGAL and LPs
  mapping(address => bool) private _minters;
  // (proposedMinterAddress => adminCreatingProposal)
  mapping(address => address) private _proposedMintersToAdd;
  // (proposedMinterAddress => adminCreatingProposal)
  mapping(address => address) private _proposedMintersToRemove;
  // 2 or more admins need to give consent
  mapping(address => bool) private _mintingConsensusVotes;
  uint256 private _mintingConsensusThreshold = 2;
  bool private _mintingConsensusReached = false;

  // Initializes the contract with the gnosis multisig admins.
  // This checks for unique admin addresses.
  constructor(
    address adminOne,
    address adminTwo,
    address adminThree
  ) ERC20('$teak', '$TEAK') {
    require(adminOne != adminTwo && adminOne != adminThree && adminTwo != adminThree, 'ADMINS_SHOULD_BE_UNIQUE');
    _adminsArray.push(adminOne);
    _adminsArray.push(adminTwo);
    _adminsArray.push(adminThree);
    _admins[adminOne] = true;
    _admins[adminTwo] = true;
    _admins[adminThree] = true;
  }

  modifier onlyAdmin() {
    require(_admins[msg.sender], 'DOES_NOT_HAVE_ADMIN_ROLE');
    _;
  }

  modifier onlyMinter() {
    require(_minters[msg.sender], 'DOES_NOT_HAVE_MINTER_ROLE');
    _;
  }

  // Function for admins to give minting consent.
  function giveMintingConsent() external override onlyAdmin {
    _mintingConsensusVotes[msg.sender] = true;
    updateConsensusState();
  }

  // Function for admins to remove minting consent.
  function removeMintingConsent() external override onlyAdmin {
    _mintingConsensusVotes[msg.sender] = false;
    updateConsensusState();
  }

  // Calculates and updates the minting consent state after an admin calls giveMintingConsent or removeMintingConsent.
  function updateConsensusState() private {
    uint256 votes;
    for (uint256 i = 0; i < _adminsArray.length; i++) {
      address adminAddress = _adminsArray[i];
      if (_mintingConsensusVotes[adminAddress]) {
        votes += 1;
      }
    }
    _mintingConsensusReached = votes >= _mintingConsensusThreshold;
  }

  // Function for admins to propose a new minter
  function proposeMinter(address proposedMinterAddress) external override onlyAdmin {
    require(_minters[proposedMinterAddress] == false, 'ADDRESS_ALREADY_MINTER');
    require(_proposedMintersToAdd[proposedMinterAddress] == address(0), 'ADDRESS_ALREADY_BEEN_PROPOSED');

    _proposedMintersToAdd[proposedMinterAddress] = msg.sender;
  }

  // Function for admins to approve a proposed minter.
  // The proposal creator cannot approve since they approve with the proposition creation.
  // 2/3 consensus is required.
  function approveProposedMinter(address proposedMinterAddress) external override onlyAdmin {
    require(_proposedMintersToAdd[proposedMinterAddress] != address(0), 'NO_PROPOSITION_TO_APPROVE');
    require(_proposedMintersToAdd[proposedMinterAddress] != msg.sender, 'CANNOT_APPROVE_SELF_PROPOSITION');

    _proposedMintersToAdd[proposedMinterAddress] = address(0);
    _minters[proposedMinterAddress] = true;
  }

  // Function for admins to propose to remove a minter
  function proposeMinterRemoval(address minterAddress) external override onlyAdmin {
    require(_minters[minterAddress], 'ADDRESS_MUST_BE_MINTER');
    require(_proposedMintersToRemove[minterAddress] == address(0), 'ADDRESS_ALREADY_BEEN_PROPOSED_FOR_REMOVAL');

    _proposedMintersToRemove[minterAddress] = msg.sender;
  }

  // Function for admins to approve minter removal proposal.
  // The proposal creator cannot approve since they approve with the proposition creation.
  // 2/3 consensus is required.
  function approveMinterRemoval(address minterAddress) external override onlyAdmin {
    require(_minters[minterAddress], 'ADDRESS_MUST_BE_A_MINTER');
    require(_proposedMintersToRemove[minterAddress] != address(0), 'NO_PROPOSITION_TO_APPROVE');
    require(_proposedMintersToRemove[minterAddress] != msg.sender, 'CANNOT_APPROVE_SELF_PROPOSITION');

    _proposedMintersToRemove[minterAddress] = address(0);
    _minters[minterAddress] = false;
  }

  // Function for minters to mint new tokens.
  function mint(address to, uint256 amount) external override onlyMinter {
    require(_mintingConsensusReached, 'MINTING_CONTENSUS_NOT_REACHED');

    _mint(to, amount);
  }
}
