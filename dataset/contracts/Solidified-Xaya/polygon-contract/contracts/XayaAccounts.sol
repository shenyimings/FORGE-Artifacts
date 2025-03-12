// SPDX-License-Identifier: MIT
// Copyright (C) 2021-2022 Autonomous Worlds Ltd

pragma solidity ^0.8.4;

import "./IXayaAccounts.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @dev The base contract of Xaya on an EVM chain.  This manages user
 * accounts (names) as NFTs, and handles moves sent by them.
 *
 * The contract itself is not upgradable, but it has an owner which is able
 * to modify the policy for name/move validation, fees and the NFT metadata
 * generation (but nothing else).
 */
contract XayaAccounts is ERC721Enumerable, Ownable, IXayaAccounts
{

  /* ************************************************************************ */

  /** @dev The address of the WCHI token used.  */
  IERC20 public override immutable wchiToken;

  /** @dev Time lock for policy changes.  */
  uint public constant policyTimelock = 1 weeks;

  /** @dev The address of the current policy contract.  */
  IXayaPolicy public override policy;

  /** @dev If the policy is being changed, the next policy.  */
  IXayaPolicy public nextPolicy;

  /**
   * @dev If the policy is being changed, the timestamp after which
   * nextPolicy can be enacted as current policy.  This is zero if there
   * is no current change going on.
   */
  uint public nextPolicyAfter;

  /** @dev Mapping of token IDs to the next nonce for that account.  */
  mapping (uint256 => uint256) public override nextNonce;

  /**
   * @dev A full account identifier with namespace and name, for use
   * in the token-id-to-account map.
   */
  struct NamespaceAndName
  {
    string ns;
    string name;
  }

  /** @dev For existing accounts, mapping of token ID to name.  */
  mapping (uint256 => NamespaceAndName) private tokenIdToAccount;

  /** @dev Emitted when a new policy change is scheduled.  */
  event PolicyChangeScheduled (IXayaPolicy newPolicy, uint validAfter);

  /** @dev Emitted when a policy change takes effect.  */
  event PolicyChanged (IXayaPolicy oldPolicy, IXayaPolicy newPolicy);

  /* ************************************************************************ */

  /**
   * @dev Constructs the token contract.  It accepts the (immutable) WCHI
   * token address as well as the (changable) initial policy as arguments.
   */
  constructor (IERC20 wchi, IXayaPolicy initialPolicy)
    ERC721 ("Xaya Name", "XAYA")
  {
    wchiToken = wchi;
    policy = initialPolicy;
    emit PolicyChanged (IXayaPolicy (address (0)), policy);

    /* nextPolicy and nextPolicyAfter start off as zero, which means that
       there is no policy change scheduled.  */
  }

  /**
   * @dev For an existing account, return the namespace and name corresponding
   * to a token ID.
   */
  function tokenIdToName (uint256 tokenId)
      public view override returns (string memory, string memory)
  {
    NamespaceAndName memory res = tokenIdToAccount[tokenId];
    require (tokenId == tokenIdForName (res.ns, res.name),
             "no matching account found for token");
    return (res.ns, res.name);
  }

  /**
   * @dev Computes the token ID deterministically (as hash) from
   * the namespace/name combination.
   */
  function tokenIdForName (string memory ns, string memory name)
      public pure override returns (uint256)
  {
    return uint256 (keccak256 (abi.encodePacked (ns, name)));
  }

  /**
   * @dev Returns true if the given namespace/name combination exists.
   */
  function exists (string memory ns, string memory name)
      public view override returns (bool)
  {
    return exists (tokenIdForName (ns, name));
  }

  /**
   * @dev Returns true if the given token ID exists.
   */
  function exists (uint256 tokenId) public view override returns (bool)
  {
    return _exists (tokenId);
  }

  /**
   * @dev Returns a constructed metadata URI for the NFT.  This is based
   * on the NFT's associated namespace and name.
   */
  function tokenURI (uint256 tokenId)
      public view override returns (string memory)
  {
    (string memory ns, string memory name) = tokenIdToName (tokenId);
    return policy.tokenUriForName (ns, name);
  }

  /**
   * @dev Returns a link to the contract-level metadata used by OpenSea.
   */
  function contractURI () public view returns (string memory)
  {
    return policy.contractUri ();
  }

  /**
   * @dev Schedules an update to the policy implementation.
   */
  function schedulePolicyChange (IXayaPolicy newPolicy) public onlyOwner
  {
    require (newPolicy != IXayaPolicy (address (0)),
             "invalid policy scheduled");

    nextPolicy = newPolicy;
    nextPolicyAfter = block.timestamp + policyTimelock;
    emit PolicyChangeScheduled (nextPolicy, nextPolicyAfter);
  }

  /**
   * @dev Enacts a policy change after the timelock is over.  This function
   * can be called by anyone, not only the owner.
   */
  function enactPolicyChange () public
  {
    require (nextPolicyAfter != 0, "no policy change is scheduled");
    require (block.timestamp >= nextPolicyAfter,
             "policy timelock is not expired yet");

    emit PolicyChanged (policy, nextPolicy);
    policy = nextPolicy;
    nextPolicy = IXayaPolicy (address (0));
    nextPolicyAfter = 0;
  }

  /* ************************************************************************ */

  /* The following two methods are the main interface for this contract
     (registration of names and moves).  They are marked as virtual just so
     we have the ability to override them in subcontracts for specific
     use-cases, e.g. for instrumentation with state overlays.  There are no
     direct plans to override those methods (or even set up derived contracts)
     for production deployment.  */

  /**
   * @dev Registers a new name.  The newly minted account NFT will be owned
   * by the caller.  Returns the token ID of the new account.
   */
  function register (string memory ns, string memory name)
      public virtual override returns (uint256)
  {
    uint256 tokenId = tokenIdForName (ns, name);

    uint256 fee = policy.checkRegistration (ns, name);
    if (fee > 0)
      require (wchiToken.transferFrom (msg.sender, policy.feeReceiver (), fee),
               "failed to transfer registration fee");

    _safeMint (msg.sender, tokenId);

    NamespaceAndName storage entry = tokenIdToAccount[tokenId];
    entry.ns = ns;
    entry.name = name;

    emit Registration (ns, name, tokenId, msg.sender);

    return tokenId;
  }

  /**
   * @dev Sends a move with a given name, optionally attaching a WCHI payment
   * to the given receiver.  For no payment, amount and receiver should be
   * set to zero.
   *
   * If a nonce other than uint256.max is passed, then the move is valid
   * only if it matches exactly the account's next nonce.  The nonce used
   * is returned.
   */
  function move (string memory ns, string memory name, string memory mv,
                 uint256 nonce, uint256 amount, address receiver)
      public virtual override returns (uint256)
  {
    uint256 tokenId = tokenIdForName (ns, name);
    require (_isApprovedOrOwner (msg.sender, tokenId),
             "not allowed to send a move for this account");

    uint256 currentNonce = nextNonce[tokenId];
    if (nonce != type (uint256).max)
      require (nonce == currentNonce, "nonce mismatch");

    uint256 fee = policy.checkMove (ns, mv);
    if (fee > 0)
      require (wchiToken.transferFrom (msg.sender, policy.feeReceiver (), fee),
               "failed to transfer move fee");

    if (receiver == address (0))
      require (amount == 0, "non-zero amount for zero receiver");
    else
      {
        /* Payment is done from the sending account, not from the owner of
           the NFT.  This gives delegation contracts more flexibility, e.g.
           paying on behalf of the user for certain types of free-to-play,
           or exchanging tokens to WCHI on the fly before paying.  They need
           to make sure they secure the necessary payment from the user
           on their own end.  */
        require (wchiToken.transferFrom (msg.sender, receiver, amount),
                 "failed to execute payment with move");
      }

    emit Move (ns, name, mv, tokenId, currentNonce,
               msg.sender, amount, receiver);

    nextNonce[tokenId] = currentNonce + 1;

    return currentNonce;
  }

  /**
   * @dev Returns the message that needs to be signed for permitOperator.
   */
  function permitOperatorMessage (address operator)
      public view override returns (bytes memory)
  {
    return abi.encodePacked (
        "I permit ",
        Strings.toHexString (uint160 (operator), 20),
        " to manage all my Xaya names.\n\nContract: ",
        Strings.toHexString (uint160 (address (this)), 20),
        "\nChain: ", Strings.toString (block.chainid));
  }

  /**
   * @dev Gives operator approval to manage all names (tokens) owned by
   * the signer of the permit message.  This method can be called by anyone,
   * so it can be used for native meta transactions.  Returns the signer
   * address extracted from the signature.
   */
  function permitOperator (address operator, bytes memory signature)
      public override returns (address)
  {
    bytes memory messageToSign = permitOperatorMessage (operator);
    bytes32 hashToSign = ECDSA.toEthSignedMessageHash (messageToSign);
    address signer = ECDSA.recover (hashToSign, signature);

    _setApprovalForAll (signer, operator, true);
    return signer;
  }

  /* ************************************************************************ */

}
