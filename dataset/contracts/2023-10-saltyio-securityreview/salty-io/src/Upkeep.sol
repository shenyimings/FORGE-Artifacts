// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "./pools/interfaces/IPools.sol";
import "./pools/interfaces/IPoolsConfig.sol";
import "./interfaces/IExchangeConfig.sol";
import "./price_feed/interfaces/IPriceAggregator.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./dao/interfaces/IDAOConfig.sol";
import "./pools/Counterswap.sol";
import "./rewards/interfaces/IEmissions.sol";
import "./pools/interfaces/IPoolStats.sol";
import "./staking/interfaces/ILiquidity.sol";
import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";


// Performs the following upkeep for each call to performUpkeep():
// 1. Updates the prices of BTC and ETH in the PriceAggregator.
// 2. Sends WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraws USDS from counterswap for burning.
// 3. Withdraws the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
// 4. Has the DAO withdraw the WETH arbitrage profits from the Pools contract.
// 5. Sends a default 5% of the withdrawn WETH to the caller of performUpkeep().
// 6. Sends a default 10% (20% / 2) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
// 7. Sends all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
// 8. Withdraws SALT from previous counterswaps.
// 9. Sends SALT and USDS (from steps 3 and 8) to the DAO and has it form SALT/USDS Protocol Owned Liquidity
// 10. Sends the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.  Remaining USDS stays in the Upkeep contract for later POL formation.
// 11. Sends SALT Emissions to the SaltRewards contract.
// 12. Distributes SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
// 13. Distributes SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.
// 14. Collects SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): sends 10% to the team and burns a default 75% of the remaining.
// 15. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
// 16. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

