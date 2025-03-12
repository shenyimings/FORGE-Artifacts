// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";

    error InvalidSigner();
    error InvalidProof();
    error InvalidApproval();
    error ExpiredTimestamp();

contract Store is Pausable {
    address public adminSigner;
    address public storeReceiver;
    address public paymentTokenAddress;

    event TransactionProcessed(address indexed buyer, uint256 amountSend, uint256 amountReceived, bytes32 merkleRoot, string id);

    struct ValidationData {
        string expiringTime;
        bytes32[] expiringProof;
        string offer;
        bytes32[] offerProof;
        bytes32 merkleRoot;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    constructor(
        address _admin,
        address _storeReceiver,
        address _paymentTokenAddress
    ) {
        adminSigner = _admin;
        storeReceiver = _storeReceiver;
        paymentTokenAddress = _paymentTokenAddress;
    }

    modifier onlyAdminSigner() {
        require(msg.sender == adminSigner, "Only the admin signer can call this function");
        _;
    }

    function updateAdminSigner(address newAdminSigner) external onlyAdminSigner {
        require(newAdminSigner != address(0), "New admin signer cannot be the zero address");
        adminSigner = newAdminSigner;
    }

    function pause() public onlyAdminSigner {
        _pause();
    }

    function unpause() public onlyAdminSigner {
        _unpause();
    }

    function stringToUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint i = 0; i < b.length; i++) {
            uint8 temp = uint8(b[i]) - 48; // convert char to uint
            result = result * 10 + temp;
        }
        return result;
    }

    function _split(string memory str) public pure returns (string memory, string memory) {
        bytes memory strBytes = bytes(str);
        uint index = 0;
        for (uint i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == '|') {
                index = i;
                break;
            }
        }

        require(index != 0, "Separator not found");

        bytes memory str1 = new bytes(index);
        for (uint i = 0; i < index; i++) {
            str1[i] = strBytes[i];
        }

        bytes memory str2 = new bytes(strBytes.length - index - 1);
        for (uint i = 0; i < str2.length; i++) {
            str2[i] = strBytes[index + 1 + i];
        }

        return (string(str1), string(str2));
    }

    function checkSig(
        address signer,
        bytes32 hash,
        Signature calldata sig
    ) public pure returns (bool isValid) {
        address recover = ecrecover(hash, sig.v, sig.r, sig.s);
        isValid = recover == signer;
    }

    function verifyMerkle(
        string calldata offer,
        bytes32[] calldata proof,
        bytes32 merkleRoot
    ) public pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(offer));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    // Only used for testing !
    function checkExpiringTime(
        string calldata expiringTime,
        bytes32[] calldata expiringProof,
        bytes32 merkleRoot
    ) public view returns (bool) {
        if (!verifyMerkle(expiringTime, expiringProof, merkleRoot)) {
            revert InvalidProof();
        }
        bytes memory timeBytes = bytes(expiringTime);
        uint256 startIndex = 7; // 'expire:' has 7 characters
        uint256 endIndex = timeBytes.length;
        uint256 expiryTimestamp = 0;
        // Convert bytes to uint
        for (uint256 i = startIndex; i < endIndex; i++) {
            expiryTimestamp =
                expiryTimestamp *
                10 +
                uint256(uint8(timeBytes[i])) -
                48;
        }
        if (block.timestamp >= expiryTimestamp) {
            revert ExpiredTimestamp();
        }
        return true;
    }

    function validateMerkleValues(
        ValidationData calldata data
    ) public view returns (bool) {
        if (!verifyMerkle(data.expiringTime, data.expiringProof, data.merkleRoot)) {
            revert InvalidProof();
        }
        if (!verifyMerkle(data.offer, data.offerProof, data.merkleRoot)) {
            revert InvalidProof();
        }
        bytes memory timeBytes = bytes(data.expiringTime);
        uint256 startIndex = 7;
        uint256 endIndex = timeBytes.length;
        uint256 expiryTimestamp = 0;
        for (uint256 i = startIndex; i < endIndex; i++) {
            expiryTimestamp =
                expiryTimestamp *
                10 +
                uint256(uint8(timeBytes[i])) -
                48;
        }
        if (block.timestamp >= expiryTimestamp) {
            revert ExpiredTimestamp();
        }
        return true;
    }

    function proceedToBuy(
        string calldata id,
        ValidationData calldata data,
        Signature calldata sig
    ) public whenNotPaused {
        IERC20 paymentToken = IERC20(paymentTokenAddress);
        (string memory offerSend, string memory offerReceive) = _split(data.offer);

        uint256 offerSendInt = stringToUint(offerSend);
        uint256 offerReceivedInt = stringToUint(offerReceive);

        require(paymentToken.allowance(msg.sender, address(this)) >= offerSendInt, "Invalid approval");
        require(checkSig(adminSigner, data.merkleRoot, sig), "Invalid signer");

        validateMerkleValues(
            data
        );

        paymentToken.transferFrom(
            msg.sender,
            address(storeReceiver),
            offerSendInt
        );

        emit TransactionProcessed(msg.sender, offerSendInt, offerReceivedInt, data.merkleRoot, id);
    }
}
