// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../../utils/PairingAndProof.sol";
import "./medicalSpecialty.verifier.sol";
import "../../IRootsMinimal.sol";
import "../PaidProof.sol";


contract MedicalSpecialty is PaidProof {
    
    mapping(address => uint256) public specialtyMapping; // e.g., 0x123... => <specialty-represented-as-int>
    mapping(uint256 => bool) public hashbrownsWasUsed;

    MedicalSpecialtyVerifier verifier; 
    IRootsMinimal roots;

    event UserHasMedicalSpecialty(address userAddr, uint256 specialty);

    constructor(address roots_, uint[] memory issuers_, uint price_) {
        roots = IRootsMinimal(roots_);
        verifier = new MedicalSpecialtyVerifier();
        allowIssuers(issuers_);
        setPrice(price_);
    }

    function specialty(address person) public view returns (uint256) {
        return specialtyMapping[person];
    }
    /// @dev It is useful to separate this from the prove() function which is changes state, so that somebody can call this off-chain as a view function.
    /// @dev Then, they can maintain their own off-chain list of hashbrowns and verified address.
    /// @dev Proof of medical specialty is equivalent to a proof of MD or DO because users cannot get credentials that include medical specialty unless
    /// @dev they are actually a doctor. Although we do not verify the specialty here, it is a public input so that it can be checked off-chain.
    function proofIsValid(Proof calldata proof, uint[6] calldata input) public view returns (bool isValid) {
        require(roots.rootIsRecent(input[0]), "The root provided was not found in the Merkle tree's recent root list");
        require(isValidIssuer(input[2]), "Proof must come from correct issuer's address"); 
        require(input[4] == 320192098064396900878317978103229380372186908085604549333845693700248653086, "Hashbrowns is made from the wrong salt"); //poseidon("MedicalSpecialty")
        require(!hashbrownsWasUsed[input[5]], "One person can only verify once");
        // No need to make assertions about the specialty, other than that it is in a credential set issued by a valid issuer.
        // require(input[4] == <medical-specialty>, "Credentials do not include a medical specialty");
        require(verifier.verifyTx(proof, input), "Failed to verify proof");
        return true;
    }

    /// @param proof PairingAndProof.sol Proof struct
    /// @param input The public inputs to the proof, in ZoKrates' format
    function prove(Proof calldata proof, uint[6] calldata input) public {
        require(proofIsValid(proof, input));
        hashbrownsWasUsed[input[5]] = true;
        specialtyMapping[address(uint160(input[1]))] = input[4];
        emit UserHasMedicalSpecialty(msg.sender, input[4]);
    }

}
