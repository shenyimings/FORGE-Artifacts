// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Kapital DAO Transactor
 * @author Playground Labs
 * @custom:security-contact security@playgroundlabs.io
 * @notice A base contract for storing and performing arbitrary actions with
 * funds owned by either the Kapital DAO governance or the Kaptial DAO core
 * team multisig. {_transact} is used by creating an external `transact` in
 * implementation contracts, together with appropriate access control.
 */
contract Transactor {
    /**
     * @dev Used to perform arbitrary actions with funds held by the contract
     * @param targets addresses to call
     * @param values values of the associated function calls
     * @param data calldata to pass into function calls
     */
    function _transact(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory data
    ) internal {
        uint256 targetsLength = targets.length;
        require(targetsLength > 0, "Invalid array length");
        require(targetsLength == values.length, "Array length mismatch");
        require(targetsLength == data.length, "Array length mismatch");

        for (uint256 i = 0; i < targetsLength; ++i) {
            if (data[i].length != 0) {
                Address.functionCallWithValue(targets[i], data[i], values[i]);
            } else {
                Address.sendValue(payable(targets[i]), values[i]); // can be used to send ETH to EOA
            }
        }
    }

    /**
     * @dev allow the contract to receive ether (as one of the many possible
     * types of tokens which can be held by the contract)
     */
    receive() external payable {}
}
