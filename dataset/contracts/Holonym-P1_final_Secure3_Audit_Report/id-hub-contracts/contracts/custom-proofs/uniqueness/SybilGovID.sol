// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../../utils/PairingAndProof.sol";
import "./sybilGovID.verifier.sol";
import "../../IRootsMinimal.sol";
import "../PaidProof.sol";
import "./ISybilResistance.sol";

contract SybilGovID is PaidProof {
    // Stores all used footprints
    mapping(uint256 => bool) public masalaWasUsed;
    // When *address* verifies they're unique for *actionId*, keccak256(address, actionId) will be stored as true:
    mapping(bytes32 => bool) verifications;
    // And an event will be emitted:
    event Uniqueness(address userAddr, uint actionId);

    SybilGovIDVerifier verifier; 
    IRootsMinimal roots;

    // allow for backwards compatability by also accepting users who verified in the old contract
    bool legacySupport;
    ISybilResistance oldContract; 
    
    constructor(address roots_, uint[] memory issuers_, uint price_, address oldContract_) {
        roots = IRootsMinimal(roots_);
        verifier = new SybilGovIDVerifier();
        allowIssuers(issuers_);
        setPrice(price_);

        if(oldContract_ != address(0)) {
            legacySupport = true;
            oldContract = ISybilResistance(oldContract_);
        }
    }

    function isUniqueForAction(address addr, uint actionId) public view returns (bool unique) {
        return (
            verifications[keccak256(abi.encodePacked(addr, actionId))]) || 
            (legacySupport && oldContract.isUniqueForAction(addr, actionId)
        );
    }

    // It is useful to separate this from the prove() function which is changes state, so that somebody can call this off-chain as a view function.
    // Then, they can maintain their own off-chain list of footprints and verified address 
    function proofIsValid(Proof calldata proof, uint[5] memory input) public view returns (bool isValid) {
        require(roots.rootIsRecent(input[0]), "The root provided was not found in the Merkle tree's recent root list");
        // Checking msg.sender no longer seems very necessary and prevents signature-free interactions. Without it, relayers can submit cross-chain transactions without the user signature. Thus, we are deprecating this check:
        // require(uint256(uint160(msg.sender)) == input[1], "Second public argument of proof must be your address");

        require(isValidIssuer(input[2]), "Proof must come from correct issuer's address"); 
        require(!masalaWasUsed[input[4]], "One person can only verify once");
        require(verifier.verifyTx(proof, input), "Failed to verify ZKP");
        return true;
    }

    /// @param proof PairingAndProof.sol Proof struct
    /// @param input The public inputs to the proof, in ZoKrates' format
    function prove(Proof calldata proof, uint256[5] calldata input) public payable needsPayment {
        require(proofIsValid(proof, input));
        masalaWasUsed[input[4]] = true; //input[4] is address
        bytes32 commit = keccak256(abi.encodePacked(uint160(input[1]), input[3])); //input[1] is address of user to be registered for actionId, input[3] is actionId
        verifications[commit] = true;
        emit Uniqueness(msg.sender, input[3]);
    }
}
