// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "../stable/USDS.sol";
import "../stable/interfaces/IStableConfig.sol";
import "../price_feed/interfaces/IPriceAggregator.sol";
import "../staking/interfaces/IStakingConfig.sol";
import "../staking/interfaces/IStaking.sol";
import "../staking/Staking.sol";
import "../staking/interfaces/ILiquidity.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../rewards/Emissions.sol";
import "../dao/interfaces/IDAOConfig.sol";
import "../dao/interfaces/IDAO.sol";
import "../dao/interfaces/IProposals.sol";
import "../price_feed/tests/IForcedPriceFeed.sol";
import "../launch/interfaces/IBootstrapBallot.sol";
import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import "../launch/interfaces/IAirdrop.sol";
import "../dao/Proposals.sol";
import "../dao/DAO.sol";
import "../AccessManager.sol";
import "../rewards/SaltRewards.sol";
import "../launch/InitialDistribution.sol";
import "../pools/PoolsConfig.sol";
import "../ExchangeConfig.sol";
import "../price_feed/PriceAggregator.sol";
import "../pools/Pools.sol";
import "../staking/Liquidity.sol";
import "../stable/Collateral.sol";
import "../rewards/RewardsEmitter.sol";
import "../root_tests/TestERC20.sol";
import "../launch/Airdrop.sol";
import "../launch/BootstrapBallot.sol";


// Stores the contract addresses for the various parts of the exchange and allows the unit tests to be run on them.

