// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * This is the contract that stores user profile settings + his privacy policy agreement EIP712 signature
 */
interface IUserRegistry {
    /// @notice The structure that stores info about the user
    /// @param profileURL is an IPFS URL to the user's profile data
    /// @param signatureHash is a hash of a privacy policy signature
    struct UserInfo {
        string profileURL;
        bytes32 signatureHash;
    }

    /// @notice The function to change the user profile
    /// @param url the IPFS URL to the new profile settings
    function changeProfile(string calldata url) external;

    /// @notice The function to agree to the privacy policy of the DEXE platform.
    /// The user has to sign the hash of the privacy policy document
    /// @param signature the VRS packed parameters of the ECDSA signature
    function agreeToPrivacyPolicy(bytes calldata signature) external;

    /// @notice The function to change the profile and sign the privacy policy in a single transaction
    /// @param url the IPFS URL to the new profile settings
    /// @param signature the VRS packed parameters of the ECDSA signature
    function changeProfileAndAgreeToPrivacyPolicy(
        string calldata url,
        bytes calldata signature
    ) external;

    /// @notice The function to check whether the user signed the privacy policy
    /// @param user the user to check
    /// @return true is the user has signed to privacy policy, false otherwise
    function agreed(address user) external view returns (bool);

    /// @notice The function to set the hash of the document the user has to sign
    /// @param hash the has of the document the user has to sign
    function setPrivacyPolicyDocumentHash(bytes32 hash) external;
}
