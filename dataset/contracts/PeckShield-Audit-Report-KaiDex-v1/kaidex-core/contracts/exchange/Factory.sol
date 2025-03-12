// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import './interfaces/IKaiDexFactory.sol';
import './KaiDexPair.sol';

contract KaiDexFactory is IKaiDexFactory {
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(KaiDexPair).creationCode));
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() override external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) override external returns (address pair) {
        require(tokenA != tokenB, 'KAIDEX: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'KAIDEX: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'KAIDEX: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(KaiDexPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        KaiDexPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) override external {
        require(msg.sender == feeToSetter, 'KAIDEX: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) override external {
        require(msg.sender == feeToSetter, 'KAIDEX: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}