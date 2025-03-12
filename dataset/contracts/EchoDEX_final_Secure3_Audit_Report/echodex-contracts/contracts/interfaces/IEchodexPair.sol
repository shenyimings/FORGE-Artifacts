// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.6;

interface IEchodexPair {
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
    
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function swapPayWithTokenFee(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function addFee(uint amount) external;

    function initialize(address, address) external;

    function currentFee() external view returns (uint);
}