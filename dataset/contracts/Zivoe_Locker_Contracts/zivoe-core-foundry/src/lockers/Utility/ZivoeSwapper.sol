// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IUniswapV2Pool_ZivoeSwapper {
    /// @notice Will return the address of the token at index 0.
    /// @return token0 The address of the token at index 0.
    function token0() external view returns (address);

    /// @notice Will return the address of the token at index 1.
    /// @return token1 The address of the token at index 1.
    function token1() external view returns (address);
}

interface IUniswapV3Pool_ZivoeSwapper {
    /// @notice Will return the address of the token at index 0.
    /// @return token0 The address of the token at index 0.
    function token0() external view returns (address token0);

    /// @notice Will return the address of the token at index 1.
    /// @return token1 The address of the token at index 1.
    function token1() external view returns (address token1);
}



/// @notice OneInchPrototype contract integrates with 1INCH to support custom data input.
contract ZivoeSwapper {

    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable router1INCH_V5 = 0x1111111254EEB25477B68fb85Ed929f73A960582;  /// @dev The 1INCH v5 Router.

    uint256 private constant _ONE_FOR_ZERO_MASK = 1 << 255;
    uint256 private constant _REVERSE_MASK =   0x8000000000000000000000000000000000000000000000000000000000000000;

    struct OrderRFQ {
        // Lowest 64 bits is the order id, next 64 bits is the expiration timestamp.
        // Highest bit is unwrap WETH flag which is set on taker's side.
        // [unwrap eth(1 bit) | unused (127 bits) | expiration timestamp(64 bits) | orderId (64 bits)]
        uint256 info;
        address makerAsset;
        address takerAsset;
        address maker;
        address allowedSender;  // Equals address(0) on public orders.
        uint256 makingAmount;
        uint256 takingAmount;
    }

    struct SwapDescription {
        IERC20 srcToken;
        IERC20 dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeSwapper contract.
    constructor() { }



    // ---------------
    //    Functions
    // ---------------

    /// @notice Will validate the data retrieved from 1inch API triggering a swap() function in 1inch router.
    /// @dev    The swap() function will execute a swap through multiple sources.
    /// @dev    "12aa3caf": "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)"
    function handle_validation_12aa3caf(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal view {
        (, SwapDescription memory _b,) = abi.decode(data[4:], (address, SwapDescription, bytes));
        require(address(_b.srcToken) == assetIn, "ZivoeSwapper::handle_validation_12aa3caf() address(_b.srcToken) != assetIn");
        require(address(_b.dstToken) == assetOut, "ZivoeSwapper::handle_validation_12aa3caf() address(_b.dstToken) != assetOut");
        require(_b.amount == amountIn, "ZivoeSwapper::handle_validation_12aa3caf() _b.amount != amountIn");
        require(_b.dstReceiver == address(this), "ZivoeSwapper::handle_validation_12aa3caf() _b.dstReceiver != address(this)");
    }

    /// @notice Will validate the data retrieved from 1inch API triggering an uniswapV3Swap() function in 1inch router.
    /// @dev The uniswapV3Swap() function will execute a swap through Uniswap V3 pools.
    /// @dev "e449022e": "uniswapV3Swap(uint256,uint256,uint256[])"
    function handle_validation_e449022e(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal view {
        (uint256 _a,, uint256[] memory _c) = abi.decode(data[4:], (uint256, uint256, uint256[]));
        require(_a == amountIn, "ZivoeSwapper::handle_validation_e449022e() _a != amountIn");
        bool zeroForOne_0 = _c[0] & _ONE_FOR_ZERO_MASK == 0;
        bool zeroForOne_CLENGTH = _c[_c.length - 1] & _ONE_FOR_ZERO_MASK == 0;
        if (zeroForOne_0) {
            require(IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[0])))).token0() == assetIn,
            "ZivoeSwapper::handle_validation_e449022e() IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[0])))).token0() != assetIn");
        }
        else {
            require(IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[0])))).token1() == assetIn,
            "ZivoeSwapper::handle_validation_e449022e() IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[0])))).token1() != assetIn");
        }
        if (zeroForOne_CLENGTH) {
            require(IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[_c.length - 1])))).token1() == assetOut,
            "ZivoeSwapper::handle_validation_e449022e() IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[_c.length - 1])))).token1() != assetOut");
        }
        else {
            require(IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[_c.length - 1])))).token0() == assetOut,
            "ZivoeSwapper::handle_validation_e449022e() IUniswapV3Pool_ZivoeSwapper(address(uint160(uint256(_c[_c.length - 1])))).token0() != assetOut");
        }
    }

    /// @notice Will validate the data retrieved from 1inch API triggering an unoswap() function in 1inch router.
    /// @dev The unoswap() function will execute a swap through Uniswap V2 pools or similar.
    /// @dev "0502b1c5": "unoswap(address,uint256,uint256,uint256[])"
    function handle_validation_0502b1c5(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal view {
        (address _a, uint256 _b,, uint256[] memory _d) = abi.decode(data[4:], (address, uint256, uint256, uint256[]));
        require(_a == assetIn, "ZivoeSwapper::handle_validation_0502b1c5() _a != assetIn");
        require(_b == amountIn, "ZivoeSwapper::handle_validation_0502b1c5() _b != amountIn");
        bool zeroForOne_0;
        bool zeroForOne_DLENGTH;
        uint256 info_0 = _d[0];
        uint256 info_DLENGTH = _d[_d.length - 1];
        assembly {
            zeroForOne_0 := and(info_0, _REVERSE_MASK)
            zeroForOne_DLENGTH := and(info_DLENGTH, _REVERSE_MASK)
        }
        if (zeroForOne_0) {
            require(IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[0])))).token1() == assetIn,
            "ZivoeSwapper::handle_validation_0502b1c5() IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[0])))).token1() != assetIn");
        }
        else {
            require(IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[0])))).token0() == assetIn,
            "ZivoeSwapper::handle_validation_0502b1c5() IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[0])))).token0() != assetIn");
        }
        if (zeroForOne_DLENGTH) {
            require(IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[_d.length - 1])))).token0() == assetOut,
            "ZivoeSwapper::handle_validation_0502b1c5() IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[_d.length - 1])))).token0() != assetOut");
        }
        else {
            require(IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[_d.length - 1])))).token1() == assetOut,
            "ZivoeSwapper::handle_validation_0502b1c5() IUniswapV2Pool_ZivoeSwapper(address(uint160(uint256(_d[_d.length - 1])))).token1() != assetOut");
        }
    }

    /// @notice Will validate the data retrieved from 1inch API triggering a fillOrderRFQ() function in 1inch router.
    /// @dev The fillOrderRFQ() function will execute a swap through limit orders.
    /// @dev "3eca9c0a": "fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256)"
    function handle_validation_3eca9c0a(bytes calldata data, address assetIn, address assetOut, uint256 amountIn) internal pure {
        (OrderRFQ memory _a,,) = abi.decode(data[4:], (OrderRFQ, bytes, uint256));
        require(address(_a.takerAsset) == assetIn, "ZivoeSwapper::handle_validation_3eca9c0a() address(_a.takerAsset) != assetIn");
        require(address(_a.makerAsset) == assetOut, "ZivoeSwapper::handle_validation_3eca9c0a() address(_a.makerAsset) != assetOut");
        require(_a.takingAmount == amountIn, "ZivoeSwapper::handle_validation_3eca9c0a() _a.takingAmount != amountIn");
    }

    /// @notice Executes a conversion via 1INCH v5.
    /// @param assetIn The asset that will be converted.
    /// @param assetOut The asset that "assetIn" will be converted to.
    /// @param amountIn The amount of "assetIn" that will be converted.
    /// @param data Payload for 1INCH v5 router, data regarding swap.
    function convertAsset(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        bytes calldata data
    ) internal {
        // Handle validation.
        bytes4 sig = bytes4(data[:4]);
        if (sig == bytes4(keccak256("swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)"))) {
            handle_validation_12aa3caf(data, assetIn, assetOut, amountIn);
        }
        else if (sig == bytes4(keccak256("uniswapV3Swap(uint256,uint256,uint256[])"))) {
            handle_validation_e449022e(data, assetIn, assetOut, amountIn);
        }
        else if (sig == bytes4(keccak256("unoswap(address,uint256,uint256,uint256[])"))) {
            handle_validation_0502b1c5(data, assetIn, assetOut, amountIn);
        }
        else if (sig == bytes4(keccak256("fillOrderRFQ((uint256,address,address,address,address,uint256,uint256),bytes,uint256)"))) {
            handle_validation_3eca9c0a(data, assetIn, assetOut, amountIn);
        }
        else { revert(); }

        // Execute swap.
        (bool succ,) = address(router1INCH_V5).call(data);
        require(succ, "ZivoeSwapper::convertAsset() !succ");
    }

}