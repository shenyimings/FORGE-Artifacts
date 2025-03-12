// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./utils/Owned.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IRewardEscrow.sol";
import "./interfaces/IMerkleDistributor.sol";
import {ICrossDomainMessenger} from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

/// @title Kwenta MerkleDistributor
/// @author JaredBorders
/// @notice Facilitates $KWENTA distribution via Merkle Proof verification
contract MerkleDistributor is IMerkleDistributor, Owned {
    /// @notice escrow for tokens claimed
    address public immutable override rewardEscrow;

    /// @notice token to be distributed (KWENTA)
    address public immutable override token;

    /// @notice contract that initiates claim from L1 (called by address attempting to claim)
    /// @dev can only be set by owner
    address public override controlL2MerkleDistributor;

    /// @notice the merkle root of the merkle tree containing account balances available to claim
    bytes32 public immutable override merkleRoot;

    /// @notice communication between L1 and L2 is enabled by two special
    /// smart contracts called the "messengers" and below is the
    /// address for the messenger on L2
    address private constant crossDomainMessengerAddr =
        0x4200000000000000000000000000000000000007;

    /// @notice this is a packed array of booleans
    mapping(uint256 => uint256) private claimedBitMap;

    /// @notice set addresses for deployed rewardEscrow and KWENTA.
    /// Establish merkle root for verification
    /// @param _owner: designated owner of this contract
    /// @param _token: address of erc20 token to be distributed
    /// @param _rewardEscrow: address of kwenta escrow for tokens claimed
    /// @param _merkleRoot: used for claim verification
    constructor(
        address _owner,
        address _token,
        address _rewardEscrow,
        bytes32 _merkleRoot
    ) Owned(_owner) {
        token = _token;
        rewardEscrow = _rewardEscrow;
        merkleRoot = _merkleRoot;
    }

    /// @notice owner can set address of ControlL2MerkleDistributor
    /// @dev this function must be called after (1) this contract has been deployed and
    /// (2) ControlL2MerkleDistributor has been deployed (which requires this contract's
    /// deployment address as input in the constructor)
    /// @param _controlL2MerkleDistributor: address of contract that initiates claim from L1
    function setControlL2MerkleDistributor(address _controlL2MerkleDistributor)
        external
        override
        onlyOwner
    {
        controlL2MerkleDistributor = _controlL2MerkleDistributor;
    }

    /// @notice determine if indexed claim has been claimed
    /// @param index: used for claim managment
    /// @return true if indexed claim has been claimed
    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    /// @notice set claimed status for indexed claim to true
    /// @param index: used for claim managment
    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] =
            claimedBitMap[claimedWordIndex] |
            (1 << claimedBitIndex);
    }

    /// @notice attempt to claim as `account` and escrow KWENTA for `account`
    /// @param index: used for merkle tree managment and verification
    /// @param account: address used for escrow entry
    /// @param amount: $KWENTA amount to be escrowed
    /// @param merkleProof: off-chain generated proof of merkle tree inclusion
    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external override {
        require(!isClaimed(index), "MerkleDistributor: Drop already claimed.");

        // verify the merkle proof
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "MerkleDistributor: Invalid proof."
        );

        // mark it claimed and send the token to RewardEscrow
        _setClaimed(index);
        IERC20(token).approve(rewardEscrow, amount);
        IRewardEscrow(rewardEscrow).createEscrowEntry(
            account,
            amount,
            52 weeks
        );

        emit Claimed(index, account, amount);
    }

    /// @notice attempt to claim as `account` and escrow KWENTA for `destAccount`
    /// @param index: used for merkle tree managment and verification
    /// @param account: address that initiated claim and designated `destAccount`
    /// @param destAccount: address used for escrow entry
    /// @param amount: $KWENTA amount to be escrowed
    /// @param merkleProof: off-chain generated proof of merkle tree inclusion
    function claimToAddress(
        uint256 index,
        address account,
        address destAccount,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external override {
        require(!isClaimed(index), "MerkleDistributor: Drop already claimed.");

        /// @notice function caller must be L2 Cross Domain Messenger
        require(
            msg.sender == crossDomainMessengerAddr,
            "MerkleDistributor: Only the OVM-ICrossDomainMessenger can call this function"
        );

        /// @notice if controlL2MerkleDistributor has NOT been set, function will revert
        require(
            controlL2MerkleDistributor != address(0),
            "MerkleDistributor: controlL2MerkleDistributor has not been set by owner"
        );

        /// @notice L1 contract which called L1 Cross Domain Messenger
        /// must be controlL2MerkleDistributor
        require(
            controlL2MerkleDistributor ==
                ICrossDomainMessenger(crossDomainMessengerAddr)
                    .xDomainMessageSender(),
            "MerkleDistributor: xDomainMessageSender must be controlL2MerkleDistributor"
        );

        // verify the merkle proof with the L1 `account` address
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "MerkleDistributor: Invalid proof."
        );

        // mark it claimed and send the token to RewardEscrow
        _setClaimed(index);
        IERC20(token).approve(rewardEscrow, amount);

        // @notice `destAccount` is used for escrow, NOT `account`
        IRewardEscrow(rewardEscrow).createEscrowEntry(
            destAccount,
            amount,
            52 weeks
        );

        emit Claimed(index, account, amount);
    }
}
