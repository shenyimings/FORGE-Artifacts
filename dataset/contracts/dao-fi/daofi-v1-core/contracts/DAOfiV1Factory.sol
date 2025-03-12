// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

import './interfaces/IDAOfiV1Factory.sol';
import './DAOfiV1Pair.sol';

contract DAOfiV1Factory is IDAOfiV1Factory {
    mapping(bytes32 => address) public override pairs;
    address[] public override allPairs;
    address public override formula;

    /**
    * @dev Create the factory
    *
    * @param _formula address of the bancor formula
    */
    constructor(address _formula) {
        formula = _formula;
    }

    /**
    * @dev Get a pair from the tokens and params
    *
    * @param baseToken address of the base token
    * @param quoteToken address of the quote token
    * @param slopeNumerator value 1 - 1000 which represents the curve's slope numerator (denominator 1000)
    * @param n value 1 - 3 which represents the curve's exponential parameter
    * @param fee value 0-10 which represents the pair owner's fee (1 = 0.1%)
    *
    * @return pair address of the pair, derived from the params
    */
    function getPair(address baseToken, address quoteToken, uint32 slopeNumerator, uint32 n, uint32 fee)
        public override view returns (address pair)
    {
        return pairs[keccak256(
            abi.encodePacked(baseToken, quoteToken, slopeNumerator, n, fee)
        )];
    }

    /**
    * @dev Get the total number of pairs created
    *
    * @return uint number of pairs
    */
    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    /**
    * @dev Create a pair from the tokens and params
    *
    * @param router address of the router creating the pair, used to restrict pair accesss
    * @param baseToken address of the base token
    * @param quoteToken address of the quote token
    * @param slopeNumerator value 1 - 1000 which represents the curve's slope numerator (denominator 1000)
    * @param n value 1 - 3 which represents the curve's exponential parameter
    * @param fee value 0-10 which represents the pair owner's fee (1 = 0.1%)
    *
    * @return pair address of the pair, derived from the params
    */
    function createPair(
        address router,
        address baseToken,
        address quoteToken,
        address pairOwner,
        uint32 slopeNumerator,
        uint32 n,
        uint32 fee
    ) external override returns (address pair) {
        require(baseToken != quoteToken, 'DAOfiV1: IDENTICAL_ADDRESSES');
        require(baseToken != address(0) && quoteToken != address(0), 'DAOfiV1: ZERO_ADDRESS');
        require(getPair(baseToken, quoteToken, slopeNumerator, n, fee) == address(0), 'DAOfiV1: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(DAOfiV1Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(baseToken, quoteToken, slopeNumerator, n, fee));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IDAOfiV1Pair(pair).initialize(router, baseToken, quoteToken, pairOwner, slopeNumerator, n, fee);
        pairs[salt] = pair;
        allPairs.push(pair);
        emit PairCreated(baseToken, quoteToken, pairOwner, slopeNumerator, n, fee, pair, allPairs.length);
    }
}
