// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Wombat.sol";
import "@overnight-contracts/connectors/contracts/stuff/PancakeV2.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";


contract StrategyWombatBusd is Strategy {

    // --- structs

    struct StrategyParams {
        address busdToken;
        address womToken;
        address asset;
        address pool;
        address masterWombat;
        address pancakeRouter;
        address rewardWallet;
        uint256 rewardWalletPercent;
    }

    // --- params

    IERC20 public busdToken;
    IERC20 public womToken;

    IAsset public asset;
    IPool public pool;
    IMasterWombatV2 public masterWombat;

    IPancakeRouter02 public pancakeRouter;

    address public rewardWallet;
    uint256 public rewardWalletPercent;

    uint256 public busdTokenDenominator;
    uint256 public assetTokenDenominator;

    // --- events

    event StrategyUpdatedParams();

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }

    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        busdToken = IERC20(params.busdToken);
        womToken = IERC20(params.womToken);

        asset = IAsset(params.asset);
        pool = IPool(params.pool);
        masterWombat = IMasterWombatV2(params.masterWombat);

        pancakeRouter = IPancakeRouter02(params.pancakeRouter);

        rewardWallet = params.rewardWallet;
        rewardWalletPercent = params.rewardWalletPercent;

        busdTokenDenominator = 10 ** IERC20Metadata(params.busdToken).decimals();
        assetTokenDenominator = 10 ** IERC20Metadata(params.asset).decimals();

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(busdToken), "Some token not compatible");

        // add liquidity
        (uint256 assetAmount,) = pool.quotePotentialDeposit(address(busdToken), _amount);
        busdToken.approve(address(pool), _amount);
        pool.deposit(
            address(busdToken),
            _amount,
            // 1bp slippage
            OvnMath.subBasisPoints(assetAmount, 1),
            address(this),
            block.timestamp,
            false
        );

        // stake
        uint256 pid = masterWombat.getAssetPid(address(asset));
        uint256 assetBalance = asset.balanceOf(address(this));
        asset.approve(address(masterWombat), assetBalance);
        masterWombat.deposit(pid, assetBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busdToken), "Some token not compatible");

        // get amount to unstake
        (uint256 busdAmountOneAsset,) = pool.quotePotentialWithdraw(address(busdToken), assetTokenDenominator);
        // add 1bp for smooth withdraw
        uint256 assetAmount = OvnMath.addBasisPoints(_amount, 1) * assetTokenDenominator / busdAmountOneAsset;
        uint256 pid = masterWombat.getAssetPid(address(asset));
        (uint128 assetBalance,,,) = masterWombat.userInfo(pid, address(this));
        if (assetAmount > assetBalance) {
            assetAmount = assetBalance;
        }

        // unstake
        masterWombat.withdraw(pid, assetAmount);

        // remove liquidity
        asset.approve(address(pool), assetAmount);
        pool.withdraw(
            address(busdToken),
            assetAmount,
            _amount,
            address(this),
            block.timestamp
        );

        return busdToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busdToken), "Some token not compatible");

        // get amount to unstake
        uint256 pid = masterWombat.getAssetPid(address(asset));
        (uint128 assetBalance,,,) = masterWombat.userInfo(pid, address(this));

        // unstake
        masterWombat.withdraw(pid, assetBalance);

        // remove liquidity
        (uint256 busdAmount,) = pool.quotePotentialWithdraw(address(busdToken), assetBalance);
        asset.approve(address(pool), assetBalance);
        pool.withdraw(
            address(busdToken),
            assetBalance,
            // 1bp slippage
            OvnMath.subBasisPoints(busdAmount, 1),
            address(this),
            block.timestamp
        );

        return busdToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 busdBalance = busdToken.balanceOf(address(this));

        uint256 pid = masterWombat.getAssetPid(address(asset));
        (uint128 assetBalance,,,) = masterWombat.userInfo(pid, address(this));
        if (assetBalance > 0) {
            if (nav) {
                (uint256 busdAmountOneAsset,) = pool.quotePotentialWithdraw(address(busdToken), assetTokenDenominator);
                busdBalance += assetBalance * busdAmountOneAsset / assetTokenDenominator;
            } else {
                (uint256 busdAmount,) = pool.quotePotentialWithdraw(address(busdToken), assetBalance);
                busdBalance += busdAmount;
            }
        }

        return busdBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        uint256 pid = masterWombat.getAssetPid(address(asset));
        (uint128 assetBalance,,,) = masterWombat.userInfo(pid, address(this));
        if (assetBalance > 0) {
            masterWombat.deposit(pid, 0);
        }

        // sell rewards
        uint256 totalBusd;

        uint256 womBalance = womToken.balanceOf(address(this));
        if (womBalance > 0) {
            uint256 amountOut = PancakeSwapLibrary.getAmountsOut(
                pancakeRouter,
                address(womToken),
                address(busdToken),
                womBalance
            );

            if (amountOut > 0) {
                uint256 womBusd = PancakeSwapLibrary.swapExactTokensForTokens(
                    pancakeRouter,
                    address(womToken),
                    address(busdToken),
                    womBalance,
                    amountOut * 99 / 100,
                    address(this)
                );

                totalBusd += womBusd;
            }
        }

        // send percent to rewardWallet
        if (totalBusd > 0) {
            uint256 rewardBalance = totalBusd * rewardWalletPercent / 1e4;
            uint256 toBalance = totalBusd - rewardBalance;
            busdToken.transfer(rewardWallet, rewardBalance);
            busdToken.transfer(_to, toBalance);
        }

        return totalBusd;
    }

}
