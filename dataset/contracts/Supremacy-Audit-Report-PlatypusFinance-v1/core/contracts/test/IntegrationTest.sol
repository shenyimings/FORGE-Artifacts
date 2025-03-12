// SPDX-License-Identifier: GPL-3.0
import '../asset/AggregateAccount.sol';
import '../asset/Asset.sol';
import '../pool/Pool.sol';
import './TestChainlinkAggregator.sol';
import '../oracle/ChainlinkProxyPriceProvider.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

pragma solidity 0.8.9;

/**
 * This is an integration test of deposit, withdraw, and swap.
 *
 * A pool of USDT and DAI is set up. The user bob will
 * deposit/withdraw/swap with these tokens.
 *
 * The goal is to make sure certain invariants hold. For example,
 * each asset's cash equals to its underlying token balance; and
 * each asset's liability are non-zero.
 */
contract IntegrationTest {
    MintableERC20 private usdt_;
    MintableERC20 private dai_;
    AggregateAccount private aggregateAccount_;
    Asset private usdt_asset_;
    Asset private dai_asset_;
    Pool private pool_;
    ChainlinkProxyPriceProvider private chainlink;
    TestChainlinkAggregator private mock_feed;

    address private bob_;
    uint256 private max_uint256 = 2**256 - 1;

    constructor() {
        // The pool has USDT, DAI, and USDC (and asset respectively) all in one aggregate account.
        pool_ = new Pool();
        // initialize pool
        pool_.initialize();

        usdt_ = new MintableERC20('Tether USD', 'USDT.e');
        dai_ = new MintableERC20('Dai', 'DAI.e');
        aggregateAccount_ = new AggregateAccount();
        aggregateAccount_.initialize('USD', true);
        usdt_asset_ = new Asset();
        usdt_asset_.initialize(address(usdt_), 'Platypus USDT Asset', 'platypus.USDT', address(aggregateAccount_));
        dai_asset_ = new Asset();
        dai_asset_.initialize(address(dai_), 'Platypus DAI Asset', 'platypus.DAI', address(aggregateAccount_));

        mock_feed = new TestChainlinkAggregator();
        mock_feed.setLatestAnswer(1e8, block.timestamp);
        address[] memory assetList_ = new address[](2);
        address[] memory mockFeeds_ = new address[](2);

        assetList_[0] = address(dai_);
        assetList_[1] = address(usdt_);

        mockFeeds_[0] = address(mock_feed);
        mockFeeds_[1] = address(mock_feed);

        chainlink = new ChainlinkProxyPriceProvider(assetList_, mockFeeds_);
        pool_.setPriceOracle(address(chainlink));

        init(pool_, usdt_, usdt_asset_);
        init(pool_, dai_, dai_asset_);

        // give bob some money and deposit initial liquidity.
        // note: internal transactions are called by this contract.
        bob_ = address(this);
        eassert(usdt_.mint(bob_, 10000));
        eassert(dai_.mint(bob_, 10000));
        eassert(usdt_.approve(bob_, address(pool_)));
        eassert(dai_.approve(bob_, address(pool_)));
        eassert(pool_.deposit(address(usdt_), 100, bob_, max_uint256) == 100);
        eassert(pool_.deposit(address(dai_), 9000, bob_, max_uint256) == 9000);
    }

    function init(
        Pool pool,
        ERC20 token,
        Asset asset
    ) internal {
        asset.setPool(address(pool));
        pool.addAsset(address(token), address(asset));
    }

    // work around for echidna 1.7 which doesn't support solidity 0.8 yet.
    // see https://github.com/crytic/echidna/issues/669
    event AssertionFailed();

    function eassert(bool succeed) internal {
        if (!succeed) {
            emit AssertionFailed();
        }
    }

    function depositUsdt(uint256 amount) public {
        eassert(pool_.deposit(address(usdt_), amount, bob_, max_uint256) >= 0);
    }

    function depositDai(uint256 amount) public {
        eassert(pool_.deposit(address(dai_), amount, bob_, max_uint256) >= 0);
    }

    function withdrawUsdt(uint256 amount) public {
        eassert(pool_.withdraw(address(usdt_), amount, 0, bob_, max_uint256) >= 0);
    }

    function withdrawDai(uint256 amount) public {
        eassert(pool_.withdraw(address(dai_), amount, 0, bob_, max_uint256) >= 0);
    }

    function withdrawUsdtFromDai(uint256 amount) public {
        eassert(pool_.withdrawFromOtherAsset(address(dai_), address(usdt_), amount, 0, bob_, max_uint256) >= 0);
    }

    function withdrawDaiFromUsdt(uint256 amount) public {
        eassert(pool_.withdrawFromOtherAsset(address(usdt_), address(dai_), amount, 0, bob_, max_uint256) >= 0);
    }

    function swapUsdt(uint256 amount) public {
        pool_.swap(address(usdt_), address(dai_), amount, 0, bob_, max_uint256);
    }

    function swapDai(uint256 amount) public {
        pool_.swap(address(dai_), address(usdt_), amount, 0, bob_, max_uint256);
    }

    function echidna_cash() public view returns (bool) {
        return
            usdt_asset_.cash() == usdt_asset_.underlyingTokenBalance() &&
            dai_asset_.cash() == dai_asset_.underlyingTokenBalance();
    }

    function echidna_total_supply() public view returns (bool) {
        return
            usdt_.totalSupply() == 10000 &&
            dai_.totalSupply() == 10000 &&
            usdt_.totalSupply() == usdt_.balanceOf(bob_) + usdt_asset_.underlyingTokenBalance() &&
            dai_.totalSupply() == dai_.balanceOf(bob_) + dai_asset_.underlyingTokenBalance();
    }

    // check system solvency
    function echidna_solvency() public view returns (bool) {
        return (usdt_asset_.cash() + dai_asset_.cash()) >= (usdt_asset_.liability() + dai_asset_.liability());
    }
}

contract MintableERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address account, uint256 amount) public returns (bool) {
        _mint(account, amount);
        return true;
    }

    function approve(address owner, address spender) public returns (bool) {
        _approve(owner, spender, 2**256 - 1);
        return true;
    }
}
