// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.23;

import "../PriceLinear.sol";
import "./CloneFactory.sol";

/**
 * @title PriceLinearCloneFactory
 * @author malteish
 * @notice Create clones of a PriceLinear contract with deterministic addresses
 */
contract PriceLinearCloneFactory is CloneFactory {
    constructor(address _implementation) CloneFactory(_implementation) {}

    /**
     * Create a clone
     * @param _rawSalt this value influences the address of the clone, but not the initialization
     * @param _trustedForwarder the trusted forwarder (ERC2771) can not be changed, but is checked for security
     * @param _owner address that will own the new clone
     * @param _slopeEnumerator when slope is a/b, this value is a
     * @param _slopeDenominator when slope is a/b, this value is b
     * @param _startTimeOrBlockNumber when to start the price change
     * @param _stepDuration how often to change the price (in seconds or blocks)
     * @param _isBlockBased true = change based on block number, false = change based on timestamp
     * @param _isRising true = price only increases, false = price only decreases
     * @return address of the clone that was created
     */
    function createPriceLinearClone(
        bytes32 _rawSalt,
        address _trustedForwarder,
        address _owner,
        uint64 _slopeEnumerator,
        uint64 _slopeDenominator,
        uint64 _startTimeOrBlockNumber,
        uint32 _stepDuration,
        bool _isBlockBased,
        bool _isRising
    ) external returns (address) {
        bytes32 salt = _generateSalt(
            _rawSalt,
            _trustedForwarder,
            _owner,
            _slopeEnumerator,
            _slopeDenominator,
            _startTimeOrBlockNumber,
            _stepDuration,
            _isBlockBased,
            _isRising
        );
        address clone = Clones.cloneDeterministic(implementation, salt);
        PriceLinear clonePriceOracle = PriceLinear(clone);
        require(
            clonePriceOracle.isTrustedForwarder(_trustedForwarder),
            "PriceLinearCloneFactory: Unexpected trustedForwarder"
        );
        clonePriceOracle.initialize(
            _owner,
            _slopeEnumerator,
            _slopeDenominator,
            _startTimeOrBlockNumber,
            _stepDuration,
            _isBlockBased,
            _isRising
        );
        emit NewClone(clone);
        return clone;
    }

    /**
     * Return the address a clone would have if it was created with these parameters.
     * @param _rawSalt this value influences the address of the clone, but not the initialization
     * @param _trustedForwarder the trusted forwarder (ERC2771) can not be changed, but is checked for security
     * @param _owner address that will own the new clone
     * @param _slopeEnumerator when slope is a/b, this value is a
     * @param _slopeDenominator when slope is a/b, this value is b
     * @param _startTimeOrBlockNumber when to start the price change
     * @param _stepDuration how often to change the price (in seconds or blocks)
     * @param _isBlockBased true = change based on block number, false = change based on timestamp
     * @param _isRising true = price only increases, false = price only decreases
     * @return address of the clone that would be created with these parameters
     */
    function predictCloneAddress(
        bytes32 _rawSalt,
        address _trustedForwarder,
        address _owner,
        uint64 _slopeEnumerator,
        uint64 _slopeDenominator,
        uint64 _startTimeOrBlockNumber,
        uint32 _stepDuration,
        bool _isBlockBased,
        bool _isRising
    ) external view returns (address) {
        bytes32 salt = _generateSalt(
            _rawSalt,
            _trustedForwarder,
            _owner,
            _slopeEnumerator,
            _slopeDenominator,
            _startTimeOrBlockNumber,
            _stepDuration,
            _isBlockBased,
            _isRising
        );
        return Clones.predictDeterministicAddress(implementation, salt);
    }

    /**
     * Generate a single salt from all input parameters
     * @param _rawSalt this value influences the address of the clone, but not the initialization
     * @param _trustedForwarder the trusted forwarder (ERC2771) can not be changed, but is checked for security
     * @param _owner address that will own the new clone
     * @param _slopeEnumerator when slope is a/b, this value is a
     * @param _slopeDenominator when slope is a/b, this value is b
     * @param _startTimeOrBlockNumber when to start the price change
     * @param _stepDuration how often to change the price (in seconds or blocks)
     * @param _isBlockBased true = change based on block number, false = change based on timestamp
     * @param _isRising true = price only increases, false = price only decreases
     * @return salt to use for clone creation
     */
    function _generateSalt(
        bytes32 _rawSalt,
        address _trustedForwarder,
        address _owner,
        uint64 _slopeEnumerator,
        uint64 _slopeDenominator,
        uint64 _startTimeOrBlockNumber,
        uint32 _stepDuration,
        bool _isBlockBased,
        bool _isRising
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _rawSalt,
                    _trustedForwarder,
                    _owner,
                    _slopeEnumerator,
                    _slopeDenominator,
                    _startTimeOrBlockNumber,
                    _stepDuration,
                    _isBlockBased,
                    _isRising
                )
            );
    }
}
