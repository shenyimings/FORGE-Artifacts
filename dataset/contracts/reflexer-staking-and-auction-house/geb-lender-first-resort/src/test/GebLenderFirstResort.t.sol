pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "../GebLenderFirstResort.sol";

abstract contract Hevm {
    function warp(uint) virtual public;
    function roll(uint) virtual public;
}

contract AuctionHouseMock {
    uint public activeStakedTokenAuctions;
    DSToken public tokenToAuction;

    constructor(address tokenToAuction_) public {
        tokenToAuction = DSToken(tokenToAuction_);
    }

    function startAuction(uint256 tokensToAuction, uint256) external returns (uint256) {
        tokenToAuction.transferFrom(msg.sender, address(this), tokensToAuction);
        return activeStakedTokenAuctions++;
    }
}
contract AccountingEngineMock {
    uint public debtAuctionBidSize = 100 ether;
    uint public unqueuedUnauctionedDebt = 0 ether;

    function modifyParameters(bytes32 param, uint val) public {
        if (param == "debtAuctionBidSize") debtAuctionBidSize = val;
        else if (param == "unqueuedUnauctionedDebt") unqueuedUnauctionedDebt = val;
        else revert("unrecognized param");
    }
}
contract SAFEEngineMock {
    mapping (address => uint256)                       public coinBalance;      // [rad]
    // Amount of debt held by an account. Coins & debt are like matter and antimatter. They nullify each other
    mapping (address => uint256)                       public debtBalance;      // [rad]

    function modifyBalance(bytes32 param, address who, uint val) public {
        if (param == "coin") coinBalance[who] = val;
        else if (param == "debt") debtBalance[who] = val;
        else revert("unrecognized param");
    }
}

contract Caller {
    GebLenderFirstResort stakingPool;

    constructor (GebLenderFirstResort add) public {
        stakingPool = add;
    }

    function doModifyParameters(bytes32 param, uint256 data) public {
        stakingPool.modifyParameters(param, data);
    }

    function doModifyParameters(bytes32 param, address data) public {
        stakingPool.modifyParameters(param, data);
    }

    function doAddAuthorization(address data) public {
        stakingPool.addAuthorization(data);
    }

    function doRemoveAuthorization(address data) public {
        stakingPool.removeAuthorization(data);
    }

    function doJoin(uint wad) public {
        stakingPool.ancestor().approve(address(stakingPool), uint(-1));
        stakingPool.join(wad);
    }

    function doRequestExit(uint wad) public {
        stakingPool.requestExit(wad);
    }

    function doExit() public {
        stakingPool.descendant().approve(address(stakingPool), uint(-1));
        stakingPool.exit();
    }
}

