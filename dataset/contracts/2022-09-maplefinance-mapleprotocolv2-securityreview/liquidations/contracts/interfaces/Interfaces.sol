// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface ILoanManagerLike {

    function getExpectedAmount(address collateralAsset_, uint256 swapAmount_) external view returns (uint256 expectedAmount_);

    function globals() external view returns (address globals_);

    function governor() external view returns (address governor_);

    function poolDelegate() external view returns (address poolDelegate_);

}

interface IERC20Like {

    function allowance(address account_, address spender_) external view returns (uint256 allowance_);

    function approve(address account_, uint256 amount_) external returns (bool success_);

    function balanceOf(address account_) external view returns (uint256 balance_);

    function decimals() external view returns (uint256 decimals_);

}

interface ILiquidatorLike {

    function getExpectedAmount(uint256 swapAmount_) external returns (uint256 expectedAmount_);

    function liquidatePortion(uint256 swapAmount_, uint256 maxReturnAmount_, bytes calldata data_) external;

}

interface IMapleGlobalsLike {

    function getLatestPrice(address asset_) external view returns (uint256 price_);

    function governor() external view returns (address governor_);

    function isFactory(bytes32 factoryId_, address factory_) external view returns (bool isValid_);

    function isValidScheduledCall(address caller_, address contract_, bytes32 functionId_, bytes calldata callData_) external view returns (bool isValid_);

    function protocolPaused() external view returns (bool protocolPaused_);

    function unscheduleCall(address caller_, bytes32 functionId_, bytes calldata callData_) external;

}

interface IOracleLike {

    function latestRoundData() external view returns (
        uint80  roundId_,
        int256  answer_,
        uint256 startedAt_,
        uint256 updatedAt_,
        uint80  answeredInRound_
    );

}

interface IUniswapRouterLike {

    function swapExactTokensForTokens(
        uint256 amountIn_,
        uint256 amountOutMin_,
        address[] calldata path_,
        address to_,
        uint256 deadline_
    ) external returns (uint256[] memory amounts_);

    function swapTokensForExactTokens(
        uint256 amountOut_,
        uint256 amountInMax_,
        address[] calldata path_,
        address to_,
        uint256 deadline_
    ) external returns (uint[] memory amounts_);

}
