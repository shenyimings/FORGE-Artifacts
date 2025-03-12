// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";

import "@solarity/solidity-lib/access-control/MultiOwnable.sol";

import "../interfaces/user/IUserRegistry.sol";

contract UserRegistry is IUserRegistry, EIP712Upgradeable, MultiOwnable {
    bytes32 public documentHash;

    mapping(bytes32 => mapping(address => bytes32)) internal _signatureHashes;
    mapping(address => string) internal _users;

    event UpdatedProfile(address user, string url);
    event Agreed(address user, bytes32 documentHash);
    event SetDocumentHash(bytes32 hash);

    function __UserRegistry_init(string calldata name) external initializer {
        __EIP712_init(name, "1");
        __MultiOwnable_init();
    }

    function changeProfile(string calldata url) public override {
        _users[msg.sender] = url;

        emit UpdatedProfile(msg.sender, url);
    }

    function agreeToPrivacyPolicy(bytes calldata signature) public override {
        bytes32 _documentHash = documentHash;

        require(_documentHash != 0, "UserRegistry: privacy policy is not set");

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(keccak256("Agreement(bytes32 documentHash)"), _documentHash))
        );

        require(
            ECDSAUpgradeable.recover(digest, signature) == msg.sender,
            "UserRegistry: invalid signature"
        );

        _signatureHashes[_documentHash][msg.sender] = keccak256(abi.encodePacked(signature));

        emit Agreed(msg.sender, _documentHash);
    }

    function changeProfileAndAgreeToPrivacyPolicy(
        string calldata url,
        bytes calldata signature
    ) external override {
        agreeToPrivacyPolicy(signature);
        changeProfile(url);
    }

    function agreed(address user) external view override returns (bool) {
        return _signatureHashes[documentHash][user] != 0;
    }

    function setPrivacyPolicyDocumentHash(bytes32 hash) external override onlyOwner {
        documentHash = hash;

        emit SetDocumentHash(hash);
    }

    function userInfos(address user) external view returns (UserInfo memory) {
        return
            UserInfo({
                profileURL: _users[user],
                signatureHash: _signatureHashes[documentHash][user]
            });
    }
}
