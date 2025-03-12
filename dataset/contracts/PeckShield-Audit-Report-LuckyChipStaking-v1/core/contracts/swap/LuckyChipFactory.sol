// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import '../interfaces/ILuckyChipFactory.sol';
import './LuckyChipPair.sol';

contract LuckyChipFactory is ILuckyChipFactory {
    using SafeMath for uint;

    address public override feeTo;
    address public override feeToSetter;
    bytes32 public override INIT_CODE_HASH = keccak256(abi.encodePacked(type(LuckyChipPair).creationCode));

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'LuckyChip: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'LuckyChip: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'LuckyChip: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(LuckyChipPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        LuckyChipPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'LuckyChip: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'LuckyChip: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setDevFee(address _pair, uint8 _devFee) external override {
        require(msg.sender == feeToSetter, 'LuckyChip: FORBIDDEN');
        require(_devFee > 0, 'LuckyChip: FORBIDDEN_FEE');
        LuckyChipPair(_pair).setDevFee(_devFee);
    }
    
    function setSwapFee(address _pair, uint32 _swapFee) external override {
        require(msg.sender == feeToSetter, 'LuckyChip: FORBIDDEN');
        LuckyChipPair(_pair).setSwapFee(_swapFee);
    }
}
