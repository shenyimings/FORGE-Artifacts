pragma solidity >=0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "../auction/StakedTokenAuctionHouse.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
    function roll(uint256) virtual public;
}

contract Caller {
    StakedTokenAuctionHouse target;

    constructor (StakedTokenAuctionHouse target_) public {
        target = target_;
    }

    function doModifyParameters(bytes32 param, uint256 data) public {
        target.modifyParameters(param, data);
    }

    function doModifyParameters(bytes32 param, address data) public {
        target.modifyParameters(param, data);
    }

    function doAddAuthorization(address data) public {
        target.addAuthorization(data);
    }

    function doRemoveAuthorization(address data) public {
        target.removeAuthorization(data);
    }
}

contract SAFEEngineMock {
    event TransferInternalCoins(address indexed src, address indexed dst, uint256 rad);

    mapping (address => uint256)                       public coinBalance;      // [rad]
    // Amount of debt held by an account. Coins & debt are like matter and antimatter. They nullify each other
    mapping (address => uint256)                       public debtBalance;      // [rad]

    function modifyBalance(bytes32 param, address who, uint val) public {
        if (param == "coin") coinBalance[who] = val;
        else if (param == "debt") debtBalance[who] = val;
        else revert("unrecognized param");
    }

    function addition(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "SAFEEngine/add-uint-uint-overflow");
    }
    function subtract(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "SAFEEngine/sub-uint-uint-underflow");
    }

    function transferInternalCoins(address src, address dst, uint256 rad) external {
        coinBalance[src] = subtract(coinBalance[src], rad);
        coinBalance[dst] = addition(coinBalance[dst], rad);
        emit TransferInternalCoins(src, dst, rad);
    }
}

contract AccountingEngineMock {
    uint public totalOnAuctionDebt = 0;

    function setTotalOnAuctionDebt(uint val) public {
        totalOnAuctionDebt = val;
    }

    function cancelAuctionedDebtWithSurplus(uint val) public {
        totalOnAuctionDebt = (totalOnAuctionDebt - val > totalOnAuctionDebt) ? 0 : totalOnAuctionDebt - val;
    }
}