contract GebLenderFirstResortTest is DSTest {
    Hevm hevm;
    DSToken ancestor;
    DSToken descendant;
    GebLenderFirstResort stakingPool;
    AuctionHouseMock auctionHouse;
    AccountingEngineMock accountingEngine;
    SAFEEngineMock safeEngine;
    Caller unauth;

    uint maxDelay = 48 weeks;
    uint exitDelay = 1 weeks;
    uint minStakedTokensToKeep = 10 ether;
    uint tokensToAuction  = 100 ether;
    uint systemCoinsToRequest = 1000 ether;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        hevm.roll(5000000);
        hevm.warp(100000001);

        ancestor = new DSToken("PROT", "PROT");
        descendant = new DSToken("POOL", "POOL");
        auctionHouse = new AuctionHouseMock(address(ancestor));
        accountingEngine = new AccountingEngineMock();
        safeEngine = new SAFEEngineMock();

        stakingPool = new GebLenderFirstResort(
            address(ancestor),
            address(descendant),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest
        );

        ancestor.mint(address(this), 10000000 ether);
        descendant.setOwner(address(stakingPool));

        unauth = new Caller(stakingPool);
    }

    function test_setup() public {
        assertEq(address(stakingPool.ancestor()), address(ancestor));
        assertEq(address(stakingPool.descendant()), address(descendant));
        assertEq(address(stakingPool.auctionHouse()), address(auctionHouse));
        assertEq(stakingPool.MAX_DELAY(), maxDelay);
        assertEq(stakingPool.exitDelay(), exitDelay);
        assertEq(stakingPool.minStakedTokensToKeep(), minStakedTokensToKeep);
        assertEq(stakingPool.tokensToAuction(), tokensToAuction);
        assertEq(stakingPool.systemCoinsToRequest(), systemCoinsToRequest);
        assertEq(stakingPool.authorizedAccounts(address(this)), 1);
        assertEq(stakingPool.maxConcurrentAuctions(), uint(-1));
        assertTrue(stakingPool.canJoin());
    }

    function testFail_setup_invalid_maxDelay() public {
        stakingPool = new GebLenderFirstResort(
            address(ancestor),
            address(descendant),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            0,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest
        );
    }

    function testFail_setup_invalid_minStakedTokensToKeep() public {
        stakingPool = new GebLenderFirstResort(
            address(ancestor),
            address(descendant),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            maxDelay,
            exitDelay,
            0,
            tokensToAuction,
            systemCoinsToRequest
        );
    }

    function testFail_setup_invalid_tokensToAuction() public {
        stakingPool = new GebLenderFirstResort(
            address(ancestor),
            address(descendant),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            0,
            systemCoinsToRequest
        );
    }

    function testFail_setup_invalid_systemCoinsToRequest() public {
        stakingPool = new GebLenderFirstResort(
            address(ancestor),
            address(descendant),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            0
        );
    }

    function testFail_setup_invalid_auctionHouse() public {
        stakingPool = new GebLenderFirstResort(
            address(ancestor),
            address(descendant),
            address(0),
            address(accountingEngine),
            address(safeEngine),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest
        );
    }

    function testFail_setup_invalid_accountingEngine() public {
        stakingPool = new GebLenderFirstResort(
            address(ancestor),
            address(descendant),
            address(auctionHouse),
            address(0),
            address(safeEngine),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest
        );
    }

    function testFail_setup_invalid_safeEngine() public {
        stakingPool = new GebLenderFirstResort(
            address(ancestor),
            address(descendant),
            address(auctionHouse),
            address(accountingEngine),
            address(0),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest
        );
    }

    function test_add_authorization() public {
        stakingPool.addAuthorization(address(0xfab));
        assertEq(stakingPool.authorizedAccounts(address(0xfab)), 1);
    }

    function test_remove_authorization() public {
        stakingPool.removeAuthorization(address(this));
        assertEq(stakingPool.authorizedAccounts(address(this)), 0);
    }

    function testFail_add_authorization_unauthorized() public {
        unauth.doAddAuthorization(address(0xfab));
    }

    function testFail_remove_authorization_unauthorized() public {
        unauth.doRemoveAuthorization(address(this));
    }

    function test_modify_parameters() public {
        stakingPool.modifyParameters("exitDelay", maxDelay - 10);
        assertEq(stakingPool.exitDelay(), maxDelay - 10);

        stakingPool.modifyParameters("minStakedTokensToKeep", 3);
        assertEq(stakingPool.minStakedTokensToKeep(), 3);

        stakingPool.modifyParameters("tokensToAuction", 4);
        assertEq(stakingPool.tokensToAuction(), 4);

        stakingPool.modifyParameters("systemCoinsToRequest", 5);
        assertEq(stakingPool.systemCoinsToRequest(), 5);

        stakingPool.modifyParameters("maxConcurrentAuctions", 6);
        assertEq(stakingPool.maxConcurrentAuctions(), 6);

        stakingPool.modifyParameters("auctionHouse", address(3));
        assertEq(address(stakingPool.auctionHouse()), address(3));

        stakingPool.modifyParameters("accountingEngine", address(4));
        assertEq(address(stakingPool.accountingEngine()), address(4));
    }

    function testFail_modify_parameters_null_address() public {
        stakingPool.modifyParameters("accountingEngine", address(0));
    }

    function testFail_modify_parameters_invalid_param_address() public {
        stakingPool.modifyParameters("invalid", address(1));
    }

    function testFail_modify_parameters_invalid_param_uint() public {
        stakingPool.modifyParameters("invalid", 1);
    }

    function testFail_modify_parameters_invalid_exit_delay() public {
        stakingPool.modifyParameters("exitDelay", maxDelay + 1);
    }

    function testFail_modify_parameters_invalid_min_tokens_to_keep() public {
        stakingPool.modifyParameters("minTokensToKeep", 0);
    }

    function testFail_modify_parameters_invalid_tokens_to_auction() public {
        stakingPool.modifyParameters("tokensToAuction", 0);
    }

    function testFail_modify_parameters_invalid_system_coins_to_request() public {
        stakingPool.modifyParameters("systemCoinsToRequest", 0);
    }

    function testFail_modify_parameters_invalid_max_concurrent_auctions() public {
        stakingPool.modifyParameters("maxConcurrentAuctions", 1);
    }

    function testFail_modify_parameters_unauthorized_address() public {
        unauth.doModifyParameters("rewardDripper", address(1));
    }

    function testFail_modify_parameters_unauthorized_uint() public {
        unauth.doModifyParameters("systemCoinsToRequest", 5 ether);
    }

    function test_join() public {
        uint amount = 1 ether;

        ancestor.approve(address(stakingPool), amount);
        uint price = stakingPool.joinPrice(amount);

        stakingPool.join(amount);

        assertEq(ancestor.balanceOf(address(stakingPool)), amount);
        assertEq(descendant.balanceOf(address(this)),price);
    }

    function testFail_join_invalid_ammount() public {
        uint amount = 0;

        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);
    }

    function testFail_join_unnaproved() public {
        uint amount = 1 ether;
        stakingPool.join(amount);
    }

    function testFail_join_cant_join() public {
        uint amount = 1 ether;
        ancestor.approve(address(stakingPool), amount);
        stakingPool.toggleJoin();
        stakingPool.join(amount);
    }

    function testFail_join_underwater() public {
        uint amount = 1 ether;
        ancestor.approve(address(stakingPool), amount);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);

        stakingPool.join(amount);
    }

    function test_join_2() public {
        uint amount = 1 ether;
        ancestor.approve(address(stakingPool), amount);
        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);
        safeEngine.modifyBalance("coin", address(accountingEngine), 1000 ether);

        stakingPool.join(amount);
    }

    function test_request_exit() public {
        ancestor.approve(address(stakingPool), 1 ether);
        stakingPool.join(1 ether);

        stakingPool.requestExit(1 ether);
        (uint deadline, uint wad) = stakingPool.exitRequests(address(this));

        assertEq(deadline, now + exitDelay);
        assertEq(wad, 1 ether);
    }

    function test_exit() public {
        uint amount = 2 ether;
        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        // request exit
        stakingPool.requestExit(amount);

        // exit
        hevm.warp(now + exitDelay);
        descendant.approve(address(stakingPool), uint(-1)); // necessary, should be handled by proxyActions
        uint256 price = stakingPool.exitPrice(amount);

        uint previousBalance = ancestor.balanceOf(address(this));

        stakingPool.exit();
        assertEq(ancestor.balanceOf(address(this)), previousBalance + price);
        assertEq(descendant.balanceOf(address(this)), 0);
    }

    function testFail_requestExit_null_amount() public {
        uint amount = 10 ether;
        // join
        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        // request exit
        stakingPool.requestExit(0);
    }

    function testFail_exit_no_request() public {
        uint amount = 2 ether;
        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        // does not request exit
        // stakingPool.requestExit();

        // exit
        hevm.warp(now + exitDelay);
        descendant.approve(address(stakingPool), uint(-1)); // necessary, should be handled by proxyActions

        stakingPool.exit();
    }

    function testFail_exit_underwater() public {
        uint amount = 5 ether;
        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        // request exit
        stakingPool.requestExit(amount);

        // exit
        hevm.warp(now + exitDelay);
        descendant.approve(address(stakingPool), uint(-1)); // necessary, should be handled by proxyActions

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);

        stakingPool.exit();
    }

    function test_exit_forced_underwater() public {
        uint amount = 5 ether;
        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        // request exit
        stakingPool.requestExit(amount);

        // exit
        hevm.warp(now + exitDelay);
        descendant.approve(address(stakingPool), uint(-1)); // necessary, should be handled by proxyActions

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);

        stakingPool.toggleForcedExit();

        stakingPool.exit();
    }

    function test_auction_ancestor_tokens() public {
        uint amount = 1000 ether;
        // join
        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);

        // auction
        stakingPool.auctionAncestorTokens();

        assertEq(auctionHouse.activeStakedTokenAuctions(), 1);
        assertEq(ancestor.balanceOf(address(auctionHouse)), 100 ether);
    }

    function testFail_auction_ancestor_tokens_abovewater() public {
        uint amount = 10000 ether;
        // join
        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        // auction
        stakingPool.auctionAncestorTokens();
    }

    function testFail_auction_ancestor_tokens_abovewater_2() public {
        uint amount = 10000 ether;
        // join
        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);
        safeEngine.modifyBalance("coin", address(accountingEngine), 1000 ether);

        // auction
        stakingPool.auctionAncestorTokens();
    }

    function test_slashing() public {
        uint amount = 1000 ether;
        // join
        uint previousBalance = ancestor.balanceOf(address(this));
        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);

        // auction
        stakingPool.auctionAncestorTokens();

        assertEq(auctionHouse.activeStakedTokenAuctions(), 1);
        assertEq(ancestor.balanceOf(address(auctionHouse)), 100 ether);

        // exiting (after slash)
        stakingPool.requestExit(amount);
        hevm.warp(now + exitDelay);
        descendant.approve(address(stakingPool), uint(-1));

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 90 ether); // above water

        stakingPool.exit();
        assertEq(ancestor.balanceOf(address(this)), previousBalance - 100 ether);
        assertEq(descendant.balanceOf(address(this)), 0);
    }

    function assertAlmostEqual(uint a, uint b, uint p) public {
        uint v = a - (a / 10**p);
        assertTrue(b >= a - v && b <= a + v);
    }

    function test_slashing_2_users() public {
        uint amount = 513 ether;
        Caller user1 = new Caller(stakingPool);
        ancestor.transfer(address(user1), amount);
        Caller user2 = new Caller(stakingPool);
        ancestor.transfer(address(user2), amount);

        uint previousBalance1 = ancestor.balanceOf(address(user1));
        uint previousBalance2 = ancestor.balanceOf(address(user2));

        // join
        user1.doJoin(amount);
        user2.doJoin(amount);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);

        // auction
        stakingPool.auctionAncestorTokens();

        assertEq(auctionHouse.activeStakedTokenAuctions(), 1);
        assertEq(ancestor.balanceOf(address(auctionHouse)), 100 ether);

        // exiting (after slash)
        user1.doRequestExit(amount);
        user2.doRequestExit(amount);
        hevm.warp(now + exitDelay);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 90 ether); // above water

        user1.doExit();
        user2.doExit();

        assertAlmostEqual(ancestor.balanceOf(address(user1)), previousBalance1 - 50 ether, 1);
        assertEq(descendant.balanceOf(address(user1)), 0);
        assertAlmostEqual(ancestor.balanceOf(address(user2)), previousBalance2 - 50 ether, 1);
        assertEq(descendant.balanceOf(address(user2)), 0);
    }

    function test_protocol_underwater() public {
        // protocolUnderwater == false when unqueuedUnauctionedDebt < safeEngine.coinBalance(accountingEngine) + debtAuctionBidSize
        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);
        safeEngine.modifyBalance("coin", address(accountingEngine), 1000 ether);
        accountingEngine.modifyParameters("debtAuctionBidSize", 1);
        assertTrue(!stakingPool.protocolUnderwater());

        // protocolUnderwater == true when unqueuedUnauctionedDebt >= safeEngine.coinBalance(accountingEngine) + debtAuctionBidSize
        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether + 1);
        safeEngine.modifyBalance("coin", address(accountingEngine), 1000 ether);
        accountingEngine.modifyParameters("debtAuctionBidSize", 1);
        assertTrue(stakingPool.protocolUnderwater());

        // protocolUnderwater == false when accountingEngine.debtAuctionBidSize() > unqueuedUnauctionedDebt
        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);
        accountingEngine.modifyParameters("debtAuctionBidSize", 1000 ether + 1);
        assertTrue(!stakingPool.protocolUnderwater());
    }
}