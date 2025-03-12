// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.6;

interface IEchodexFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function INIT_CODE_PAIR_HASH() external view returns (bytes32);

    function calcFeeOrReward(address tokenOut, uint amountOut, uint percent) external view returns(uint amount);

    function tokenFee() external view returns (address);
    function tokenReward() external view returns (address);

    function owner() external view returns (address);

    function receiveFeeAddress() external view returns (address);

    function setTokenFee(address) external;

    function setReceiveFeeAddress(address) external;

    function rewardPercent(address pair) external view returns (uint percent);

    function setRefundPercentPair(address, uint) external;

    function setFeePath(address, address[] calldata) external;

    function feePathLength(address) external view returns(uint);
}