contract StakedTokenAuctionHouseTest is DSTest {
    Hevm hevm;

    StakedTokenAuctionHouse auctionHouse;
    DSToken prot;
    Caller unauth;
    SAFEEngineMock safeEngine;
    AccountingEngineMock accountingEngine;

    // uint256 initTokenAmount = 100 ether;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        // Create token
        prot = new DSToken("FLX", "FLX");

        safeEngine = new SAFEEngineMock();

        auctionHouse = new StakedTokenAuctionHouse(
            address(safeEngine),
            address(prot)
        );

        accountingEngine = new AccountingEngineMock();

        auctionHouse.modifyParameters("accountingEngine", address(accountingEngine));

        unauth = new Caller(auctionHouse);

        prot.approve(address(auctionHouse), uint(-1));
        prot.mint(address(this), 100000 ether);

        safeEngine.modifyBalance("coin", address(this), 300 ether);

        auctionHouse.startAuction(
            10 ether,
            100 ether
        );
    }

    // --- Tests ---
    function test_correct_setup() public {
        assertEq(address(auctionHouse.safeEngine()), address(safeEngine));
        assertEq(address(auctionHouse.stakedToken()), address(prot));
        assertEq(auctionHouse.contractEnabled(), 1);
        assertEq(auctionHouse.authorizedAccounts(address(this)), 1);
        assertEq(prot.balanceOf(address(auctionHouse)), 10 ether);
    }

    function testFail_setup_null_safeEngine() public {
        auctionHouse = new StakedTokenAuctionHouse(
            address(0),
            address(prot)
        );
    }

    function testFail_setup_null_token() public {
        auctionHouse = new StakedTokenAuctionHouse(
            address(safeEngine),
            address(0)
        );
    }

    function test_add_authorization() public {
        auctionHouse.addAuthorization(address(0xfab));
        assertEq(auctionHouse.authorizedAccounts(address(0xfab)), 1);
    }

    function test_remove_authorization() public {
        auctionHouse.removeAuthorization(address(this));
        assertEq(auctionHouse.authorizedAccounts(address(this)), 0);
    }

    function testFail_add_authorization_unauthorized() public {
        unauth.doAddAuthorization(address(0xfab));
    }

    function testFail_remove_authorization_unauthorized() public {
        unauth.doRemoveAuthorization(address(this));
    }

    function test_modify_parameters() public {
        auctionHouse.modifyParameters("bidIncrease", 2 ether);
        assertEq(auctionHouse.bidIncrease(), 2 ether);

        auctionHouse.modifyParameters("bidDuration", 1 weeks);
        assertEq(uint(auctionHouse.bidDuration()), 1 weeks);

        auctionHouse.modifyParameters("totalAuctionLength", 4 hours);
        assertEq(uint(auctionHouse.totalAuctionLength()), 4 hours);

        auctionHouse.modifyParameters("minBidDecrease", 1000);
        assertEq(auctionHouse.minBidDecrease(), 1000);

        auctionHouse.modifyParameters("minBid", 3 ether);
        assertEq(auctionHouse.minBid(), 3 ether);



        auctionHouse.modifyParameters("accountingEngine", address(0xbeef));
        assertEq(address(auctionHouse.accountingEngine()), address(0xbeef));

        auctionHouse.modifyParameters("tokenBurner", address(0xbeef));
        assertEq(address(auctionHouse.tokenBurner()), address(0xbeef));
    }

    function testFail_modify_parameters_invalid_uint() public {
        auctionHouse.modifyParameters("bidIncrease", 0);
    }

    function testFail_modify_parameters_invalid_bid_increase() public {
        auctionHouse.modifyParameters("bidIncrease", 1 ether);
    }

    function testFail_modify_parameters_invalid_Min_bid_increase() public {
        auctionHouse.modifyParameters("minBidDecrease", 1 ether);
    }

    function testFail_modify_parameters_invalid_param_address() public {
        auctionHouse.modifyParameters("invalid", address(1));
    }

    function testFail_modify_parameters_invalid_param_uint() public {
        auctionHouse.modifyParameters("invalid", 1);
    }

    function testFail_modify_parameters_unauthorized_address() public {
        unauth.doModifyParameters("tokenBurner", address(1));
    }

    function testFail_modify_parameters_unauthorized_uint() public {
        unauth.doModifyParameters("rewardPerBlock", 5 ether);
    }

    function test_start_auction() public {
        assertEq(auctionHouse.auctionsStarted(), 1);
        (uint256 bidAmount, uint256 amountToSell, address highBidder,, uint48  auctionDeadline) =
                auctionHouse.bids(1);

        assertEq(amountToSell, 10 ether);
        assertEq(bidAmount, 100 ether);
        assertEq(highBidder, address(0));
        assertEq(auctionDeadline, now + auctionHouse.totalAuctionLength());
        assertEq(auctionHouse.activeStakedTokenAuctions(), 1);
    }

    function testFail_start_auction_disabled() public {
        auctionHouse.disableContract();
        auctionHouse.startAuction(
            10 ether,
            100 ether
        );
    }

    function testFail_start_auction_null_accounting_engine() public {
        auctionHouse.modifyParameters("accountingEngine", address(0));
        auctionHouse.startAuction(
            10 ether,
            100 ether
        );
    }

    function testFail_start_auction_null_amount_to_sell() public {
        auctionHouse.startAuction(
            0,
            100 ether
        );
    }

    function testFail_start_auction_null_coins_requested() public {
        auctionHouse.startAuction(
            10 ether,
            0
        );
    }

    function testFail_start_auction_invalid_coins_requested() public {
        auctionHouse.startAuction(
            10 ether,
            (uint256(-1) / 1 ether) + 1
        );
    }

    function test_restart_auction() public {
        hevm.warp(now + auctionHouse.totalAuctionLength() + 1);

        auctionHouse.restartAuction(1);

        (uint256 bidAmount,,,, uint48  auctionDeadline) =
                auctionHouse.bids(1);

        assertEq(bidAmount, 95 ether);
        assertEq(auctionDeadline, now + auctionHouse.totalAuctionLength());
    }

    function testFail_restart_auction_before_finish() public {
        hevm.warp(now + auctionHouse.totalAuctionLength());

        auctionHouse.restartAuction(1);
    }

    function testFail_restart_auction_invalid() public {
        auctionHouse.restartAuction(66);
    }

    function testFail_restart_already_bid() public {
        auctionHouse.increaseBidSize(1, 10 ether, 105.1 ether);
        hevm.warp(now + auctionHouse.totalAuctionLength() + 1);

        auctionHouse.restartAuction(1);
    }

    function test_increase_bid_size() public {
        auctionHouse.increaseBidSize(1, 10 ether, 105.1 ether);
        (uint256 bidAmount, uint256 amountToSell, address highBidder, uint48 bidExpiry, uint48 auctionDeadline) =
                auctionHouse.bids(1);

        assertEq(amountToSell, 10 ether);
        assertEq(bidAmount, 105.1 ether);
        assertEq(highBidder, address(this));
        assertEq(auctionHouse.activeStakedTokenAuctions(), 1);
        assertEq(bidExpiry, now + auctionHouse.bidDuration());
        assertEq(safeEngine.coinBalance(address(auctionHouse)), 105.1 ether);

        auctionHouse.increaseBidSize(1, 10 ether, 112 ether);
        (bidAmount, amountToSell, highBidder,  bidExpiry, auctionDeadline) =
                auctionHouse.bids(1);

        assertEq(amountToSell, 10 ether);
        assertEq(bidAmount, 112 ether);
        assertEq(highBidder, address(this));
        assertEq(auctionHouse.activeStakedTokenAuctions(), 1);
        assertEq(bidExpiry, now + auctionHouse.bidDuration());
        assertEq(safeEngine.coinBalance(address(auctionHouse)), 112 ether);
    }

    function testFail_increase_bid_size_disabled() public {
        auctionHouse.disableContract();
        auctionHouse.increaseBidSize(1, 10 ether, 105.1 ether);
    }

    function testFail_increase_bid_size_finished() public {
        hevm.warp(now + auctionHouse.totalAuctionLength() + 1);
        auctionHouse.increaseBidSize(1, 10 ether, 105.1 ether);
    }

    function testFail_increase_bid_size_expired() public {
        auctionHouse.increaseBidSize(1, 10 ether, 105.1 ether);
        hevm.warp(now + auctionHouse.bidDuration() + 1);
        auctionHouse.increaseBidSize(1, 10 ether, 112 ether);
    }

    function testFail_increase_bid_size_invalid_amountToBuy() public {
        auctionHouse.increaseBidSize(1, 10.11 ether, 105.1 ether);
    }

    function testFail_increase_bid_size_insufficient_increase() public {
        auctionHouse.increaseBidSize(1, 10 ether, 105 ether);
    }

    function test_settle_auction() public {
        auctionHouse.increaseBidSize(1, 10 ether, 105.1 ether);
        (,,, uint48 bidExpiry,) = auctionHouse.bids(1);

        hevm.warp(bidExpiry + 1);
        uint previousBalance = prot.balanceOf(address(this));
        auctionHouse.settleAuction(1);
        assertEq(auctionHouse.activeStakedTokenAuctions(), 0);

        assertEq(safeEngine.coinBalance(address(auctionHouse)), 0);
        assertEq(safeEngine.coinBalance(address(accountingEngine)), 105.1 ether);
        assertEq(prot.balanceOf(address(this)), previousBalance + 10 ether);

    }

    function testFail_settle_auction_early() public {
        auctionHouse.increaseBidSize(1, 10 ether, 105.1 ether);
        (,,, uint48 bidExpiry,) = auctionHouse.bids(1);

        hevm.warp(bidExpiry - 1);
        auctionHouse.settleAuction(1);
    }

    function testFail_settle_auction_disabled() public {
        auctionHouse.increaseBidSize(1, 10 ether, 105.1 ether);
        (,,, uint48 bidExpiry,) = auctionHouse.bids(1);

        hevm.warp(bidExpiry + 1);
        auctionHouse.disableContract();
        auctionHouse.settleAuction(1);
    }

    function testFail_settle_auction_no_bids() public {
        (,,,, uint auctionDeadline) = auctionHouse.bids(1);

        hevm.warp(auctionDeadline + 1);
        auctionHouse.settleAuction(1);
    }

    function test_terminate_auction_prematurely() public {
        uint previousBalance = prot.balanceOf(address(this));
        auctionHouse.increaseBidSize(1, 10 ether, 105.1 ether);
        auctionHouse.disableContract();
        auctionHouse.terminateAuctionPrematurely(1);
        assertEq(safeEngine.coinBalance(address(auctionHouse)), 0);
        assertEq(safeEngine.coinBalance(address(accountingEngine)), 0);
        assertEq(prot.balanceOf(address(this)), previousBalance);
        assertEq(prot.balanceOf(auctionHouse.tokenBurner()), 10 ether);
    }

    function testFail_terminate_auction_prematurely_enabled() public {
        auctionHouse.increaseBidSize(1, 10 ether, 105.1 ether);
        auctionHouse.terminateAuctionPrematurely(1);
    }

    function testFail_terminate_auction_prematurely_no_bid() public {
        auctionHouse.disableContract();
        auctionHouse.terminateAuctionPrematurely(1);
    }
}
