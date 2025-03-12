// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.4;
pragma experimental ABIEncoderV2;

interface IDAOfiV1Pair {
    event Deposit(address indexed sender, uint256 amountBase, uint256 amountQuote, uint256 output, address indexed to);
    event Withdraw(address indexed sender, uint256 amountBase, uint256 amountQuote, address indexed to);
    event WithdrawFees(address indexed sender, uint256 amountBase, uint256 amountQuote, address indexed to);
    event Swap(
        address indexed pair,
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );

    function PLATFORM_FEE() external view returns (uint8);
    function factory() external view returns (address);
    function baseToken() external view returns (address);
    function quoteToken() external view returns (address);
    function pairOwner() external view returns (address);
    function slopeNumerator() external view returns (uint32);
    function n() external view returns (uint32);
    function fee() external view returns (uint32);
    function reserveRatio() external view returns (uint32);
    function supply() external view returns (uint256);
    function initialize(
        address _router,
        address _baseToken,
        address _quoteToken,
        address _pairOwner,
        uint32 _slopeNumerator,
        uint32 _n,
        uint32 _fee
    ) external;
    function setPairOwner(address) external;
    function getReserves() external view returns (uint256 reserveBase, uint256 reserveQuote);
    function getPlatformFees() external view returns (uint256 feesBase, uint256 feesQuote);
    function getOwnerFees() external view returns (uint256 feesBase, uint256 feesQuote);
    function basePrice() external view returns (uint256 price);
    function quotePrice() external view returns (uint256 price);
    function deposit(address to) external returns (uint256 amountBase);
    function withdraw(address to) external returns (uint256 amountBase, uint256 amountQuote);
    function withdrawPlatformFees(address to) external returns (uint256 amountBase, uint256 amountQuote);
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, address to) external;
    function getBaseOut(uint256 amountQuoteIn) external view returns (uint256 amountBaseOut);
    function getQuoteOut(uint256 amountBaseIn) external view returns (uint256 amountQuoteOut);
}
