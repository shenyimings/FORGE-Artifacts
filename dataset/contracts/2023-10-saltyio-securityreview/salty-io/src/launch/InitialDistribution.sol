// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../interfaces/ISalt.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../rewards/interfaces/ISaltRewards.sol";
import "../rewards/interfaces/IEmissions.sol";
import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import "./interfaces/IInitialDistribution.sol";
import "../staking/interfaces/ILiquidity.sol";
import "./interfaces/IAirdrop.sol";
import "./interfaces/IBootstrapBallot.sol";


contract InitialDistribution is IInitialDistribution
    {
	using SafeERC20 for ISalt;

	uint256 constant public MILLION_ETHER = 1000000 ether;


   	ISalt public salt;

	IPoolsConfig public poolsConfig;
   	IEmissions public emissions;
   	IBootstrapBallot public bootstrapBallot;
	IDAO public dao;
	VestingWallet public daoVestingWallet;
	VestingWallet public teamVestingWallet;
	IAirdrop public airdrop;
	ISaltRewards public saltRewards;
	ILiquidity public liquidity;


	constructor( ISalt _salt, IPoolsConfig _poolsConfig, IEmissions _emissions, IBootstrapBallot _bootstrapBallot, IDAO _dao, VestingWallet _daoVestingWallet, VestingWallet _teamVestingWallet, IAirdrop _airdrop, ISaltRewards _saltRewards, ILiquidity _liquidity  )
		{
		require( address(_salt) != address(0), "_salt cannot be address(0)" );

		require( address(_poolsConfig) != address(0), "_poolsConfig cannot be address(0)" );
		require( address(_emissions) != address(0), "_emissions cannot be address(0)" );
		require( address(_bootstrapBallot) != address(0), "_bootstrapBallot cannot be address(0)" );
		require( address(_dao) != address(0), "_dao cannot be address(0)" );
		require( address(_daoVestingWallet) != address(0), "_daoVestingWallet cannot be address(0)" );
		require( address(_teamVestingWallet) != address(0), "_teamVestingWallet cannot be address(0)" );
		require( address(_airdrop) != address(0), "_airdrop cannot be address(0)" );
		require( address(_saltRewards) != address(0), "_saltRewards cannot be address(0)" );
		require( address(_liquidity) != address(0), "_liquidity cannot be address(0)" );

		salt = _salt;

		poolsConfig = _poolsConfig;
		emissions = _emissions;
		bootstrapBallot = _bootstrapBallot;
		dao = _dao;
		daoVestingWallet = _daoVestingWallet;
		teamVestingWallet = _teamVestingWallet;
		airdrop = _airdrop;
		saltRewards = _saltRewards;
		liquidity = _liquidity;
        }


    // Called when the BootstrapBallot is approved by the initial airdrop recipients
    function distributionApproved() public
    	{
    	require( msg.sender == address(bootstrapBallot), "InitialDistribution.distributionApproved can only be called from the BootstrapBallot contract" );
		require( salt.balanceOf(address(this)) > 0, "SALT has already been sent from the contract" );

    	// 52 million		Emissions
		salt.safeTransfer( address(emissions), 52 * MILLION_ETHER );

	    // 25 million		DAO Reserve Vesting Wallet
		salt.safeTransfer( address(daoVestingWallet), 25 * MILLION_ETHER );

	    // 10 million		Initial Team Vesting Wallet
		salt.safeTransfer( address(teamVestingWallet), 10 * MILLION_ETHER );

	    // 5 million		Airdrop Participants
		salt.safeTransfer( address(airdrop), 5 * MILLION_ETHER );
		airdrop.allowClaiming();

		bytes32[] memory poolIDs = poolsConfig.whitelistedPools();

	    // 5 million		Liquidity Bootstrapping
	    // 3 million		Staking Bootstrapping
		salt.safeTransfer( address(saltRewards), 8 * MILLION_ETHER );
		saltRewards.sendInitialSaltRewards(5 * MILLION_ETHER, poolIDs );
    	}
	}