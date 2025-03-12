// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV2.sol";
import "@overnight-contracts/connectors/contracts/stuff/MeshSwap.sol";

contract StrategyMeshSwapUsdc is Strategy, UniswapV2Exchange {

    IERC20 public usdcToken;
    IERC20 public meshToken;

    IMeshSwapLP public meshSwapUsdc;


    // --- events

    event StrategyUpdatedTokens(address usdcToken, address meshToken);

    event StrategyUpdatedParams(address meshSwapUsdc, address meshSwapRouter );


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _meshToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_meshToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        meshToken = IERC20(_meshToken);

        emit StrategyUpdatedTokens(_usdcToken, _meshToken);
    }

    function setParams(
        address _meshSwapUsdc,
        address _meshSwapRouter
    ) external onlyAdmin {

        require(_meshSwapUsdc != address(0), "Zero address not allowed");
        require(_meshSwapRouter != address(0), "Zero address not allowed");

        meshSwapUsdc = IMeshSwapLP(_meshSwapUsdc);
        _setUniswapRouter(_meshSwapRouter);

        emit StrategyUpdatedParams(_meshSwapUsdc, _meshSwapRouter);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        usdcToken.approve(address(meshSwapUsdc), _amount);
        meshSwapUsdc.depositToken(_amount);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        meshSwapUsdc.withdrawToken(_amount);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        //TODO fix count
        uint256 usdcTokenAmount = meshSwapUsdc.balanceOf(address(this)) * 2;
        meshSwapUsdc.withdrawToken(usdcTokenAmount);

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        //TODO fix count
        return meshSwapUsdc.balanceOf(address(this)) * 2;
    }

    function liquidationValue() external view override returns (uint256) {
        //TODO fix count
        return meshSwapUsdc.balanceOf(address(this)) * 2;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        //claim rewards
        meshSwapUsdc.claimReward();

        // sell rewards
        uint256 totalUsdc;

        uint256 meshBalance = meshToken.balanceOf(address(this));
        if (meshBalance > 0) {
            uint256 meshUsdc = _swapExactTokensForTokens(
                address(meshToken),
                address(usdcToken),
                meshBalance,
                address(this)
            );
            totalUsdc += meshUsdc;
        }

        usdcToken.transfer(_to, usdcToken.balanceOf(address(this)));

        return totalUsdc;
    }

}
