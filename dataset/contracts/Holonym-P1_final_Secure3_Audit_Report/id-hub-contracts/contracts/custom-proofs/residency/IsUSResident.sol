// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../../utils/PairingAndProof.sol";
import "./proofOfResidency.verifier.sol";
import "../../IRootsMinimal.sol";
import "../PaidProof.sol";
import "./IIsUSResident.sol";


contract IsUSResident is PaidProof {
    
    mapping(address => bool) public usResidencyMapping; // e.g., 0x123... => true
    mapping(uint256 => bool) public masalaWasUsed;

    ProofOfCountry verifier; 
    IRootsMinimal roots;
    event USResidency(address userAddr, bool usResidency);

    // allow for backwards compatability by also accepting users who verified in the old contract
    bool legacySupport;
    IIsUSResident oldContract; 

    constructor(address roots_, uint[] memory issuers_, uint price_, address oldContract_) {
        roots = IRootsMinimal(roots_);
        verifier = new ProofOfCountry();
        allowIssuers(issuers_);
        setPrice(price_);
        
        if(oldContract_ != address(0)) {
            legacySupport = true;
            oldContract = IIsUSResident(oldContract_);
        }
    }

    function usResidency(address person) public view returns (bool) {
        return usResidencyMapping[person] || (legacySupport && oldContract.usResidency(person));
    }
    // It is useful to separate this from the prove() function which is changes state, so that somebody can call this off-chain as a view function.
    // Then, they can maintain their own off-chain list of footprints and verified address 
    function proofIsValid(Proof calldata proof, uint[6] calldata input) public view returns (bool isValid) {
        require(roots.rootIsRecent(input[0]), "The root provided was not found in the Merkle tree's recent root list");

        // Checking msg.sender no longer seems very necessary and prevents signature-free interactions. Without it, relayers can submit cross-chain transactions without the user signature. Thus, we are deprecating this check:
        // require(uint256(uint160(msg.sender)) == input[1], "Second public argument of proof must be your address");
        
        require(isValidIssuer(input[2]), "Proof must come from correct issuer's address"); 
        require(input[3] == 18450029681611047275023442534946896643130395402313725026917000686233641593164, "Footprint is made from the wrong salt"); //poseidon("IsFromUS")
        require(!masalaWasUsed[input[4]], "One person can only verify once");
        require(input[5] == 2, "Credentials do not have US as country code"); // 2 is prime that represents USA because USA is #2
        require(verifier.verifyTx(proof, input), "Failed to verify proof");
        return true;
    }

    /// @param proof PairingAndProof.sol Proof struct
    /// @param input The public inputs to the proof, in ZoKrates' format
    function prove(Proof calldata proof, uint[6] calldata input) public {
        require(proofIsValid(proof, input));
        masalaWasUsed[input[4]] = true;
        usResidencyMapping[address(uint160(input[1]))] = true; //
        emit USResidency(msg.sender, true);
    }

}