contract Deployment is Test
    {
    bool public DEBUG = true;
	address constant public DEPLOYER = 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF;

	// Test addresses on Sepolia for the Price Feeds
	address public CHAINLINK_BTC_USD = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
	address public CHAINLINK_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
	address public UNISWAP_V3_BTC_ETH = 0xC27D6ACC8560F24681BC475953F27C5F71668448;
	address public UNISWAP_V3_USDC_ETH = 0x9014aE623A76499A0f9F326e95f66fc800bF651d;
	IERC20 public _testBTC = IERC20(0xd4C3cc58E46C99fbA0c4e4d93C82AE32000cc4D4);
	IERC20 public _testETH = IERC20(0xcEBB1DB86DFc17563385b394CbD968CBd3B46F2A);
	IERC20 public _testUSDC = IERC20(0x9C65b1773A95d607f41fa205511cd3327cc39D9D);
	IForcedPriceFeed public forcedPriceFeed = IForcedPriceFeed(address(0x3B0Eb37f26b502bAe83df4eCc54afBDfb90B5d3a));

	// The DAO contract can provide us with all other contract addresses in the protocol
	IDAO public dao = IDAO(address(0xde9d40127E8cA0222f82d7C5283D43Cb217fc6E5));

	IExchangeConfig public exchangeConfig = IExchangeConfig(getContract(address(dao), "exchangeConfig()" ));
	IPoolsConfig public poolsConfig = IPoolsConfig(getContract(address(dao), "poolsConfig()" ));
	IStakingConfig public stakingConfig = IStakingConfig(getContract(address(dao), "stakingConfig()" ));
	IStableConfig public stableConfig = IStableConfig(getContract(address(dao), "stableConfig()" ));
	IRewardsConfig public rewardsConfig = IRewardsConfig(getContract(address(dao), "rewardsConfig()" ));
	IDAOConfig public daoConfig = IDAOConfig(getContract(address(dao), "daoConfig()" ));
	IPriceAggregator public priceAggregator = IPriceAggregator(getContract(address(dao), "priceAggregator()" ));

	address public teamWallet = exchangeConfig.teamWallet();
	IUpkeep public upkeep = exchangeConfig.upkeep();
	IEmissions public emissions = IEmissions(getContract(address(upkeep), "emissions()" ));

	ISalt public salt = exchangeConfig.salt();
    IERC20 public wbtc = exchangeConfig.wbtc();
    IERC20 public weth = exchangeConfig.weth();
    IERC20 public dai = exchangeConfig.dai();
    USDS public usds = USDS(address(exchangeConfig.usds()));

	IRewardsEmitter public stakingRewardsEmitter = IRewardsEmitter(getContract(address(exchangeConfig), "stakingRewardsEmitter()" ));
	IRewardsEmitter public liquidityRewardsEmitter = IRewardsEmitter(getContract(address(exchangeConfig), "liquidityRewardsEmitter()" ));

	IStaking public staking = IStaking(getContract(address(stakingRewardsEmitter), "stakingRewards()" ));
	ILiquidity public liquidity = ILiquidity(getContract(address(liquidityRewardsEmitter), "stakingRewards()" ));
	ICollateral public collateral = ICollateral(getContract(address(usds), "collateral()" ));

	IPools public pools = IPools(getContract(address(collateral), "pools()" ));

	IProposals public proposals = IProposals(getContract(address(dao), "proposals()" ));

	ISaltRewards public saltRewards = ISaltRewards(getContract(address(upkeep), "saltRewards()" ));
	IAccessManager public accessManager = exchangeConfig.accessManager();

	VestingWallet public daoVestingWallet = VestingWallet(payable(exchangeConfig.daoVestingWallet()));
	VestingWallet public teamVestingWallet = VestingWallet(payable(exchangeConfig.teamVestingWallet()));

	IInitialDistribution public initialDistribution = exchangeConfig.initialDistribution();
	IAirdrop public airdrop = IAirdrop(getContract(address(initialDistribution), "airdrop()" ));
	IBootstrapBallot public bootstrapBallot = IBootstrapBallot(getContract(address(initialDistribution), "bootstrapBallot()" ));


	function getContract( address _contract, string memory _functionName ) public returns (address result) {
		bytes4 FUNC_SELECTOR = bytes4(keccak256( bytes(_functionName) ));

		bytes memory data = abi.encodeWithSelector(FUNC_SELECTOR );

		uint256 remainingGas = gasleft();

		bool success;
		bytes memory output = new bytes(32);  // Initialize an output buffer

		assembly {
			success := call(
				remainingGas,            // gas remaining
				_contract,               // destination address
				0,                       // no ether
				add(data, 32),           // input buffer (starts after the first 32 bytes in the `data` array)
				mload(data),             // input length (loaded from the first 32 bytes in the `data` array)
				add(output, 32),         // output buffer
				32                       // output length is 32 bytes because address is 20 bytes
			)
		}

		require(success, "External call failed");

		// Cast bytes to address
		result = abi.decode(output, (address));
		}


	function initializeContracts() public
		{
//		console.log( "DEFAULT: ", address(this) );

		// Transfer the salt from the original initialDistribution to the DEPLOYER
		vm.prank(address(initialDistribution));
		salt.transfer(DEPLOYER, 100000000 ether);

		vm.startPrank(DEPLOYER);

		poolsConfig = new PoolsConfig();
		usds = new USDS(wbtc, weth);

		exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet );

		priceAggregator = new PriceAggregator();
		priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );

		pools = new Pools(exchangeConfig, poolsConfig);
		staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
		liquidity = new Liquidity( pools, exchangeConfig, poolsConfig, stakingConfig );
		collateral = new Collateral(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator);

		stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig );
		liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, rewardsConfig );

		saltRewards = new SaltRewards(exchangeConfig, rewardsConfig);
		emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

		poolsConfig.whitelistPool(pools, salt, wbtc);
		poolsConfig.whitelistPool(pools, salt, weth);
		poolsConfig.whitelistPool(pools, salt, usds);
		poolsConfig.whitelistPool(pools, wbtc, usds);
		poolsConfig.whitelistPool(pools, weth, usds);
		poolsConfig.whitelistPool(pools, wbtc, dai);
		poolsConfig.whitelistPool(pools, weth, dai);
		poolsConfig.whitelistPool(pools, usds, dai);
		poolsConfig.whitelistPool(pools, wbtc, weth);

		proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

		address oldDAO = address(dao);
		dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter);

		airdrop = new Airdrop(exchangeConfig, staking);

		accessManager = new AccessManager(dao);

		exchangeConfig.setAccessManager( accessManager );
		exchangeConfig.setStakingRewardsEmitter( stakingRewardsEmitter);
		exchangeConfig.setLiquidityRewardsEmitter( liquidityRewardsEmitter);
		exchangeConfig.setDAO( dao );
		exchangeConfig.setAirdrop(airdrop);

		upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);
		exchangeConfig.setUpkeep(upkeep);

		daoVestingWallet = new VestingWallet( address(dao), uint64(block.timestamp + 60 * 60 * 24 * 7), 60 * 60 * 24 * 365 * 10 );
		teamVestingWallet = new VestingWallet( address(upkeep), uint64(block.timestamp + 60 * 60 * 24 * 7), 60 * 60 * 24 * 365 * 10 );
		exchangeConfig.setVestingWallets(address(teamVestingWallet), address(daoVestingWallet));

		bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop, 60 * 60 * 24 * 3 );
		initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, liquidity);
		exchangeConfig.setInitialDistribution(initialDistribution);

		pools.setDAO(dao);


		usds.setContracts(collateral, pools, exchangeConfig );

		// Transfer ownership of the newly created config files to the DAO
		Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
		Ownable(address(poolsConfig)).transferOwnership( address(dao) );
		Ownable(address(priceAggregator)).transferOwnership(address(dao));
		vm.stopPrank();

		vm.startPrank(address(oldDAO));
		Ownable(address(stakingConfig)).transferOwnership( address(dao) );
		Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
		Ownable(address(stableConfig)).transferOwnership( address(dao) );
		Ownable(address(daoConfig)).transferOwnership( address(dao) );
		vm.stopPrank();

		// Move the SALT to the new initialDistribution contract
		vm.prank(DEPLOYER);
		salt.transfer(address(initialDistribution), 100000000 ether);
		}


	function grantAccessAlice() public
		{
		bytes memory sig = abi.encodePacked(hex"4f69e68f57bbd5d369c62eaf3e2bf4ab8f34ba5c0b3a782303e71664149fef4d0b7c9426a932c9c7f5b8e1186e193ebacc929651ad95130de9f1b306e5ef913e1c");

		vm.prank( address(0x1111) );
		accessManager.grantAccess(sig);
		}


	function grantAccessBob() public
		{
		bytes memory sig = abi.encodePacked(hex"9692bd8568d725621e169001b02c11bc3ef89bb195bc04758b16db4e02422b423400ce4729dd2896998f5e4fcd500704859039d642ab2818fc3ba7d69df97b3b1b");

		vm.prank( address(0x2222) );
		accessManager.grantAccess(sig);
		}


	function grantAccessCharlie() public
		{
		bytes memory sig = abi.encodePacked(hex"4440eb129ab41dd8cf12baa0366ce7c54bc10d185450830745d7eb6ee3a680231edd64db7c2df80b5988ef2880274f91b1df2a24a77d8b9176325ee13091e3741c");

		vm.prank( address(0x3333) );
		accessManager.grantAccess(sig);
		}


	function grantAccessDeployer() public
		{
		bytes memory sig = abi.encodePacked(hex"7b562514293d56c3cf7012eb63b771846d6a44f9195c0b94d2d340fae9e31e82366ebec63b0e52f8a385fe754f88150ae1defc979351cda7bd45123a0b1445481c");

		vm.prank( 0x73107dA86708c2DAd0D91388fB057EeE3E2581aF );
		accessManager.grantAccess(sig);
		}


	function grantAccessDefault() public
		{
		bytes memory sig = abi.encodePacked(hex"a32e7c2d1b0d660c7051f2586d5370dc2bb034cf6cfbec76a0126077758189b328c3312eaf1b0ef03b854819c82c239d7eca596eb5e35cd29a5de78855c53c301b");

		vm.prank( 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496 );
		accessManager.grantAccess(sig);
		}


	function whitelistAlice() public
		{
		vm.prank( address(bootstrapBallot) );
		airdrop.authorizeWallet(address(0x1111));
		}


	function whitelistBob() public
		{
		vm.prank( address(bootstrapBallot) );
		airdrop.authorizeWallet(address(0x2222));
		}


	function whitelistCharlie() public
		{
		vm.prank( address(bootstrapBallot) );
		airdrop.authorizeWallet(address(0x3333));
		}


	function finalizeBootstrap() public
		{
		address alice = address(0x1111);
		address bob = address(0x2222);

		whitelistAlice();
		whitelistBob();

		// Voting stage (yesVotes: 2, noVotes: 0)
		uint256[] memory regionalVotes = new uint256[](5);


		bytes memory sig = abi.encodePacked(hex"53d24a49fc79e56ebcfc268dac964bb50beabe79024eda84158c5826428092fc3122b2dcc20e23109a3e44a7356bacedcda41214562801eebdf7695ec08c80b31b");
		vm.startPrank(alice);
		bootstrapBallot.vote(true, regionalVotes, sig);
		vm.stopPrank();

		sig = abi.encodePacked(hex"98ea2c8a10e4fc75b13147210b54aaaf5d45922fa576ca9968db642afa6241b100bcb8139fd7f4fce46b028a68941769f70b3085375c9ae22d69d80fc35f90551c");
		vm.startPrank(bob);
		bootstrapBallot.vote(true, regionalVotes, sig);
		vm.stopPrank();

		// Increase current blocktime to be greater than completionTimestamp
		vm.warp( bootstrapBallot.completionTimestamp() + 1);

		// Call finalizeBallot()
		bootstrapBallot.finalizeBallot();
		}
	}