// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interface/IDepositContract.sol";

/**
 * @title Aspida's StakingModel
 * @dev This contract manages the deposit of validators to the Ethereum 2.0 deposit contract.
 * @author Aspida engineer
 */
abstract contract StakingModel {
    uint256 internal constant DEPOSIT_SIZE = 32 ether;
    uint256 internal constant SIGNATURE_INDEX = 64;
    uint64 internal constant DEPOSIT_SIZE_IN_GWEI_LE64 = 0x0040597307000000;

    IDepositContract internal immutable DEPOSIT_CONTRACT; // Deposit contract is immutable

    bytes internal withdrawalCredentials_; // Withdrawal credentials are stored as bytes

    mapping(bytes => bool) internal pubKeyExpired_; // Mapping to check if a public key has expired

    /**
     * @dev Emitted when the withdrawal credentials are set.
     */
    event SetWithdrawalCredentials(bytes withdrawalCredential);

    /**
     * @dev Emitted when a validator is deposited.
     */
    event ValidatorDeposited(
        address operator,
        bytes pubKey,
        bytes signature,
        bytes withdrawalCredential,
        bytes32 depositDataRoot
    );

    /**
     * @dev Event emitted when a deposit is made.
     */
    event Deposit(uint256 depositValue, uint256 validatorCount);

    constructor(IDepositContract _depositContract) {
        DEPOSIT_CONTRACT = _depositContract;
    }

    /**
     * @dev Sets the withdrawal credentials.
     * @param _withdrawalCredentials The withdrawal credentials.
     */
    function _setWithdrawalCredentialsInternal(bytes memory _withdrawalCredentials) internal {
        require(
            _withdrawalCredentials.length == 32,
            "_setWithdrawalCredentialsInternal: Invalid withdrawalCredentials length"
        );

        withdrawalCredentials_ = _withdrawalCredentials;
        emit SetWithdrawalCredentials(_withdrawalCredentials);
    }

    struct Validator {
        address operator;
        bytes pubKey;
        bytes signature;
    }

    /**
     * @dev Deposits validators.
     * @param _validators The validators to deposit.
     */
    function _deposit(Validator[] calldata _validators) internal {
        require(_validators.length > 0, "_deposit: Deposit 0 is invalid");
        bytes memory _withdrawalCredentials = withdrawalCredentials_;
        for (uint256 i = 0; i < _validators.length; i++) {
            require(!pubKeyExpired_[_validators[i].pubKey], "_deposit: Invalid validator public key");

            bytes32 _depositDataRoot = _calculateDepositDataRoot(
                _validators[i].pubKey,
                _validators[i].signature,
                _withdrawalCredentials
            );
            DEPOSIT_CONTRACT.deposit{ value: DEPOSIT_SIZE }(
                _validators[i].pubKey,
                _withdrawalCredentials,
                _validators[i].signature,
                _depositDataRoot
            );

            pubKeyExpired_[_validators[i].pubKey] = true;
            emit ValidatorDeposited(
                _validators[i].operator,
                _validators[i].pubKey,
                _validators[i].signature,
                _withdrawalCredentials,
                _depositDataRoot
            );
        }
        emit Deposit(_validators.length * DEPOSIT_SIZE, _validators.length);
    }

    /**
     * @dev Slices a portion of a bytes array.
     * @param _src The source bytes array.
     * @param _srcStart The starting index of the slice.
     * @param _length The length of the slice.
     * @return _dst The sliced bytes array.
     */
    function _bytesSlice(
        bytes memory _src,
        uint256 _srcStart,
        uint256 _length
    ) internal pure returns (bytes memory _dst) {
        require(_srcStart + _length <= _src.length, "_bytesSlice: Slice param error");
        _dst = new bytes(_length);
        for (uint256 i = 0; i < _length; i++) {
            _dst[i] = _src[i + _srcStart];
        }
    }

    /**
     * @dev Calculates the deposit data root.
     * @param _pubKey The public key.
     * @param _signature The signature.
     * @param _withdrawalCredentials The withdrawal credentials.
     * @return _depositDataRoot The deposit data root.
     */
    function _calculateDepositDataRoot(
        bytes memory _pubKey,
        bytes memory _signature,
        bytes memory _withdrawalCredentials
    ) internal pure returns (bytes32 _depositDataRoot) {
        bytes32 _pubkeyRoot = sha256(abi.encodePacked(_pubKey, bytes16(0)));
        bytes32 _signatureRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(_bytesSlice(_signature, 0, SIGNATURE_INDEX))),
                sha256(abi.encodePacked(_bytesSlice(_signature, SIGNATURE_INDEX, 32), bytes32(0)))
            )
        );

        _depositDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(_pubkeyRoot, _withdrawalCredentials)),
                sha256(abi.encodePacked(DEPOSIT_SIZE_IN_GWEI_LE64, bytes24(0), _signatureRoot))
            )
        );
    }

    /**
     * @dev Converts an address to withdrawal credentials.
     * @param _withdrawalAddress The withdrawal address.
     * @return The withdrawal credentials.
     */
    function _addressToWithdrawalCredentials(address _withdrawalAddress) internal pure returns (bytes memory) {
        return abi.encodePacked(uint256(uint160(_withdrawalAddress)) | (1 << 248));
    }

    /**
     * @dev Returns the deposit contract.
     * @return The deposit contract.
     */
    function depositContract() external view returns (IDepositContract) {
        return DEPOSIT_CONTRACT;
    }

    /**
     * @dev Returns the withdrawal credentials.
     * @return The withdrawal credentials.
     */
    function withdrawalCredentials() external view returns (bytes memory) {
        return withdrawalCredentials_;
    }

    /**
     * @dev Checks if a public key has expired.
     * @param _pubKey The public key.
     * @return True if the public key has expired, false otherwise.
     */
    function pubKeyExpired(bytes memory _pubKey) external view returns (bool) {
        return pubKeyExpired_[_pubKey];
    }
}
