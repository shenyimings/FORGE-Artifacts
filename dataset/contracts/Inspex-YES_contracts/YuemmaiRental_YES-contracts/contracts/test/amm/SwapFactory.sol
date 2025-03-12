pragma solidity >=0.5.16 < 0.6.7;

import "./interfaces/ISwapFactory.sol";
import "./interfaces/ISwapPair.sol";
import "./interfaces/ISwapERC20.sol";
import "./interfaces/IERC20.sol";
import "./libraries/SafeMath.sol";
import "./SwapPair.sol";

contract SwapFactory is ISwapFactory {
    bytes32 public override constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(SwapPair).creationCode));

    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'Swap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Swap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Swap: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(SwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ISwapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'Swap: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'Swap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}