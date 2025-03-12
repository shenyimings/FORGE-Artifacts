// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../wallet/ShardedWallet.sol";
import "../../governance/IGovernance.sol";


contract BondingCurve {
	using SafeMath for uint256;

	uint256 internal _x;
	uint256 internal _k; // k = totalSupply^2 * initial price

	// bytes32 public constant PCT_FEE_SUPPLIERS = bytes32(uint256(keccak256("PCT_FEE_SUPPLIERS")) - 1);
	bytes32 public constant PCT_FEE_SUPPLIERS  = 0xe4f5729eb40e38b5a39dfb36d76ead9f9bc286f06852595980c5078f1af7e8c9;
	// bytes32 public constant PCT_FEE_ARTIST    = bytes32(uint256(keccak256("PCT_FEE_ARTIST")) - 1);
	bytes32 public constant PCT_FEE_ARTIST     = 0xdd0618e2e2a17ff193a933618181c8f8909dc169e9707cce1921893a88739ca0;
	// bytes32 public constant PCT_FEE_NIFTEX    = bytes32(uint256(keccak256("PCT_FEE_NIFTEX")) - 1);
	bytes32 public constant PCT_FEE_NIFTEX     = 0xcfb1dd89e6f4506eca597e7558fbcfe22dbc7e0b9f2b3956e121d0e344d6f7aa;
	// bytes32 public constant LIQUIDITY_TIMELOCK   = bytes32(uint256(keccak256("LIQUIDITY_TIMELOCK")) - 1);
	bytes32 public constant LIQUIDITY_TIMELOCK = 0x4babff57ebd34f251a515a845400ed950a51f0a64c92e803a3e144fc40623fa8;

	struct ethSuppliers {
		uint256 _totalSuppliedEthPlusFeesToSuppliers;
		uint256 _ethFeesToNiftex;
		uint256 _ethFeesToArtist;
		mapping(address => uint256) _mappingEthLPTokens;
		uint256 _totalEthLPTokens;
	}

	struct shardSuppliers {
		uint256 _totalSuppliedShardsPlusFeesToSuppliers;
		uint256 _shardFeesToNiftex;
		uint256 _shardFeesToArtist;
		mapping(address => uint256) _mappingShardLPTokens;
		uint256 _totalShardLPTokens;
	}

	struct shardedWalletDetails {
		address wallet;
		address recipient;
		uint256 timelockDeadline;
		uint256 decimals;
	}

	ethSuppliers internal _ethSuppliers;
	shardSuppliers internal _shardSuppliers;
	shardedWalletDetails internal _shardedWalletDetails;
	// uint256 internal _timelockDeadline;
	// address internal _recipient;
	event Initialized(address, address);
	event ShardsBought(uint256, uint256, address);
	event ShardsSold(uint256, uint256, address);
	event ShardsSupplied(uint256, address);
	event EtherSupplied(uint256, address);
	event ShardsWithdrawn(uint256, uint256, address);
	event EtherWithdrawn(uint256, uint256, address);
	event TransferEthLPTokens(address, address, uint256);
	event TransferShardLPTokens(address, address, uint256);

	function initialize(
		uint256 suppliedShards,
		address wallet, // shardedWallet instance
		address recipient, // recipient from crowdsale
		uint256 initialPriceInWei
	) public payable {
		require(_shardedWalletDetails.wallet == address(0));
		_shardedWalletDetails.wallet = wallet;
		_shardedWalletDetails.recipient = recipient;
		_shardedWalletDetails.timelockDeadline = block.timestamp.add(ShardedWallet(payable(_shardedWalletDetails.wallet)).governance().getConfig(_shardedWalletDetails.wallet, LIQUIDITY_TIMELOCK));
		_shardedWalletDetails.decimals = ShardedWallet(payable(_shardedWalletDetails.wallet)).decimals();
		// can create the bonding curve without transferring shards.
		if (suppliedShards > 0) {
			ShardedWallet(payable(_shardedWalletDetails.wallet)).transferFrom(msg.sender, address(this), suppliedShards);
		}

		_x = ShardedWallet(payable(_shardedWalletDetails.wallet)).totalSupply();
		_k = _x.mul(_x).mul(initialPriceInWei).div(10**_shardedWalletDetails.decimals);

		_shardSuppliers._mappingShardLPTokens[address(this)] = suppliedShards;
		_shardSuppliers._totalShardLPTokens = suppliedShards;
		_shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers = suppliedShards;

		_ethSuppliers._mappingEthLPTokens[address(this)] = msg.value;
		_ethSuppliers._totalEthLPTokens = msg.value;
		_ethSuppliers._totalSuppliedEthPlusFeesToSuppliers = msg.value;

		emit Initialized(_shardedWalletDetails.wallet, address(this));
	}

	function getExternalFee(uint256 _feeToNiftex, uint256 _feeToArtist, bool _hasArtistWallet) internal pure returns (uint256) {
		uint256 externalFees = _feeToNiftex;
		if (_hasArtistWallet) {
			externalFees = externalFees.add(_feeToArtist);
		}

		return externalFees;
	}

	// no need to add default fallback non-payable function in Solidity 0.8.0
	// address(this).balance will only be updated via specified function in this contract

	function buyShards(
		uint256 shardAmount,
		uint256 maxEthForShardAmount
	) public payable {
		uint256 y = _k.div(_x);

		uint256[3] memory fees;
		{
			IGovernance governance = ShardedWallet(payable(_shardedWalletDetails.wallet)).governance();
			address owner = ShardedWallet(payable(_shardedWalletDetails.wallet)).owner();
			// pause if someone else reclaimed the ownership of shardedWallet
			require(owner == address(0) || governance.isModule(_shardedWalletDetails.wallet, owner));

			fees[0] = governance.getConfig(_shardedWalletDetails.wallet, PCT_FEE_SUPPLIERS);
			fees[1] = governance.getConfig(_shardedWalletDetails.wallet, PCT_FEE_NIFTEX);
			fees[2] = governance.getConfig(_shardedWalletDetails.wallet, PCT_FEE_ARTIST);
		}

		bool hasArtistWallet = ShardedWallet(payable(_shardedWalletDetails.wallet)).artistWallet() != address(0);

		uint256 shardAmountAfterFee = shardAmount.mul(
			uint256(10**18)
			.add(fees[0])
			.add(getExternalFee(fees[1], fees[2], hasArtistWallet))
		).div(10**18);

		uint256 newXAfterFee = _x.sub(shardAmountAfterFee);
		uint256 newYAfterFee = _k.div(newXAfterFee);
		assert(newXAfterFee > 0);
		assert(newYAfterFee > 0);

		uint256 weiRequired = newYAfterFee.sub(y);

		require(
			maxEthForShardAmount >= weiRequired
		);

		require(
			ShardedWallet(payable(_shardedWalletDetails.wallet)).balanceOf(address(this)).sub(_shardSuppliers._shardFeesToNiftex).sub(_shardSuppliers._shardFeesToArtist) >= shardAmountAfterFee
		);

		require(
			weiRequired <= msg.value
		);

		_x = _x.sub(shardAmount.mul(
			uint256(10**18)
			.add(getExternalFee(fees[1], fees[2], hasArtistWallet))
		).div(10**18));

		_shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers = _shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers.add(shardAmount.mul(fees[0]).div(10**18));
		_shardSuppliers._shardFeesToNiftex = _shardSuppliers._shardFeesToNiftex.add(shardAmount.mul(fees[1]).div(10**18));
		if (hasArtistWallet) {
			_shardSuppliers._shardFeesToArtist = _shardSuppliers._shardFeesToArtist.add(shardAmount.mul(fees[2]).div(10**18));
		}

		ShardedWallet(payable(_shardedWalletDetails.wallet)).transfer(msg.sender, shardAmount);

		if (msg.value > weiRequired) {
			Address.sendValue(payable(msg.sender), msg.value.sub(weiRequired));
		}

		emit ShardsBought(shardAmount, weiRequired, msg.sender);
	}

	function sellShards(
		uint256 shardAmount,
		uint256 minEthForShardAmount
	) public {
		require(
			ShardedWallet(payable(_shardedWalletDetails.wallet)).balanceOf(msg.sender) >= shardAmount
		);

		uint256 y = _k.div(_x);

		IGovernance governance = ShardedWallet(payable(_shardedWalletDetails.wallet)).governance();
		address owner = ShardedWallet(payable(_shardedWalletDetails.wallet)).owner();

		// pause if someone else reclaimed the ownership of shardedWallet
		require(owner == address(0) || governance.isModule(_shardedWalletDetails.wallet, owner));

		uint256[3] memory fees;
		fees[0] = governance.getConfig(_shardedWalletDetails.wallet, PCT_FEE_SUPPLIERS);
		fees[1] = governance.getConfig(_shardedWalletDetails.wallet, PCT_FEE_NIFTEX);
		fees[2] = governance.getConfig(_shardedWalletDetails.wallet, PCT_FEE_ARTIST);

		bool hasArtistWallet = ShardedWallet(payable(_shardedWalletDetails.wallet)).artistWallet() != address(0);

		uint256 newX = _x.add(shardAmount);
		uint256 newY = _k.div(newX);
		assert(newY > 0);
		assert(newX > 0);

		uint256 weiPayout = y.sub(newY);

		require(
			weiPayout <= address(this).balance.sub(_ethSuppliers._ethFeesToNiftex).sub(_ethSuppliers._ethFeesToArtist)
		);

		_x = newX;

		_ethSuppliers._totalSuppliedEthPlusFeesToSuppliers = _ethSuppliers._totalSuppliedEthPlusFeesToSuppliers.add(weiPayout.mul(fees[0]).div(10**18));
		_ethSuppliers._ethFeesToNiftex = _ethSuppliers._ethFeesToNiftex.add(weiPayout.mul(fees[1]).div(10**18));
		if (hasArtistWallet) {
			_ethSuppliers._ethFeesToArtist = _ethSuppliers._ethFeesToArtist.add(weiPayout.mul(fees[2]).div(10**18));
		}

		weiPayout = weiPayout.mul(uint256(10**18)
			.sub(fees[0])
			.sub(getExternalFee(fees[1], fees[2], hasArtistWallet))
		).div(10**18);

		require(
			weiPayout >= minEthForShardAmount
		);

		require(ShardedWallet(payable(_shardedWalletDetails.wallet)).transferFrom(msg.sender, address(this), shardAmount));
		Address.sendValue(payable(msg.sender), weiPayout);

		emit ShardsSold(shardAmount, weiPayout, msg.sender);
	}

	function calcNewShardLPTokensToIssue(uint256 addedAmount) public view returns (uint256) {
		uint256 existingShardPool = _shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers;
		if (existingShardPool == 0) {
			return addedAmount;
		}
		uint256 proportion = addedAmount.mul(10**18).div(existingShardPool.add(addedAmount));
		uint256 newShardLPTokensToIssue = proportion.mul(_shardSuppliers._totalShardLPTokens).div(uint256(10**18).sub(proportion));
		return newShardLPTokensToIssue;
	}

	function calcNewEthLPTokensToIssue(uint256 addedAmount) public view returns (uint256) {
		uint256 existingEthPool = _ethSuppliers._totalSuppliedEthPlusFeesToSuppliers;
		if (existingEthPool == 0) {
			return addedAmount;
		}
		uint256 proportion = addedAmount.mul(10**18).div(existingEthPool.add(addedAmount));
		uint256 newEthLPTokensToIssue = proportion.mul(_ethSuppliers._totalEthLPTokens).div(uint256(10**18).sub(proportion));
		return newEthLPTokensToIssue;
	}

	function calcShardsForEthSuppliers() public view returns (uint256) {
		if (ShardedWallet(payable(_shardedWalletDetails.wallet)).balanceOf(address(this)).sub(_shardSuppliers._shardFeesToNiftex).sub(_shardSuppliers._shardFeesToArtist) < _shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers) {
			return 0;
		}

		return ShardedWallet(payable(_shardedWalletDetails.wallet)).balanceOf(address(this)).sub(_shardSuppliers._shardFeesToNiftex).sub(_shardSuppliers._shardFeesToArtist).sub(_shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers);
	}

	function calcEthForShardSuppliers() public view returns (uint256) {
		if (address(this).balance.sub(_ethSuppliers._ethFeesToNiftex).sub(_ethSuppliers._ethFeesToArtist) < _ethSuppliers._totalSuppliedEthPlusFeesToSuppliers) {
			return 0;
		}

		return address(this).balance.sub(_ethSuppliers._ethFeesToNiftex).sub(_ethSuppliers._ethFeesToArtist).sub(_ethSuppliers._totalSuppliedEthPlusFeesToSuppliers);
	}

	function supplyShards(uint256 shardAmount) external {
		require(
			ShardedWallet(payable(_shardedWalletDetails.wallet)).transferFrom(msg.sender, address(this), shardAmount)
		);

		require(
			_x >= shardAmount.add(_shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers)
		);

		uint256 newShardLPTokensToIssue = calcNewShardLPTokensToIssue(shardAmount);
		_shardSuppliers._mappingShardLPTokens[msg.sender] = _shardSuppliers._mappingShardLPTokens[msg.sender].add(newShardLPTokensToIssue);
		_shardSuppliers._totalShardLPTokens = _shardSuppliers._totalShardLPTokens.add(newShardLPTokensToIssue);
		_shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers = _shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers.add(shardAmount);


		emit ShardsSupplied(shardAmount, msg.sender);
	}

	function supplyEther() external payable {
		require(
			msg.value > 0
			);

		require(
			_k.div(_x) >= address(this).balance
		);

		uint256 newEthLPTokensToIssue = calcNewEthLPTokensToIssue(msg.value);
		_ethSuppliers._mappingEthLPTokens[msg.sender] = _ethSuppliers._mappingEthLPTokens[msg.sender].add(newEthLPTokensToIssue);
		_ethSuppliers._totalEthLPTokens = _ethSuppliers._totalEthLPTokens.add(newEthLPTokensToIssue);
		_ethSuppliers._totalSuppliedEthPlusFeesToSuppliers = _ethSuppliers._totalSuppliedEthPlusFeesToSuppliers.add(msg.value);

		emit EtherSupplied(msg.value, msg.sender);
	}

	function withdrawSuppliedShards(uint256 shardLPTokensAmount) external returns (uint256, uint256) {
		require(
			shardLPTokensAmount > 0
		);

		require(
			_shardSuppliers._mappingShardLPTokens[msg.sender] >= shardLPTokensAmount
		);

		uint256 shardsToWithdraw;
		if (ShardedWallet(payable(_shardedWalletDetails.wallet)).balanceOf(address(this)).sub(_shardSuppliers._shardFeesToNiftex).sub(_shardSuppliers._shardFeesToArtist) <= _shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers) {
			shardsToWithdraw = (ShardedWallet(payable(_shardedWalletDetails.wallet)).balanceOf(address(this)).sub(_shardSuppliers._shardFeesToNiftex).sub(_shardSuppliers._shardFeesToArtist)).mul(shardLPTokensAmount).div(_shardSuppliers._totalShardLPTokens);
		} else {
			shardsToWithdraw = _shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers.mul(shardLPTokensAmount).div(_shardSuppliers._totalShardLPTokens);
		}

		uint256 ethPayout = calcEthForShardSuppliers().mul(shardLPTokensAmount).div(_shardSuppliers._totalShardLPTokens);

		_shardSuppliers._mappingShardLPTokens[msg.sender] = _shardSuppliers._mappingShardLPTokens[msg.sender].sub(shardLPTokensAmount);
		_shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers = _shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers.mul(_shardSuppliers._totalShardLPTokens.sub(shardLPTokensAmount)).div(_shardSuppliers._totalShardLPTokens);
		_shardSuppliers._totalShardLPTokens = _shardSuppliers._totalShardLPTokens.sub(shardLPTokensAmount);


		ShardedWallet(payable(_shardedWalletDetails.wallet)).transfer(msg.sender, shardsToWithdraw);

		if (ethPayout > 0) {
			Address.sendValue(payable(msg.sender), ethPayout);
		}

		emit ShardsWithdrawn(ethPayout, shardsToWithdraw, msg.sender);

		return (ethPayout, shardsToWithdraw);
	}

	function withdrawSuppliedEther(uint256 ethLPTokensAmount) external returns (uint256, uint256) {
		require(
			ethLPTokensAmount > 0
		);

		require(
			_ethSuppliers._mappingEthLPTokens[msg.sender] >= ethLPTokensAmount
		);

		uint256 ethToWithdraw;
		if (address(this).balance.sub(_ethSuppliers._ethFeesToNiftex).sub(_ethSuppliers._ethFeesToArtist) <= _ethSuppliers._totalSuppliedEthPlusFeesToSuppliers) {
			ethToWithdraw = (address(this).balance.sub(_ethSuppliers._ethFeesToNiftex).sub(_ethSuppliers._ethFeesToArtist)).mul(ethLPTokensAmount).div(_ethSuppliers._totalEthLPTokens);
		} else {
			ethToWithdraw = _ethSuppliers._totalSuppliedEthPlusFeesToSuppliers.mul(ethLPTokensAmount).div(_ethSuppliers._totalEthLPTokens);
		}

		uint256 shardPayout = calcShardsForEthSuppliers().mul(ethLPTokensAmount).div(_ethSuppliers._totalEthLPTokens);

		_ethSuppliers._mappingEthLPTokens[msg.sender] = _ethSuppliers._mappingEthLPTokens[msg.sender].sub(ethLPTokensAmount);
		_ethSuppliers._totalSuppliedEthPlusFeesToSuppliers = _ethSuppliers._totalSuppliedEthPlusFeesToSuppliers.mul(_ethSuppliers._totalEthLPTokens.sub(ethLPTokensAmount)).div(_ethSuppliers._totalEthLPTokens);
		_ethSuppliers._totalEthLPTokens = _ethSuppliers._totalEthLPTokens.sub(ethLPTokensAmount);

		Address.sendValue(payable(msg.sender), ethToWithdraw);

		if (shardPayout > 0) {
			ShardedWallet(payable(_shardedWalletDetails.wallet)).transfer(msg.sender, shardPayout);
		}

		emit EtherWithdrawn(ethToWithdraw, shardPayout, msg.sender);

		return (ethToWithdraw, shardPayout);
	}

	function transferShardLPTokens(uint256 shardLPTokensAmount, address recipient) public {
		require(
			_shardSuppliers._mappingShardLPTokens[msg.sender] >= shardLPTokensAmount
		);

		_shardSuppliers._mappingShardLPTokens[msg.sender] = _shardSuppliers._mappingShardLPTokens[msg.sender].sub(shardLPTokensAmount);
		_shardSuppliers._mappingShardLPTokens[recipient] = _shardSuppliers._mappingShardLPTokens[recipient].add(shardLPTokensAmount);

		emit TransferShardLPTokens(msg.sender, recipient, shardLPTokensAmount);
	}

	function transferEthLPTokens(uint256 ethLPTokensAmount, address recipient) public {
		require(
			_ethSuppliers._mappingEthLPTokens[msg.sender] >= ethLPTokensAmount
		);

		_ethSuppliers._mappingEthLPTokens[msg.sender] = _ethSuppliers._mappingEthLPTokens[msg.sender].sub(ethLPTokensAmount);
		_ethSuppliers._mappingEthLPTokens[recipient] = _ethSuppliers._mappingEthLPTokens[recipient].add(ethLPTokensAmount);

		emit TransferEthLPTokens(msg.sender, recipient, ethLPTokensAmount);
	}

	function withdrawNiftexOrArtistFees(address recipient) public {
		require(
			msg.sender == ShardedWallet(payable(_shardedWalletDetails.wallet)).artistWallet() ||
			msg.sender == ShardedWallet(payable(_shardedWalletDetails.wallet)).governance().getNiftexWallet()
		);

		uint256 shardFees;
		uint256 ethFees;

		if (msg.sender == ShardedWallet(payable(_shardedWalletDetails.wallet)).artistWallet()) {
			shardFees = _shardSuppliers._shardFeesToArtist;
			ethFees = _ethSuppliers._ethFeesToArtist;

			_shardSuppliers._shardFeesToArtist = 0;
			_ethSuppliers._ethFeesToArtist = 0;
		} else if (msg.sender == ShardedWallet(payable(_shardedWalletDetails.wallet)).governance().getNiftexWallet()) {
			shardFees = _shardSuppliers._shardFeesToNiftex;
			ethFees = _ethSuppliers._ethFeesToNiftex;

			_shardSuppliers._shardFeesToNiftex = 0;
			_ethSuppliers._ethFeesToNiftex = 0;
		}

		Address.sendValue(payable(recipient), ethFees);

		ShardedWallet(payable(_shardedWalletDetails.wallet)).transfer(recipient, shardFees);
	}

	function transferTimelockLiquidity() public {
		address recipient = _shardedWalletDetails.recipient;

		require(block.timestamp > _shardedWalletDetails.timelockDeadline);
		require(_shardSuppliers._mappingShardLPTokens[address(this)] > 0 || _ethSuppliers._mappingEthLPTokens[address(this)] >0);

		_shardSuppliers._mappingShardLPTokens[recipient] = _shardSuppliers._mappingShardLPTokens[recipient].add(_shardSuppliers._mappingShardLPTokens[address(this)]);
		_ethSuppliers._mappingEthLPTokens[recipient] = _ethSuppliers._mappingEthLPTokens[recipient].add(_ethSuppliers._mappingEthLPTokens[address(this)]);

		_shardSuppliers._mappingShardLPTokens[address(this)] = 0;
		_ethSuppliers._mappingEthLPTokens[address(this)] = 0;
	}

	function getCurrentPrice() external view returns (uint256) {
		return _k.mul(10**_shardedWalletDetails.decimals).div(_x).div(_x);
	}

	function getCurveCoordinates() external view returns (uint256, uint256) {
		return (_x, _k);
	}

	function getEthSuppliers() external view returns (uint256, uint256, uint256, uint256) {
		return (_ethSuppliers._totalSuppliedEthPlusFeesToSuppliers, _ethSuppliers._totalEthLPTokens, _ethSuppliers._ethFeesToNiftex, _ethSuppliers._ethFeesToArtist);
	}

	function getShardSuppliers() external view returns (uint256, uint256, uint256, uint256) {
		return (_shardSuppliers._totalSuppliedShardsPlusFeesToSuppliers, _shardSuppliers._totalShardLPTokens, _shardSuppliers._shardFeesToNiftex, _shardSuppliers._shardFeesToArtist);
	}

	function getEthLPTokens(address owner) public view returns (uint256) {
		return _ethSuppliers._mappingEthLPTokens[owner];
	}

	function getShardLPTokens(address owner) public view returns (uint256) {
		return _shardSuppliers._mappingShardLPTokens[owner];
	}

	function decimals() public view returns (uint256) {
		return _shardedWalletDetails.decimals;
	}

	function getEthInPool() public view returns (uint256) {
		return address(this).balance;
	}
}