contract Upkeep is IUpkeep
    {
	using SafeERC20 for ISalt;
	using SafeERC20 for IUSDS;
	using SafeERC20 for IERC20;

    event UpkeepError(string description, bytes error);

	IPools immutable public pools;
	IExchangeConfig  immutable public exchangeConfig;
	IPoolsConfig immutable public poolsConfig;
	IDAOConfig immutable public daoConfig;
	IPriceAggregator immutable public priceAggregator;
	ISaltRewards immutable public saltRewards;
	ILiquidity immutable public liquidity;
	IEmissions immutable public emissions;

	IERC20  immutable public weth;
	ISalt  immutable public salt;
	IUSDS  immutable public usds;

	uint256 public lastUpkeepTime;


    constructor( IPools _pools, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IDAOConfig _daoConfig, IPriceAggregator _priceAggregator, ISaltRewards _saltRewards, ILiquidity _liquidity, IEmissions _emissions )
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_poolsConfig) != address(0), "_poolsConfig cannot be address(0)" );
		require( address(_daoConfig) != address(0), "_daoConfig cannot be address(0)" );
		require( address(_priceAggregator) != address(0), "_priceAggregator cannot be address(0)" );
		require( address(_saltRewards) != address(0), "_saltRewards cannot be address(0)" );
		require( address(_liquidity) != address(0), "_liquidity cannot be address(0)" );
		require( address(_emissions) != address(0), "_emissions cannot be address(0)" );

		pools = _pools;
		exchangeConfig = _exchangeConfig;
		poolsConfig = _poolsConfig;
		daoConfig = _daoConfig;
		priceAggregator = _priceAggregator;
		saltRewards = _saltRewards;
		liquidity = _liquidity;
		emissions = _emissions;

		// Cached for efficiency
		weth = _exchangeConfig.weth();
		salt = _exchangeConfig.salt();
		usds = _exchangeConfig.usds();

		lastUpkeepTime = block.timestamp;
		}


	modifier onlySameContract()
		{
    	require(msg.sender == address(this), "Only callable from within the same contract");
    	_;
		}


	function _withdrawTokenFromCounterswap( IERC20 token, address counterswapAddress ) internal
		{
		uint256 tokenDepositedInCounterswap = pools.depositedBalance( counterswapAddress, token );
		if ( tokenDepositedInCounterswap == 0 )
			return;

		pools.withdrawTokenFromCounterswap( counterswapAddress, token, tokenDepositedInCounterswap );
		}


	// 1. Update the prices of BTC and ETH in the PriceAggregator.
	function step1() public onlySameContract
		{
 		priceAggregator.performUpkeep();
		}


	// 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
	function step2() public onlySameContract
		{
		usds.performUpkeep();
		}


	// 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
	function step3() public onlySameContract
		{
		_withdrawTokenFromCounterswap(usds, Counterswap.WBTC_TO_USDS);
		_withdrawTokenFromCounterswap(usds, Counterswap.WETH_TO_USDS);
		}


	// 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
	function step4() public onlySameContract
		{
		exchangeConfig.dao().withdrawArbitrageProfits(weth);
		}


	// 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
	// The only WETH balance normally in the contract will be the WETH arbitrage profit that was withdrawn in step4
	function step5( address receiver ) public onlySameContract
		{
		uint256 wethBalance = weth.balanceOf( address(this) );

		if ( wethBalance == 0 )
			return;

		uint256 rewardAmount = wethBalance * daoConfig.upkeepRewardPercent() / 100;

		// Send the reward
		weth.safeTransfer(receiver, rewardAmount);
		}


	// 6. Send a default 10% (20% / 2) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
	function step6() public onlySameContract
		{
		uint256 wethBalance = weth.balanceOf( address(this) );

		// Only half the specified percent will be used for USDS to form SALT/USDS POL (the other half will be counterswapped into SALT in step7)
		uint256 wethAmountForUSDS = ( wethBalance * daoConfig.arbitrageProfitsPercentPOL() / 100 ) / 2;
		weth.approve( address(pools), wethAmountForUSDS );

		pools.depositTokenForCounterswap( Counterswap.WETH_TO_USDS, weth, wethAmountForUSDS );
		}


	// 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
	function step7() public onlySameContract
		{
		// WETH approval done in the previous step
		uint256 wethBalance = weth.balanceOf( address(this) );
		weth.approve( address(pools), wethBalance );

		pools.depositTokenForCounterswap( Counterswap.WETH_TO_SALT, weth, wethBalance );
		}


	// 8. Withdraw SALT from previous counterswaps.
	function step8() public onlySameContract
		{
		_withdrawTokenFromCounterswap(salt, Counterswap.WETH_TO_SALT);
		}


	// 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
	// Any SALT or USDS that is not used will be stay in the DAO contract for later POL formation.
	function step9() public onlySameContract
		{
		uint256 saltBalance = salt.balanceOf( address(this) );
		uint256 usdsBalance = usds.balanceOf( address(this) );

		IDAO dao = exchangeConfig.dao();

		salt.safeTransfer(address(dao), saltBalance);
		usds.safeTransfer(address(dao), usdsBalance);

		dao.formPOL(liquidity, salt, usds);
		}


	// 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
	function step10( uint256 daoStartingSaltBalance ) public onlySameContract
		{
		IDAO dao = exchangeConfig.dao();

		uint256 daoSaltBalance = salt.balanceOf( address(dao) );

		// Assume that the DAO SALT balance held at the start of performUpkeep() should just stay in the DAO.
		// The only exception to this would be when extra USDS was kept in the DAO contract and matched with SALT to form POL in step9 in which case the current SALT balance could be less than the starting SALT balance.
		if ( daoSaltBalance < daoStartingSaltBalance )
			return;

		// See how much withdrawn SALT was left over from step9
		uint256 saltRewardsToSend = daoSaltBalance - daoStartingSaltBalance;

		if ( saltRewardsToSend == 0 )
			return;

		dao.sendSaltToSaltRewards(salt, saltRewards, saltRewardsToSend);
		}


	// 11. Send SALT Emissions to the SaltRewards contract.
	function step11( uint256 timeSinceLastUpkeep ) public onlySameContract
		{
		emissions.performUpkeep(timeSinceLastUpkeep);
		}


	// 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
	function step12( bytes32[] memory poolIDs) public onlySameContract
		{
		IPoolStats poolStats = IPoolStats(address(pools));

		uint256[] memory profitsForPools = poolStats.profitsForPools(poolIDs);
		saltRewards.performUpkeep(poolIDs, profitsForPools );

		poolStats.clearProfitsForPools(poolIDs);
		}


	// 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.
	function step13( uint256 timeSinceLastUpkeep ) public onlySameContract
		{
		exchangeConfig.stakingRewardsEmitter().performUpkeep(timeSinceLastUpkeep, true);
		exchangeConfig.liquidityRewardsEmitter().performUpkeep(timeSinceLastUpkeep, false);
		}


	// 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
	function step14() public onlySameContract
		{
		exchangeConfig.dao().processRewardsFromPOL(liquidity, salt, usds);
		}


	// 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
	function step15() public onlySameContract
		{
		VestingWallet(payable(exchangeConfig.daoVestingWallet())).release(address(salt));
		}


	// 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
	// The teamVestingWallet vests to this contract - which is then transferred to the active teamWallet.
	function step16() public onlySameContract
		{
		uint256 releaseableAmount = VestingWallet(payable(exchangeConfig.teamVestingWallet())).releasable(address(salt));

		// teamVestingWallet actually sends the vested SALT to this contract (which will then need to be sent to the active teamWallet)
		VestingWallet(payable(exchangeConfig.teamVestingWallet())).release(address(salt));

		salt.safeTransfer( exchangeConfig.teamWallet(), releaseableAmount );
		}


	// Perform the various steps of performUpkeep as outlined at the top of the contract.
	// Each step is wrapped in a try/catch and called using this.stepX() - with each stepX function requiring that the caller has to be this contract.
	// Uses a maximum of 2.8 million gas with 100 whitelisted pools according to UpkeepGasUsage.t.sol
	function performUpkeep() public
		{
		require( block.timestamp >= lastUpkeepTime, "Cannot update with an earlier block.timestamp than lastUpkeepTime" );

		uint256 timeSinceLastUpkeep = block.timestamp - lastUpkeepTime;

		bytes32[] memory poolIDs = poolsConfig.whitelistedPools();

		// Perform the multiple steps to perform upkeep.
		// Try/catch blocks are used to prevent any of the steps (which are not independent from previous steps) from reverting the transaction.
 		try this.step1() {}
		catch (bytes memory error) { emit UpkeepError("Step 1", error); }

 		try this.step2() {}
		catch (bytes memory error) { emit UpkeepError("Step 2", error); }

 		try this.step3() {}
		catch (bytes memory error) { emit UpkeepError("Step 3", error); }

 		try this.step4() {}
		catch (bytes memory error) { emit UpkeepError("Step 4", error); }

 		try this.step5(msg.sender) {}
		catch (bytes memory error) { emit UpkeepError("Step 5", error); }

 		try this.step6() {}
		catch (bytes memory error) { emit UpkeepError("Step 6", error); }

 		try this.step7() {}
		catch (bytes memory error) { emit UpkeepError("Step 7", error); }

 		try this.step8() {}
		catch (bytes memory error) { emit UpkeepError("Step 8", error); }

		// Remember the DAO SALT balance before SALT is sent there to form POL
		// It will be assumed that that SALT should just stay in the contract and not be sent to the SaltRewards contract
		uint256 daoStartingSaltBalance = salt.balanceOf( address(exchangeConfig.dao()) );

 		try this.step9() {}
		catch (bytes memory error) { emit UpkeepError("Step 9", error); }

 		try this.step10(daoStartingSaltBalance) {}
		catch (bytes memory error) { emit UpkeepError("Step 10", error); }

 		try this.step11(timeSinceLastUpkeep) {}
		catch (bytes memory error) { emit UpkeepError("Step 11", error); }

 		try this.step12(poolIDs) {}
		catch (bytes memory error) { emit UpkeepError("Step 12", error); }

 		try this.step13(timeSinceLastUpkeep) {}
		catch (bytes memory error) { emit UpkeepError("Step 13", error); }

 		try this.step14() {}
		catch (bytes memory error) { emit UpkeepError("Step 14", error); }

 		try this.step15() {}
		catch (bytes memory error) { emit UpkeepError("Step 15", error); }

 		try this.step16() {}
		catch (bytes memory error) { emit UpkeepError("Step 16", error); }

		lastUpkeepTime = block.timestamp;
		}


	// ==== VIEWS ====
	// Returns the amount of SALT that will currently be rewarded for calling performUpkeep()
	// Useful for potential callers to know if calling the function will be profitable in comparison to the gas costs
	function currentRewardsForCallingPerformUpkeep() public view returns (uint256)
		{
		uint256 daoWETH = pools.depositedBalance( address(exchangeConfig.dao()), weth );

		if ( daoWETH == 0 )
			return 0;

		return daoWETH * daoConfig.upkeepRewardPercent() / 100;
		}
	}
