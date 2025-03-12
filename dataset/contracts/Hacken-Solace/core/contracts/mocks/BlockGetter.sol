// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.6;


/**
 * @title BlockGetter
 * @author solace.fi
 * @notice Used to get information about the chain. Useful in situations where chain manipulation results in the wrong results being returned.
 */
contract BlockGetter {

    /**
     * @notice Returns the elevation of the latest block in the chain.
     * @return num The block number.
     */
    function getBlockNumber() external view returns (uint256 num) {
        return block.number;
    }

    /**
     * @notice Returns the timestamp of the latest block in the chain.
     * @return timestamp The block timestamp.
     */
    function getBlockTimestamp() external view returns (uint256 timestamp) {
        return block.timestamp;
    }
}
