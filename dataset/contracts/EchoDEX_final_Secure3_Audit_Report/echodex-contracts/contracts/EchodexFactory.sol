// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.6.6;

import './EchodexPair.sol';
import './libraries/EchodexLibrary.sol';

contract EchodexFactory {
    using SafeMath  for uint;
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(type(EchodexPair).creationCode);
    uint private constant FEE_DENOMINATOR = 10000;

    address public receiveFeeAddress;
    address public tokenFee;
    address public tokenReward;
    address public immutable owner;

    mapping(address => address[]) public feePath;
    mapping(address => uint) public feePathLength;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    mapping(address => uint) public rewardPercent; // pair -> percent

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _receiveFeeAddress, address _tokenFee, address _tokenReward) public {
        receiveFeeAddress = _receiveFeeAddress;
        tokenFee = _tokenFee;
        tokenReward = _tokenReward;
        owner = msg.sender;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'Echodex: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Echodex: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Echodex: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(EchodexPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        EchodexPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setTokenFee(address _tokenFee) external {
        require(msg.sender == owner, 'Echodex: FORBIDDEN');
        tokenFee = _tokenFee;
    }

    function setTokenReward(address _tokenReward) external {
        require(msg.sender == owner, 'Echodex: FORBIDDEN');
        tokenReward = _tokenReward;
    }

    function setReceiveFeeAddress(address _receiveFeeAddress) external {
        require(msg.sender == owner, 'Echodex: FORBIDDEN');
        receiveFeeAddress = _receiveFeeAddress;
    }

    function setFeePath(address tokenOut, address[] calldata path) external {
        require(msg.sender == owner, 'Echodex: FORBIDDEN');
        feePath[tokenOut] = path;
        feePathLength[tokenOut] = path.length;
    }

    function setRewardPercent(address pair, uint _percent) external {
        require(msg.sender == owner, 'Echodex: FORBIDDEN');
        rewardPercent[pair] = _percent;
    }

    function calcFeeOrReward(address tokenOut, uint amountOut, uint percent) external view returns (uint amount) {
        amount = amountOut.mul(percent).div(FEE_DENOMINATOR);
        if(tokenOut != tokenFee) {
            address[] memory path = feePath[tokenOut];
            uint256[] memory amounts = EchodexLibrary.getAmountsOutRouterFee(address(this), amount, path);
            amount = amounts[amounts.length - 1];
        }
    }
}