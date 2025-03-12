// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @dev External interface of EIP712 declared to support ERC165 detection.
 * @author Origami
 */
interface IEIP712 {
    /**
     * @notice the user readable name of signing domain
     * @return name
     */
    function name() external view returns (string memory);
    /**
     * @notice the current major version of the signing domain.
     * @return semantic version.
     */
    function version() external pure returns (string memory);
    /**
     * @notice the EIP712 domain separator for this contract.
     * @return domain separator.
     */
    function domainSeparatorV4() external view returns (bytes32);
}
