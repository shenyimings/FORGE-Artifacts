// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20Like, IMapleGlobalsLike, IOracleLike, IUniswapRouterLike, ILiquidatorLike } from "../../interfaces/Interfaces.sol";

import { TestUtils } from "../../../modules/contract-test-utils/contracts/test.sol";

contract EmptyContract { }

contract FailApproveERC20 {

    function approve(address, uint256) public pure returns (bool) {
        return false;
    }

}

contract MaliciousERC20 {

    function transferAndCall(address to_) public {
        ILiquidatorLike(to_).liquidatePortion(0, 0, bytes(""));
    }

}

contract MockFactory {

    mapping(address => bool) public isInstance;

    function __setInstance(address instance_, bool isInstance_) external {
        isInstance[instance_] = isInstance_;
    }

}

contract MockGlobals {

    address public governor;

    bool public protocolPaused;

    bool internal _isValidScheduledCall;

    mapping(address => address) public oracleFor;

    mapping(bytes32 => mapping(address => bool)) public isFactory;

    constructor(address governor_) {
        governor = governor_;
    }

    function getLatestPrice(address asset_) external view returns (uint256 price_) {
        ( , int256 price, , , ) = IOracleLike(oracleFor[asset_]).latestRoundData();
        return uint256(price);
    }

    function isValidScheduledCall(address, address, bytes32, bytes calldata) external view returns (bool isValid_) {
        isValid_ = _isValidScheduledCall;
    }

    function unscheduleCall(address, bytes32, bytes calldata) external { }

    function __setFactory(bytes32 factoryId_, address factory_, bool isValid_) external {
        isFactory[factoryId_][factory_] = isValid_;
    }

    function __setIsValidScheduledCall(bool isValid_) external {
        _isValidScheduledCall = isValid_;
    }

    function __setPriceOracle(address asset_, address oracle_) external {
        oracleFor[asset_] = oracle_;
    }

    function __setProtocolPaused(bool paused_) external {
        protocolPaused = paused_;
    }

}

contract MockLoanManager {

    address public factory;
    address public fundsAsset;
    address public globals;
    address public poolDelegate;

    mapping(address => uint256) public allowedSlippageFor;
    mapping(address => uint256) public minRatioFor;

    constructor(address globals_, address fundsAsset_, address poolDelegate_) {
        globals      = globals_;
        fundsAsset   = fundsAsset_;
        poolDelegate = poolDelegate_;
    }

    function getExpectedAmount(address collateralAsset_, uint256 swapAmount_) public view returns (uint256 returnAmount_) {
        uint256 oracleAmount =
            swapAmount_
                * IMapleGlobalsLike(globals).getLatestPrice(collateralAsset_)  // Convert from `fromAsset` value.
                * 10 ** IERC20Like(fundsAsset).decimals()                      // Convert to `toAsset` decimal precision.
                * (10_000 - allowedSlippageFor[collateralAsset_])              // Multiply by allowed slippage basis points.
                / IMapleGlobalsLike(globals).getLatestPrice(fundsAsset)        // Convert to `toAsset` value.
                / 10 ** IERC20Like(collateralAsset_).decimals()                // Convert from `fromAsset` decimal precision.
                / 10_000;                                                      // Divide basis points for slippage.

        uint256 minRatioAmount = (swapAmount_ * minRatioFor[collateralAsset_]) / (10 ** IERC20Like(collateralAsset_).decimals());

        return oracleAmount > minRatioAmount ? oracleAmount : minRatioAmount;
    }

    function governor() external view returns (address governor_) {
        governor_ = IMapleGlobalsLike(globals).governor();
    }

    function __setFactory(address factory_) external {
        factory = factory_;
    }

    function __setValuesFor(address collateralAsset_, uint256 allowedSlippage_, uint256 minRatio_) external {
        allowedSlippageFor[collateralAsset_] = allowedSlippage_;
        minRatioFor[collateralAsset_]        = minRatio_;
    }

}

contract MockMigrator {

    address collateralAsset;

    fallback() external {
        collateralAsset = abi.decode(msg.data, (address));
    }

}

// Contract to perform fake arbitrage transactions to prop price back up.
contract Rebalancer is TestUtils {

    function swap(
        address router_,
        uint256 amountOut_,
        uint256 amountInMax_,
        address fromAsset_,
        address middleAsset_,
        address toAsset_
    )
        external
    {
        IERC20Like(fromAsset_).approve(router_, amountInMax_);

        bool hasMiddleAsset = middleAsset_ != toAsset_ && middleAsset_ != address(0);

        address[] memory path = new address[](hasMiddleAsset ? 3 : 2);

        path[0] = address(fromAsset_);
        path[1] = hasMiddleAsset ? middleAsset_ : toAsset_;

        if (hasMiddleAsset) {
            path[2] = toAsset_;
        }

        IUniswapRouterLike(router_).swapTokensForExactTokens(
            amountOut_,
            amountInMax_,
            path,
            address(this),
            block.timestamp
        );
    }

}

contract ReentrantLiquidator {

    address lender;
    uint256 swapAmount;

    function flashBorrowLiquidation(
        address lender_,
        uint256 swapAmount_
    )
        external
    {
        lender     = lender_;
        swapAmount = swapAmount_;

        ILiquidatorLike(lender_).liquidatePortion(
            swapAmount_,
            type(uint256).max,
            abi.encodeWithSelector(
                this.reenter.selector
            )
        );
    }

    function reenter() external {
        ILiquidatorLike(lender).liquidatePortion(swapAmount, type(uint256).max, new bytes(0));
    }

}
