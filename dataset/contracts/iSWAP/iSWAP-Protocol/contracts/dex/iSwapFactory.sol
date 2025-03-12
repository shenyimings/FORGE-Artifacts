// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.6.12;

import "./interfaces/IiSwapFactory.sol";
import "./iSwapPair.sol";

contract iSwapFactory is IiSwapFactory {
    address public override feeTo;
    address public override feeToSetter;
    uint256 public override feeToRate = 5;
    address public override migrator;
    bytes32 public override initCodeHash;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
        initCodeHash = keccak256(
            abi.encodePacked(type(iSwapPair).creationCode)
        );
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(iSwapPair).creationCode);
    }

    function createPair(address tokenA, address tokenB)
        external
        override
        returns (address pair)
    {
        require(tokenA != tokenB, "iSwapFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "iSwapFactory: ZERO_ADDRESS");
        require(
            getPair[token0][token1] == address(0),
            "iSwapFactory: PAIR_EXISTS"
        ); // single check is sufficient
        bytes memory bytecode = type(iSwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        iSwapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "iSwapFactory: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setMigrator(address _migrator) external override {
        require(msg.sender == feeToSetter, "iSwapFactory: FORBIDDEN");
        migrator = _migrator;
    }

    function setFeeToRate(uint256 _rate) external override {
        require(msg.sender == feeToSetter, "iSwapFactory: FORBIDDEN");
        require(_rate > 0, "iSwapFactory: FEE_TO_RATE_OVERFLOW");
        feeToRate = _rate - 1;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "iSwapFactory: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}
