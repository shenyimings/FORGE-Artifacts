//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

/**
 * @author Polytrade
 * @title IVerification
 */
interface IVerification {
    struct UserStatus {
        bytes2 provider;
        bool status;
    }

    /**
     * @notice Emits when a agent is set (added, removed)
     * @param agent, address of the agent to be added or removed
     * @param status, true if added or false if removed
     */
    event AgentSet(address agent, bool status);

    /**
     * @notice Emits when a user is validated or removed
     * @param user, address of the user to be validated or removed
     * @param provider, code of the provider (bytes2)
     * @param status, true if added or false if removed
     */
    event UserValidation(address user, bytes2 provider, bool status);

    /**
     * @notice Emits when new kyc Limit is set
     * @dev Emitted when new kycLimit is set by the owner
     * @param kycLimit, new value of kycLimit
     */
    event ValidationLimitUpdated(uint kycLimit);

    /**
     * @notice Updates the limit for the Validation to be required
     * @dev updates validationLimit variable
     * @param validationLimit, new value of depositLimit
     *
     * Emits {ValidationLimitUpdated} event
     */
    function updateValidationLimit(uint validationLimit) external;

    /**
     * @notice Returns whether a user's KYC is verified or not
     * @dev returns a boolean if the KYC is valid
     * @param user, address of the user to check
     * @return returns true if user's KYC is valid or false if not
     */
    function isValid(address user) external view returns (bool);

    /**
     * @notice Returns whether a validation is required or not based on deposit
     * @dev returns a boolean if the KYC is required or not
     * @param user, address of the user to check
     * @param amount, amount to be added
     * @return returns a boolean if the amount requires a Validation or not
     */
    function isValidationRequired(address user, uint amount)
        external
        view
        returns (bool);
}
