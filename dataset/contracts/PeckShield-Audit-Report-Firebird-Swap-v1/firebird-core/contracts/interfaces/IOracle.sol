// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6;

interface IOracle {
    function epoch() external view returns (uint256);

    function nextEpochPoint() external view returns (uint256);

    function updateCumulative() external;

    function update() external;

    function consult(address _token, uint256 _amountIn) external view returns (uint144 _amountOut);

    function consultDollarPrice(address _sideToken, uint256 _amountIn) external view returns (uint256 _dollarPrice);

    function twap(uint256 _amountIn) external view returns (uint144 _amountOut);

    function twapDollarPrice(address _sideToken, uint256 _amountIn) external view returns (uint256 _amountOut);
}
