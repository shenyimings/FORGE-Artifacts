// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDMMFactoryDelegate {
    function setFeeConfiguration(address _feeAddress, uint16 _governmentFeeBps, uint16 _platformFeeBps) external;
    function setFeeSetter(address) external;

    function allPoolsLength() external view returns (uint256);

    function getPools(IERC20 token0, IERC20 token1) external view returns (address[] memory _tokenPools);
    
    function getPoolsLength(IERC20 token0, IERC20 token1) external view returns (uint256);

    function getPoolAtIndex(
        IERC20 token0,
        IERC20 token1,
        uint256 index
    ) external view returns (address pool);
}
