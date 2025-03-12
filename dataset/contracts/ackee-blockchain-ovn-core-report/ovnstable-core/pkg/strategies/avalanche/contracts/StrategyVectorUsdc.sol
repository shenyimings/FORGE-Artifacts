// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/TraderJoe.sol";
import "@overnight-contracts/connectors/contracts/stuff/Vector.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

contract StrategyVectorUsdc is Strategy {
    using OvnMath for uint256;

    IERC20 public usdcToken;
    IERC20 public wAvaxToken;
    IERC20 public ptpToken;
    IERC20 public vtxToken;

    IJoeRouter02 public traderJoeRouter;
    IPoolHelper public poolHelper;
    address public mainStaking;


    // --- events

    event StrategyUpdatedTokens(address usdcToken, address wAvaxToken, address ptpToken, address vtxToken);

    event StrategyUpdatedParams(address traderJoeRouter, address poolHelper, address mainStaking);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _wAvaxToken,
        address _ptpToken,
        address _vtxToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_wAvaxToken != address(0), "Zero address not allowed");
        require(_ptpToken != address(0), "Zero address not allowed");
        require(_vtxToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        wAvaxToken = IERC20(_wAvaxToken);
        ptpToken = IERC20(_ptpToken);
        vtxToken = IERC20(_vtxToken);

        emit StrategyUpdatedTokens(_usdcToken, _wAvaxToken, _ptpToken, _vtxToken);
    }

    function setParams(
        address _traderJoeRouter,
        address _poolHelper,
        address _mainStaking
    ) external onlyAdmin {

        require(_traderJoeRouter != address(0), "Zero address not allowed");
        require(_poolHelper != address(0), "Zero address not allowed");
        require(_mainStaking != address(0), "Zero address not allowed");

        traderJoeRouter = IJoeRouter02(_traderJoeRouter);
        poolHelper = IPoolHelper(_poolHelper);
        mainStaking = _mainStaking;

        emit StrategyUpdatedParams(_traderJoeRouter, _poolHelper, _mainStaking);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 stakeAmount = usdcToken.balanceOf(address(this));
        usdcToken.approve(mainStaking, stakeAmount);
        poolHelper.deposit(stakeAmount);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        poolHelper.withdraw(_amount.addBasisPoints(4), _amount);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 userDepositedBalance = poolHelper.depositTokenBalance();
        if (userDepositedBalance == 0) {
            return 0;
        }

        poolHelper.withdraw(userDepositedBalance, userDepositedBalance.subBasisPoints(4));

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        if (nav) {
            return poolHelper.depositTokenBalance();
        } else {
            return poolHelper.depositTokenBalance().subBasisPoints(4);
        }
    }

    function _claimRewards(address _beneficiary) internal override returns (uint256) {

        uint256 userDepositedBalance = poolHelper.depositTokenBalance();
        if (userDepositedBalance == 0) {
            return 0;
        }

        //claim rewards
        poolHelper.getReward();

        // sell rewards
        uint256 totalUsdc;

        uint256 ptpBalance = ptpToken.balanceOf(address(this));
        if (ptpBalance > 0) {
            uint256 amountOutMin = TraderJoeLibrary.getAmountsOut(
                traderJoeRouter,
                address(ptpToken),
                address(wAvaxToken),
                address(usdcToken),
                ptpBalance
            );

            if (amountOutMin > 0) {
                uint256 ptpUsdc = TraderJoeLibrary.swapExactTokensForTokens(
                    traderJoeRouter,
                    address(ptpToken),
                    address(wAvaxToken),
                    address(usdcToken),
                    ptpBalance,
                    amountOutMin.subBasisPoints(4),
                    address(this)
                );
                totalUsdc += ptpUsdc;
            }
        }

        uint256 vtxBalance = vtxToken.balanceOf(address(this));
        if (vtxBalance > 0) {
            uint256 amountOutMin = TraderJoeLibrary.getAmountsOut(
                traderJoeRouter,
                address(vtxToken),
                address(wAvaxToken),
                address(usdcToken),
                vtxBalance
            );

            if (amountOutMin > 0) {
                uint256 vtxUsdc = TraderJoeLibrary.swapExactTokensForTokens(
                    traderJoeRouter,
                    address(vtxToken),
                    address(wAvaxToken),
                    address(usdcToken),
                    vtxBalance,
                    amountOutMin.subBasisPoints(4),
                    address(this)
                );
                totalUsdc += vtxUsdc;
            }
        }

        usdcToken.transfer(_beneficiary, usdcToken.balanceOf(address(this)));

        return totalUsdc;
    }

}
