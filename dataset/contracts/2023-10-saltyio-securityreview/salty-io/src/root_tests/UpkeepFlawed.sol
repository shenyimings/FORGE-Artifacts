// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "../price_feed/interfaces/IPriceAggregator.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../dao/interfaces/IDAOConfig.sol";
import "../pools/Counterswap.sol";
import "../rewards/interfaces/IEmissions.sol";
import "../pools/interfaces/IPoolStats.sol";
import "../staking/interfaces/ILiquidity.sol";
import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import "../Upkeep.sol";

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

contract UpkeepFlawed is Upkeep
    {
	using SafeERC20 for ISalt;
	using SafeERC20 for IUSDS;
	using SafeERC20 for IERC20;

	uint256 public flawedStep;


    constructor( IPools _pools, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IDAOConfig _daoConfig, IPriceAggregator _priceAggregator, ISaltRewards _saltRewards, ILiquidity _liquidity, IEmissions _emissions, uint256 _flawedStep )
    Upkeep(_pools, _exchangeConfig, _poolsConfig, _daoConfig, _priceAggregator, _saltRewards, _liquidity, _emissions)
		{
		flawedStep = _flawedStep;
		}


	// 1. Update the prices of BTC and ETH in the PriceAggregator.
	function _step1() public onlySameContract
		{
		require( flawedStep != 1, "Step 1 reverts" );
		this.step1();
		}


	// 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
	function _step2() public onlySameContract
		{
		require( flawedStep != 2, "Step 2 reverts" );
		this.step2();
		}


	// 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
	function _step3() public onlySameContract
		{
		require( flawedStep != 3, "Step 3 reverts" );
		this.step3();
		}


	// 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
	function _step4() public onlySameContract
		{
		require( flawedStep != 4, "Step 4 reverts" );
		this.step4();
		}


	// 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
	// The only WETH balance normally in the contract will be the WETH arbitrage profit that was withdrawn in step4
	function _step5( address receiver ) public onlySameContract
		{
		require( flawedStep != 5, "Step 5 reverts" );
		this.step5(receiver);
		}


	// 6. Send a default 10% (20% / 2) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
	function _step6() public onlySameContract
		{
		require( flawedStep != 6, "Step 6 reverts" );
		this.step6();
		}


	// 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
	function _step7() public onlySameContract
		{
		require( flawedStep != 7, "Step 7 reverts" );
		this.step7();
		}


	// 8. Withdraw SALT from previous counterswaps.
	function _step8() public onlySameContract
		{
//		console.log( "COUNTERSWAP SALT: ", salt.balanceOf(Counterswap.WETH_TO_SALT) );

		require( flawedStep != 8, "Step 8 reverts" );
		this.step8();
		}


	// 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
	function _step9() public onlySameContract
		{
//		console.log( "SALT REWARDS SALT step9: ", salt.balanceOf(address(saltRewards)) );
//		console.log( "UPKEEP SALT: ", salt.balanceOf( address(this) ) );
//		console.log( "UPKEEP USDS: ", usds.balanceOf( address(this) ) );

		require( flawedStep != 9, "Step 9 reverts" );
		this.step9();
		}


	// 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
	function _step10( uint256 daoStartingSaltBalance ) public onlySameContract
		{
//		console.log( "SALT REWARDS SALT step10: ", salt.balanceOf(address(saltRewards)) );
//		console.log( "DAO SALT: ", salt.balanceOf( address(exchangeConfig.dao()) ));
//		console.log( "daoStartingSaltBalance: ", daoStartingSaltBalance );

		require( flawedStep != 10, "Step 10 reverts" );
		this.step10(daoStartingSaltBalance);
		}


	// 11. Send SALT Emissions to the SaltRewards contract.
	function _step11( uint256 timeSinceLastUpkeep ) public onlySameContract
		{
//		console.log( "SALT REWARDS SALT step11: ", salt.balanceOf(address(saltRewards)) );
		require( flawedStep != 11, "Step 11 reverts" );
		this.step11(timeSinceLastUpkeep);
		}


	// 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
	function _step12( bytes32[] memory poolIDs) public onlySameContract
		{
//		console.log( "SALT REWARDS SALT step12: ", salt.balanceOf(address(saltRewards)) );
		require( flawedStep != 12, "Step 12 reverts" );
		this.step12(poolIDs);
		}


	// 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.
	function _step13( uint256 timeSinceLastUpkeep ) public onlySameContract
		{
//		console.log( "SALT REWARDS SALT step13: ", salt.balanceOf(address(saltRewards)) );
		require( flawedStep != 13, "Step 13 reverts" );
		this.step13(timeSinceLastUpkeep);
		}


	// 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
	function _step14() public onlySameContract
		{
//		console.log( "SALT REWARDS SALT step14: ", salt.balanceOf(address(saltRewards)) );
		require( flawedStep != 14, "Step 14 reverts" );
		this.step14();
		}


	// 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
	function _step15() public onlySameContract
		{
//		console.log( "SALT REWARDS SALT step15: ", salt.balanceOf(address(saltRewards)) );
		require( flawedStep != 15, "Step 15 reverts" );
		this.step15();
		}


	// 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
	// The teamVestingWallet vests to this contract - which is then transferred to the active teamWallet.
	function _step16() public onlySameContract
		{
//		console.log( "SALT REWARDS SALT step16: ", salt.balanceOf(address(saltRewards)) );
		require( flawedStep != 16, "Step 16 reverts" );
		this.step16();
		}


	// Perform the various steps of performUpkeep as outlined at the top of the contract.
	// Each step is wrapped in a try/catch and called using this.stepX() - with each stepX function requiring that the caller has to be this contract.
	// Uses a maximum of 755k gas with 100 whitelisted pools according to UpkeepGasUsage.t.sol
	function performFlawedUpkeep() public
		{
		require( block.timestamp >= lastUpkeepTime, "Cannot update with an earlier block.timestamp than lastUpkeepTime" );

		uint256 timeSinceLastUpkeep = block.timestamp - lastUpkeepTime;

		bytes32[] memory poolIDs = poolsConfig.whitelistedPools();

		// Perform the multiple steps to perform upkeep.
		// Try/catch blocks are used to prevent any of the steps (which are not independent from previous steps) from reverting the transaction.
 		try this._step1() {}
		catch (bytes memory error) { emit UpkeepError("Step 1", error); }

 		try this._step2() {}
		catch (bytes memory error) { emit UpkeepError("Step 2", error); }

 		try this._step3() {}
		catch (bytes memory error) { emit UpkeepError("Step 3", error); }

 		try this._step4() {}
		catch (bytes memory error) { emit UpkeepError("Step 4", error); }

 		try this._step5(msg.sender) {}
		catch (bytes memory error) { emit UpkeepError("Step 5", error); }

 		try this._step6() {}
		catch (bytes memory error) { emit UpkeepError("Step 6", error); }

 		try this._step7() {}
		catch (bytes memory error) { emit UpkeepError("Step 7", error); }

 		try this._step8() {}
		catch (bytes memory error) { emit UpkeepError("Step 8", error); }

		// Remember the DAO SALT balance before SALT is sent there to form POL
		// It will be assumed that that SALT should just stay in the contract and not be sent to the SaltRewards contract
		uint256 daoStartingSaltBalance = salt.balanceOf( address(exchangeConfig.dao()) );

 		try this._step9() {}
		catch (bytes memory error) { emit UpkeepError("Step 9", error); }

 		try this._step10(daoStartingSaltBalance) {}
		catch (bytes memory error) { emit UpkeepError("Step 10", error); }

 		try this._step11(timeSinceLastUpkeep) {}
		catch (bytes memory error) { emit UpkeepError("Step 11", error); }

 		try this._step12(poolIDs) {}
		catch (bytes memory error) { emit UpkeepError("Step 12", error); }

 		try this._step13(timeSinceLastUpkeep) {}
		catch (bytes memory error) { emit UpkeepError("Step 13", error); }

 		try this._step14() {}
		catch (bytes memory error) { emit UpkeepError("Step 14", error); }

 		try this._step15() {}
		catch (bytes memory error) { emit UpkeepError("Step 15", error); }

 		try this._step16() {}
		catch (bytes memory error) { emit UpkeepError("Step 16", error); }

		lastUpkeepTime = block.timestamp;
		}
	}
