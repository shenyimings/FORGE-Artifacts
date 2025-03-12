pragma solidity =0.5.16;

import './interfaces/IFireBirdFactory.sol';
import './FireBirdPair.sol';

contract FireBirdFactory is IFireBirdFactory {
    address public feeTo;
    address public formula;
    uint public protocolFee;
    address public feeToSetter;

    mapping(bytes32 => address) private _pairSalts;
    address[] public allPairs;
    mapping(address => uint64) private _pairs;


    constructor(address _feeToSetter, address _formula) public {
        feeToSetter = _feeToSetter;
        formula = _formula;
    }
    function isPair(address b) external view returns (bool){
        return _pairs[b] > 0;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function getPair(address tokenA, address tokenB, uint32 tokenWeightA, uint32 swapFee) external view returns (address pair){
        (address token0, address token1, uint32 tokenWeight0) = tokenA < tokenB ? (tokenA, tokenB, tokenWeightA) : (tokenB, tokenA, 100 - tokenWeightA);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, tokenWeight0, swapFee));
        pair = _pairSalts[salt];
    }
    function createPair(address tokenA, address tokenB, uint32 tokenWeightA, uint32 swapFee) external returns (address pair) {
        require(tokenA != tokenB, 'FLP: IDENTICAL_ADDRESSES');
        require(tokenWeightA >= 2 && tokenWeightA <= 98 && (tokenWeightA % 2) == 0, 'FLP: INVALID_TOKEN_WEIGHT');
        // swap fee from [0.01% - 20%]
        require(swapFee >= 1 && swapFee <= 2000, 'FLP: INVALID_SWAP_FEE');
        (address token0, address token1, uint32 tokenWeight0) = tokenA < tokenB ? (tokenA, tokenB, tokenWeightA) : (tokenB, tokenA, 100 - tokenWeightA);
        require(token0 != address(0), 'FLP: ZERO_ADDRESS');
        // single check is sufficient
        bytes memory bytecode = type(FireBirdPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, tokenWeight0, swapFee));
        require(_pairSalts[salt] == address(0), 'FLP: PAIR_EXISTS');
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IFireBirdPair(pair).initialize(token0, token1, tokenWeight0, swapFee);
        _pairSalts[salt] = address(pair);
        allPairs.push(pair);
        uint64 weightAndFee = uint64(swapFee);
        weightAndFee |= uint64(tokenWeight0)<<32;
        _pairs[address(pair)] = weightAndFee;
        emit PairCreated(token0, token1, pair, tokenWeight0, swapFee, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'FLP: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'FLP: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setProtocolFee(uint _protocolFee) external {
        require(msg.sender == feeToSetter, 'FLP: FORBIDDEN');
        require(_protocolFee == 0 || (_protocolFee >= 10000 && _protocolFee <= 100000), 'FLP: Invalid Protocol fee');
        protocolFee = _protocolFee;
    }

    function getWeightsAndSwapFee(address pair) public view returns (uint32 tokenWeight0, uint32 tokenWeight1, uint32 swapFee) {
        uint64 weightAndFee = _pairs[pair];
        if (weightAndFee > 0) {
            swapFee = uint32(weightAndFee);
            tokenWeight0 = uint32(weightAndFee>>32);
            tokenWeight1 = 100 - tokenWeight0;
        } else {
            // Default is 0.3%
            return (50, 50, 30);
        }
    }
}
