pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "../GebLenderFirstResortRewardsVested.sol";
import {RewardDripper} from "../RewardDripper.sol";

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
contract EscrowMock {
    function escrowRewards(address, uint256) external {}
}

contract Caller {
    GebLenderFirstResortRewardsVested stakingPool;

    constructor (GebLenderFirstResortRewardsVested add) public {
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

    function doGetRewards() public {
        stakingPool.getRewards();
    }

    function doJoin(uint wad) public {
        stakingPool.ancestorPool().token().approve(address(stakingPool), uint(-1));
        stakingPool.join(wad);
    }

    function doRequestExit(uint wad) public {
        stakingPool.requestExit(wad);
    }

    function doExit() public {
        stakingPool.exit();
    }

    function doApprove(DSToken token, address guy) public {
        token.approve(guy);
    }
}

contract GebLenderFirstResortRewardsVestedTest is DSTest {
    Hevm hevm;
    DSToken rewardToken;
    DSToken ancestor;
    DSToken descendant;
    GebLenderFirstResortRewardsVested stakingPool;
    AuctionHouseMock auctionHouse;
    AccountingEngineMock accountingEngine;
    SAFEEngineMock safeEngine;
    RewardDripper rewardDripper;
    EscrowMock escrow;
    Caller unauth;

    uint maxDelay = 48 weeks;
    uint exitDelay = 1 weeks;
    uint minStakedTokensToKeep = 10 ether;
    uint tokensToAuction  = 100 ether;
    uint systemCoinsToRequest = 1000 ether;
    uint percentageVested = 60;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        hevm.roll(5000000);
        hevm.warp(100000001);

        rewardToken      = new DSToken("PROT", "PROT");
        ancestor         = new DSToken("LP", "LP");
        descendant       = new DSToken("LP_DESC", "LP_DESC");
        auctionHouse     = new AuctionHouseMock(address(ancestor));
        accountingEngine = new AccountingEngineMock();
        safeEngine       = new SAFEEngineMock();
        rewardDripper    = new RewardDripper(
            address(this),        // requestor
            address(rewardToken),
            1 ether               // rewardPerBlock
        );
        escrow           = new EscrowMock();

        stakingPool = new GebLenderFirstResortRewardsVested(
            address(ancestor),
            address(descendant),
            address(rewardToken),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            address(rewardDripper),
            address(escrow),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest,
            percentageVested
        );
        stakingPool.modifyParameters("escrowPaused", 1);

        rewardDripper.modifyParameters("requestor", address(stakingPool));
        rewardToken.mint(address(rewardDripper), 10000000 ether);

        ancestor.mint(address(this), 1000000000 ether);
        descendant.setOwner(address(stakingPool));

        descendant.approve(address(stakingPool));

        unauth = new Caller(stakingPool);
    }

    function test_setup() public {
        assertEq(address(stakingPool.ancestorPool().token()), address(ancestor));
        assertEq(address(stakingPool.descendant()), address(descendant));
        assertEq(address(stakingPool.auctionHouse()), address(auctionHouse));
        assertEq(address(stakingPool.rewardDripper()), address(rewardDripper));
        assertEq(address(stakingPool.escrow()), address(escrow));
        assertEq(address(stakingPool.rewardPool().token()), address(rewardToken));
        assertEq(stakingPool.MAX_DELAY(), maxDelay);
        assertEq(stakingPool.exitDelay(), exitDelay);
        assertEq(stakingPool.escrowPaused(), 1);
        assertEq(stakingPool.minStakedTokensToKeep(), minStakedTokensToKeep);
        assertEq(stakingPool.tokensToAuction(), tokensToAuction);
        assertEq(stakingPool.systemCoinsToRequest(), systemCoinsToRequest);
        assertEq(stakingPool.authorizedAccounts(address(this)), 1);
        assertEq(stakingPool.maxConcurrentAuctions(), uint(-1));
        assertEq(stakingPool.stakedSupply(), 0);
        assertTrue(stakingPool.canJoin());
    }

    function testFail_setup_invalid_maxDelay() public {
        stakingPool = new GebLenderFirstResortRewardsVested(
            address(ancestor),
            address(descendant),
            address(rewardToken),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            address(rewardDripper),
            address(escrow),
            0,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest,
            percentageVested
        );
    }

    function testFail_setup_invalid_minStakedTokensToKeep() public {
        stakingPool = new GebLenderFirstResortRewardsVested(
            address(ancestor),
            address(descendant),
            address(rewardToken),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            address(rewardDripper),
            address(escrow),
            maxDelay,
            exitDelay,
            0,
            tokensToAuction,
            systemCoinsToRequest,
            percentageVested
        );
    }

    function testFail_setup_invalid_tokensToAuction() public {
        stakingPool = new GebLenderFirstResortRewardsVested(
            address(ancestor),
            address(descendant),
            address(rewardToken),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            address(rewardDripper),
            address(escrow),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            0,
            systemCoinsToRequest,
            percentageVested
        );
    }

    function testFail_setup_invalid_systemCoinsToRequest() public {
        stakingPool = new GebLenderFirstResortRewardsVested(
            address(ancestor),
            address(descendant),
            address(rewardToken),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            address(rewardDripper),
            address(escrow),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            0,
            percentageVested
        );
    }

    function testFail_setup_invalid_auctionHouse() public {
        stakingPool = new GebLenderFirstResortRewardsVested(
            address(ancestor),
            address(descendant),
            address(rewardToken),
            address(0),
            address(accountingEngine),
            address(safeEngine),
            address(rewardDripper),
            address(escrow),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest,
            percentageVested
        );
    }

    function testFail_setup_invalid_accountingEngine() public {
        stakingPool = new GebLenderFirstResortRewardsVested(
            address(ancestor),
            address(descendant),
            address(rewardToken),
            address(auctionHouse),
            address(0),
            address(safeEngine),
            address(rewardDripper),
            address(escrow),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest,
            percentageVested
        );
    }

    function testFail_setup_invalid_safeEngine() public {
        stakingPool = new GebLenderFirstResortRewardsVested(
            address(ancestor),
            address(descendant),
            address(rewardToken),
            address(auctionHouse),
            address(accountingEngine),
            address(0),
            address(rewardDripper),
            address(escrow),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest,
            percentageVested
        );
    }

    function testFail_setup_invalid_rewardsDripper() public {
        stakingPool = new GebLenderFirstResortRewardsVested(
            address(ancestor),
            address(descendant),
            address(rewardToken),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            address(0),
            address(escrow),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest,
            percentageVested
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

        stakingPool.modifyParameters("rewardDripper", address(5));
        assertEq(address(stakingPool.rewardDripper()), address(5));
    }

    function testFail_modify_parameters_null_address() public {
        stakingPool.modifyParameters("rewardDripper", address(0));
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

        assertEq(ancestor.balanceOf(address(stakingPool.ancestorPool())), amount);
        assertEq(stakingPool.descendantBalanceOf(address(this)),price);
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
        uint256 price = stakingPool.exitPrice(amount);

        uint previousBalance = ancestor.balanceOf(address(this));

        stakingPool.exit();
        assertEq(ancestor.balanceOf(address(this)), previousBalance + price);
        assertEq(stakingPool.descendantBalanceOf(address(this)), 0);
    }

    function testFail_request_exit_null_amount() public {
        uint amount = 12 ether;
        // join
        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        // request exit
        stakingPool.requestExit(0);
    }

    function testFail_exit_before_deadline() public {
        uint amount = 1 ether;
        // join
        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        // request exit
        stakingPool.requestExit(amount);

        // exit
        (uint deadline,) = stakingPool.exitRequests(address(this));
        hevm.warp(deadline - 1);
        stakingPool.exit();
    }

    function testFail_exit_no_request() public {
        uint amount = 2 ether;
        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        // does not request exit
        // stakingPool.requestExit(amount);

        // exit
        hevm.warp(now + exitDelay);

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

        uint previousDescendantBalance = stakingPool.descendantBalanceOf(address(this));

        // auction
        stakingPool.auctionAncestorTokens();

        assertEq(auctionHouse.activeStakedTokenAuctions(), 1);
        assertEq(stakingPool.descendantBalanceOf(address(this)), previousDescendantBalance);
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

    function test_exit_rewards_1(uint amount, uint blockDelay) public {
        amount = amount % 10**24 + 1; // up to 1mm staked
        blockDelay = blockDelay % 100 + 1; // up to 1000 blocks
        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        // request exit
        hevm.roll(block.number + blockDelay);
        stakingPool.requestExit(amount);

        // exit
        hevm.warp(now + exitDelay);
        uint256 price = stakingPool.exitPrice(amount);

        uint previousBalance = ancestor.balanceOf(address(this));

        stakingPool.exit();
        assertEq(ancestor.balanceOf(address(this)), previousBalance + price);
        assertEq(stakingPool.descendantBalanceOf(address(this)), 0);
        assertTrue(rewardToken.balanceOf(address(this)) >= blockDelay * 1 ether - 1); // 1 eth per block
    }

    function test_exit_rewards_2_users(uint amount) public {
        amount = amount % 10**24 + 1; // non null up to 1mm
        Caller user1 = new Caller(stakingPool);
        ancestor.transfer(address(user1), amount);
        Caller user2 = new Caller(stakingPool);
        ancestor.transfer(address(user2), amount);

        // join
        user1.doJoin(amount);
        user2.doJoin(amount);

        // request exit
        hevm.roll(block.number + 32); // 32 blocks

        user1.doApprove(descendant, address(stakingPool));
        user2.doApprove(descendant, address(stakingPool));

        user1.doRequestExit(amount);
        user2.doRequestExit(amount);

        // exit
        hevm.warp(now + exitDelay);

        user1.doExit();
        user2.doExit();
        assertTrue(rewardToken.balanceOf(address(user1)) >= 16 ether -1); // .5 eth per block
        assertTrue(rewardToken.balanceOf(address(user2)) >= 16 ether -1); // .5 eth per block
    }

    function test_get_rewards() public {
        uint amount = 10 ether;

        hevm.roll(block.number + 10);

        stakingPool.updatePool(); // no effect

        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        hevm.roll(block.number + 10); // 10 blocks

        stakingPool.getRewards();
        assertEq(rewardToken.balanceOf(address(this)), 20 ether); // 1 eth per block

        hevm.roll(block.number + 8); // 8 blocks

        stakingPool.getRewards();
        assertTrue(rewardToken.balanceOf(address(this)) >= 28 ether - 1); // 1 eth per block, division rounding causes a slight loss of precision
    }

    function test_rewards_after_slashing() public {
        uint amount = 1000 ether;
        // join
        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);

        uint previousDescendantBalance = stakingPool.descendantBalanceOf(address(this));

        // auction
        stakingPool.auctionAncestorTokens();

        assertEq(auctionHouse.activeStakedTokenAuctions(), 1);
        assertEq(stakingPool.descendantBalanceOf(address(this)), previousDescendantBalance);
        assertEq(ancestor.balanceOf(address(auctionHouse)), 100 ether);

        // exiting (after slash)
        hevm.roll(block.number + 32); // 32 blocks
        stakingPool.requestExit(amount);
        hevm.warp(now + exitDelay);
        uint256 price = stakingPool.exitPrice(amount);

        uint previousBalance = ancestor.balanceOf(address(this));

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 90 ether); // above water

        stakingPool.exit();
        assertEq(ancestor.balanceOf(address(this)), previousBalance + price);
        assertEq(stakingPool.descendantBalanceOf(address(this)), 0);
        assertEq(rewardToken.balanceOf(address(this)), 32 ether); // 1 eth per block
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
        user1.doApprove(descendant, address(stakingPool));
        user2.doApprove(descendant, address(stakingPool));

        user1.doRequestExit(amount);
        user2.doRequestExit(amount);
        hevm.warp(now + exitDelay);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 90 ether); // above water

        user1.doExit();
        user2.doExit();

        assertAlmostEqual(ancestor.balanceOf(address(user1)), previousBalance1 - 50 ether, 1);
        assertEq(stakingPool.descendantBalanceOf(address(user1)), 0);
        assertAlmostEqual(ancestor.balanceOf(address(user2)), previousBalance2 - 50 ether, 1);
        assertEq(stakingPool.descendantBalanceOf(address(user2)), 0);
    }

    function test_rewards_dripper_depleated() public {
        uint amount = 7 ether;
        // leave rewards only for 20 blocks
        rewardDripper.transferTokenOut(address(0xfab), rewardToken.balanceOf(address(rewardDripper)) - 20 ether);

        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        hevm.roll(block.number + 32); // 32 blocks
        stakingPool.requestExit(amount);
        hevm.warp(now + exitDelay);

        stakingPool.exit();
        assertEq(stakingPool.descendantBalanceOf(address(this)), 0);
        assertTrue(rewardToken.balanceOf(address(this)) >= 20 ether - 1); // full amount
    }

    function test_rewards_dripper_depleated_recharged() public {
        uint amount = 7 ether;
        // leave rewards only for 20 blocks
        rewardDripper.transferTokenOut(address(0xfab), rewardToken.balanceOf(address(rewardDripper)) - 20 ether);

        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        hevm.roll(block.number + 32); // 32 blocks
        stakingPool.getRewards();
        assertTrue(rewardToken.balanceOf(address(this)) >= 20 ether - 1); // full amount

        hevm.roll(block.number + 32); // 32 blocks

        rewardToken.mint(address(rewardDripper), 5 ether);
        stakingPool.getRewards();
        assertTrue(rewardToken.balanceOf(address(this)) >= 25 ether - 1);
    }

    function test_rewards_change_dripper_emission() public {
        uint amount = 23 ether;

        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        hevm.roll(block.number + 32); // 32 blocks
        stakingPool.getRewards();
        assertTrue(rewardToken.balanceOf(address(this)) >= 32 ether - 1); // full amount

        rewardDripper.modifyParameters("rewardPerBlock", 0.5 ether);
        hevm.roll(block.number + 32); // 32 blocks

        stakingPool.getRewards();
        assertTrue(rewardToken.balanceOf(address(this)) >= 48 ether - 1);
    }

    function test_deposit_rewards() public {
        uint amount = 23 ether;

        ancestor.approve(address(stakingPool), amount * 3);
        stakingPool.join(amount);

        hevm.roll(block.number + 32); // 32 blocks
        stakingPool.join(amount);
        assertTrue(rewardToken.balanceOf(address(this)) >= 32 ether - 1); // full amount

        hevm.roll(block.number + 32); // 32 blocks

        stakingPool.join(amount);
        assertTrue(rewardToken.balanceOf(address(this)) >= 64 ether - 1);
    }

    function test_multi_user_diff_proportions() public {
        uint amount = 3.14 ether;
        Caller user1 = new Caller(stakingPool);
        ancestor.transfer(address(user1), amount);
        Caller user2 = new Caller(stakingPool);
        ancestor.transfer(address(user2), amount);
        Caller user3 = new Caller(stakingPool);
        ancestor.transfer(address(user3), amount * 2);

        // users 1 & 2 join, same amount
        user1.doJoin(amount);
        user2.doJoin(amount);

        hevm.roll(block.number + 12); // 12 blocks

        // approvals
        user1.doApprove(descendant, address(stakingPool));
        user2.doApprove(descendant, address(stakingPool));

        // users 3 joins, with double amount
        user3.doJoin(amount * 2);
        user1.doGetRewards();
        user2.doGetRewards();
        assertTrue(rewardToken.balanceOf(address(user1)) >= 6 ether -1);
        assertTrue(rewardToken.balanceOf(address(user2)) >= 6 ether -1);
        assertTrue(rewardToken.balanceOf(address(user3)) == 0);          // no rewards yet

        // users 1 exits the pool
        hevm.roll(block.number + 12); // 12 blocks
        user1.doRequestExit(amount);
        hevm.warp(now + exitDelay);

        user1.doExit();
        user2.doGetRewards();
        user3.doGetRewards();
        assertTrue(rewardToken.balanceOf(address(user1)) >= 9 ether -1);
        assertTrue(rewardToken.balanceOf(address(user2)) >= 9 ether -1);
        assertTrue(rewardToken.balanceOf(address(user3)) >= 6 ether -1);

        // user 1 rejoins
        hevm.roll(block.number + 12); // 12 blocks
        user1.doJoin(amount);
        user2.doGetRewards();
        user3.doGetRewards();
        assertTrue(rewardToken.balanceOf(address(user1)) >= 9 ether -1);
        assertTrue(rewardToken.balanceOf(address(user2)) >= 13 ether -1);
        assertTrue(rewardToken.balanceOf(address(user3)) >= 14 ether -1);

        // all onboard
        hevm.roll(block.number + 12); // 12 blocks
        user1.doGetRewards();
        user2.doGetRewards();
        user3.doGetRewards();
        assertTrue(rewardToken.balanceOf(address(user1)) >= 12 ether -1);
        assertTrue(rewardToken.balanceOf(address(user2)) >= 16 ether -1);
        assertTrue(rewardToken.balanceOf(address(user3)) >= 20 ether -1);
    }

    function test_rewards_over_long_intervals() public {
        uint amount = 3.14 ether;
        Caller user1 = new Caller(stakingPool);
        ancestor.transfer(address(user1), amount);
        Caller user2 = new Caller(stakingPool);
        ancestor.transfer(address(user2), amount);

        // users 1 & 2 join, same amount
        user1.doJoin(amount);
        hevm.roll(block.number + 1000000); // 1mm blocks

        user2.doJoin(amount);
        hevm.roll(block.number + 1); // 1 block

        user1.doGetRewards();
        user2.doGetRewards();
        assertTrue(rewardToken.balanceOf(address(user1)) >= 1000000.5 ether - 1);
        assertTrue(rewardToken.balanceOf(address(user1)) <= 1000000.5 ether);
        assertTrue(rewardToken.balanceOf(address(user2)) >= 0.5 ether - 1);
        assertTrue(rewardToken.balanceOf(address(user2)) <= 0.5 ether);

        hevm.roll(block.number + 1); // 1 block

        user1.doGetRewards();
        user2.doGetRewards();
        assertTrue(rewardToken.balanceOf(address(user1)) >= 1000001 ether - 1);
        assertTrue(rewardToken.balanceOf(address(user1)) <= 1000001 ether);
        assertTrue(rewardToken.balanceOf(address(user2)) >= 1 ether - 1);
        assertTrue(rewardToken.balanceOf(address(user2)) <= 1 ether);
    }

    function test_get_rewards_externally_funded() public {
        uint amount = 10 ether;

        hevm.roll(block.number + 10);

        stakingPool.updatePool(); // no effect

        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        hevm.roll(block.number + 10); // 10 blocks

        rewardToken.mint(address(stakingPool.rewardPool()), 10 ether); // manually filling up contract

        stakingPool.getRewards();
        assertEq(rewardToken.balanceOf(address(this)), 30 ether); // 1 eth per block + externally funded

        hevm.roll(block.number + 4);
        stakingPool.pullFunds(); // pulling rewards to conrtact without updating

        hevm.roll(block.number + 4);
        rewardToken.mint(address(stakingPool.rewardPool()), 2 ether); // manually filling up contract

        stakingPool.getRewards();
        assertTrue(rewardToken.balanceOf(address(this)) >= 40 ether - 1); // 1 eth per block, division rounding causes a slight loss of precision
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

    function test_escrow_rewards_twice() public {
        stakingPool.modifyParameters("escrowPaused", 0);

        uint amount = 10 ether;

        hevm.roll(block.number + 10);

        stakingPool.updatePool(); // no effect

        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        hevm.roll(block.number + 10); // 10 blocks

        stakingPool.getRewards();
        assertEq(rewardToken.balanceOf(address(this)), 8 ether);
        assertEq(rewardToken.balanceOf(address(escrow)), 12 ether);

        hevm.roll(block.number + 8); // 8 blocks

        stakingPool.getRewards();
        assertTrue(rewardToken.balanceOf(address(this)) >= 11.2 ether - 1);
        assertTrue(rewardToken.balanceOf(address(escrow)) >= 16.8 ether - 1);
    }
}

contract GebLenderFirstResortRewardsVestedSameTokenTest is DSTest {
    Hevm hevm;
    DSToken ancestor;
    DSToken descendant;
    GebLenderFirstResortRewardsVested stakingPool;
    AuctionHouseMock auctionHouse;
    AccountingEngineMock accountingEngine;
    SAFEEngineMock safeEngine;
    RewardDripper rewardDripper;
    Caller unauth;
    EscrowMock escrow;

    uint maxDelay = 48 weeks;
    uint exitDelay = 1 weeks;
    uint minStakedTokensToKeep = 10 ether;
    uint tokensToAuction  = 100 ether;
    uint systemCoinsToRequest = 1000 ether;
    uint256 percentageVested = 60;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        hevm.roll(5000000);
        hevm.warp(100000001);

        ancestor = new DSToken("PROT", "PROT");
        descendant = new DSToken("PROT_DESC", "PROT_DESC");
        auctionHouse = new AuctionHouseMock(address(ancestor));
        accountingEngine = new AccountingEngineMock();
        safeEngine = new SAFEEngineMock();
        rewardDripper = new RewardDripper(
            address(this),        // requestor
            address(ancestor),
            1 ether               // rewardPerBlock
        );
        escrow = new EscrowMock();

        stakingPool = new GebLenderFirstResortRewardsVested(
            address(ancestor),
            address(descendant),
            address(ancestor),
            address(auctionHouse),
            address(accountingEngine),
            address(safeEngine),
            address(rewardDripper),
            address(escrow),
            maxDelay,
            exitDelay,
            minStakedTokensToKeep,
            tokensToAuction,
            systemCoinsToRequest,
            percentageVested
        );
        stakingPool.modifyParameters("escrowPaused", 1);

        rewardDripper.modifyParameters("requestor", address(stakingPool));
        ancestor.mint(address(rewardDripper), 10000000 ether);

        ancestor.mint(address(this), 1000000000 ether);
        descendant.setOwner(address(stakingPool));

        descendant.approve(address(stakingPool));

        unauth = new Caller(stakingPool);
    }

    function test_setup() public {
        assertEq(address(stakingPool.ancestorPool().token()), address(ancestor));
        assertEq(address(stakingPool.descendant()), address(descendant));
        assertEq(address(stakingPool.auctionHouse()), address(auctionHouse));
        assertEq(address(stakingPool.rewardDripper()), address(rewardDripper));
        assertEq(address(stakingPool.rewardPool().token()), address(ancestor));
        assertEq(address(stakingPool.escrow()), address(escrow));
        assertEq(stakingPool.MAX_DELAY(), maxDelay);
        assertEq(stakingPool.exitDelay(), exitDelay);
        assertEq(stakingPool.percentageVested(), percentageVested);
        assertEq(stakingPool.minStakedTokensToKeep(), minStakedTokensToKeep);
        assertEq(stakingPool.tokensToAuction(), tokensToAuction);
        assertEq(stakingPool.systemCoinsToRequest(), systemCoinsToRequest);
        assertEq(stakingPool.authorizedAccounts(address(this)), 1);
        assertEq(stakingPool.maxConcurrentAuctions(), uint(-1));
        assertEq(stakingPool.stakedSupply(), 0);
        assertTrue(stakingPool.canJoin());
    }

    function test_join() public {
        uint amount = 1 ether;

        ancestor.approve(address(stakingPool), amount);
        uint price = stakingPool.joinPrice(amount);

        stakingPool.join(amount);

        assertEq(ancestor.balanceOf(address(stakingPool.ancestorPool())), amount);
        assertEq(stakingPool.descendantBalanceOf(address(this)),price);
    }

    function test_join_2() public {
        uint amount = 1 ether;
        ancestor.approve(address(stakingPool), amount);
        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);
        safeEngine.modifyBalance("coin", address(accountingEngine), 1000 ether);

        stakingPool.join(amount);
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
        uint256 price = stakingPool.exitPrice(amount);

        uint previousBalance = ancestor.balanceOf(address(this));

        stakingPool.exit();
        assertEq(ancestor.balanceOf(address(this)), previousBalance + price);
        assertEq(stakingPool.descendantBalanceOf(address(this)), 0);
    }

    function test_auction_ancestor_tokens() public {
        uint amount = 1000 ether;
        // join
        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);

        uint previousDescendantBalance = stakingPool.descendantBalanceOf(address(this));

        // auction
        stakingPool.auctionAncestorTokens();

        assertEq(auctionHouse.activeStakedTokenAuctions(), 1);
        assertEq(stakingPool.descendantBalanceOf(address(this)), previousDescendantBalance);
        assertEq(ancestor.balanceOf(address(auctionHouse)), 100 ether);
    }

    function test_exit_rewards_1(uint amount, uint blockDelay) public {
        amount = amount % 10**24 + 1; // up to 1mm staked
        blockDelay = blockDelay % 100 + 1; // up to 1000 blocks
        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        // request exit
        hevm.roll(block.number + blockDelay);
        uint previousBalance = ancestor.balanceOf(address(this));
        stakingPool.requestExit(amount);

        // exit
        hevm.warp(now + exitDelay);
        uint256 price = stakingPool.exitPrice(amount);

        stakingPool.exit();
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + price + (blockDelay * 1 ether) - 1);
        assertEq(stakingPool.descendantBalanceOf(address(this)), 0);
    }

    function test_exit_rewards_2_users2(uint amount) public {
        amount = amount % 10**24 + 1; // non null up to 1mm
        Caller user1 = new Caller(stakingPool);
        ancestor.transfer(address(user1), amount);
        Caller user2 = new Caller(stakingPool);
        ancestor.transfer(address(user2), amount);

        // join
        user1.doJoin(amount);
        user2.doJoin(amount);

        // request exit
        hevm.roll(block.number + 32); // 32 blocks
        uint previousBalance1 = ancestor.balanceOf(address(user1));
        uint previousBalance2 = ancestor.balanceOf(address(user2));

        user1.doApprove(descendant, address(stakingPool));
        user2.doApprove(descendant, address(stakingPool));

        user1.doRequestExit(amount);
        user2.doRequestExit(amount);

        // exit
        hevm.warp(now + exitDelay);

        user1.doExit();
        user2.doExit();
        assertTrue(ancestor.balanceOf(address(user1)) >= previousBalance1 + 16 ether -1); // .5 eth per block
        assertTrue(ancestor.balanceOf(address(user2)) >= previousBalance2 + 16 ether -1); // .5 eth per block
    }

    function test_get_rewards() public {
        uint amount = 10 ether;

        hevm.roll(block.number + 10);

        stakingPool.updatePool(); // no effect

        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        uint previousBalance = ancestor.balanceOf(address(this));

        hevm.roll(block.number + 10); // 10 blocks

        stakingPool.getRewards();
        assertEq(ancestor.balanceOf(address(this)), previousBalance + 20 ether); // 1 eth per block

        hevm.roll(block.number + 8); // 8 blocks

        stakingPool.getRewards();
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + 28 ether - 1); // 1 eth per block, division rounding causes a slight loss of precision
    }

    function test_rewards_after_slashing() public {
        uint amount = 1000 ether;
        // join
        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 1000 ether);

        uint previousDescendantBalance = stakingPool.descendantBalanceOf(address(this));

        // auction
        stakingPool.auctionAncestorTokens();

        assertEq(auctionHouse.activeStakedTokenAuctions(), 1);
        assertEq(stakingPool.descendantBalanceOf(address(this)), previousDescendantBalance);
        assertEq(ancestor.balanceOf(address(auctionHouse)), 100 ether);

        // exiting (after slash)
        hevm.roll(block.number + 32); // 32 blocks
        uint previousBalance = ancestor.balanceOf(address(this));
        stakingPool.requestExit(amount);
        hevm.warp(now + exitDelay);
        uint256 price = stakingPool.exitPrice(amount);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 90 ether); // above water

        stakingPool.exit();
        assertEq(ancestor.balanceOf(address(this)), previousBalance + price + 32 ether);
        assertEq(stakingPool.descendantBalanceOf(address(this)), 0);
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
        user1.doApprove(descendant, address(stakingPool));
        user2.doApprove(descendant, address(stakingPool));

        user1.doRequestExit(amount);
        user2.doRequestExit(amount);
        hevm.warp(now + exitDelay);

        accountingEngine.modifyParameters("unqueuedUnauctionedDebt", 90 ether); // above water

        user1.doExit();
        user2.doExit();

        assertAlmostEqual(ancestor.balanceOf(address(user1)), previousBalance1 - 50 ether, 1);
        assertEq(stakingPool.descendantBalanceOf(address(user1)), 0);
        assertAlmostEqual(ancestor.balanceOf(address(user2)), previousBalance2 - 50 ether, 1);
        assertEq(stakingPool.descendantBalanceOf(address(user2)), 0);
    }

    function test_rewards_dripper_depleated() public {
        uint amount = 7 ether;
        // leave rewards only for 20 blocks
        rewardDripper.transferTokenOut(address(0xfab), ancestor.balanceOf(address(rewardDripper)) - 20 ether);

        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        hevm.roll(block.number + 32); // 32 blocks
        uint previousBalance = ancestor.balanceOf(address(this));
        stakingPool.requestExit(amount);
        hevm.warp(now + exitDelay);

        stakingPool.exit();
        assertEq(stakingPool.descendantBalanceOf(address(this)), 0);
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + amount + 20 ether - 1); // full amount
    }

    function test_rewards_dripper_depleated_recharged() public {
        uint amount = 7 ether;
        // leave rewards only for 20 blocks
        rewardDripper.transferTokenOut(address(0xfab), ancestor.balanceOf(address(rewardDripper)) - 20 ether);

        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        hevm.roll(block.number + 32); // 32 blocks
        uint previousBalance = ancestor.balanceOf(address(this));
        stakingPool.getRewards();
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + 20 ether - 1); // full amount

        hevm.roll(block.number + 32); // 32 blocks

        ancestor.mint(address(rewardDripper), 5 ether);
        stakingPool.getRewards();
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + 25 ether - 1);
    }

    function test_rewards_change_dripper_emission() public {
        uint amount = 23 ether;

        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        hevm.roll(block.number + 32); // 32 blocks
        uint previousBalance = ancestor.balanceOf(address(this));
        stakingPool.getRewards();
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + 32 ether - 1); // full amount

        rewardDripper.modifyParameters("rewardPerBlock", 0.5 ether);
        hevm.roll(block.number + 32); // 32 blocks

        stakingPool.getRewards();
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + 48 ether - 1);
    }

    function test_deposit_rewards() public {
        uint amount = 23 ether;

        ancestor.approve(address(stakingPool), amount * 3);
        uint previousBalance = ancestor.balanceOf(address(this));
        stakingPool.join(amount);

        hevm.roll(block.number + 32); // 32 blocks
        stakingPool.join(amount);
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + 32 ether - 1 - (amount * 2)); // full amount

        hevm.roll(block.number + 32); // 32 blocks

        stakingPool.join(amount);
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + 64 ether - 1 - (amount * 3));
    }

    function test_rewards_over_long_intervals() public {
        uint amount = 3.14 ether;
        Caller user1 = new Caller(stakingPool);
        ancestor.transfer(address(user1), amount);
        Caller user2 = new Caller(stakingPool);
        ancestor.transfer(address(user2), amount);

        // users 1 & 2 join, same amount
        user1.doJoin(amount);
        hevm.roll(block.number + 1000000); // 1mm blocks

        user2.doJoin(amount);
        hevm.roll(block.number + 1); // 1 block

        uint previousBalance1 = ancestor.balanceOf(address(user1));
        uint previousBalance2 = ancestor.balanceOf(address(user2));
        user1.doGetRewards();
        user2.doGetRewards();

        assertTrue(ancestor.balanceOf(address(user1)) >= previousBalance1 + 1000000.5 ether - 1);
        assertTrue(ancestor.balanceOf(address(user1)) <= previousBalance1 + 1000000.5 ether);
        assertTrue(ancestor.balanceOf(address(user2)) >= previousBalance2 + 0.5 ether - 1);
        assertTrue(ancestor.balanceOf(address(user2)) <= previousBalance2 + 0.5 ether);

        hevm.roll(block.number + 1); // 1 block

        user1.doGetRewards();
        user2.doGetRewards();
        assertTrue(ancestor.balanceOf(address(user1)) >= previousBalance1 + 1000001 ether - 1);
        assertTrue(ancestor.balanceOf(address(user1)) <= previousBalance1 + 1000001 ether);
        assertTrue(ancestor.balanceOf(address(user2)) >= previousBalance2 + 1 ether - 1);
        assertTrue(ancestor.balanceOf(address(user2)) <= previousBalance2 + 1 ether);
    }

    function test_get_rewards_externally_funded() public {
        uint amount = 10 ether;

        hevm.roll(block.number + 10);

        stakingPool.updatePool(); // no effect

        // join
        ancestor.approve(address(stakingPool), uint(-1));
        stakingPool.join(amount);

        hevm.roll(block.number + 10); // 10 blocks

        ancestor.mint(address(stakingPool.rewardPool()), 10 ether); // manually filling up contract

        uint previousBalance = ancestor.balanceOf(address(this));
        stakingPool.getRewards();
        assertEq(ancestor.balanceOf(address(this)), previousBalance + 30 ether); // 1 eth per block + externally funded

        hevm.roll(block.number + 4);
        stakingPool.pullFunds(); // pulling rewards to conrtact without updating

        hevm.roll(block.number + 4);
        ancestor.mint(address(stakingPool.rewardPool()), 2 ether); // manually filling up contract

        stakingPool.getRewards();
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + 40 ether - 1); // 1 eth per block, division rounding causes a slight loss of precision
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

    function test_escrow_rewards_twice() public {
        stakingPool.modifyParameters("escrowPaused", 0);

        uint amount = 23 ether;

        ancestor.approve(address(stakingPool), amount);
        stakingPool.join(amount);

        hevm.roll(block.number + 32); // 32 blocks
        uint previousBalance = ancestor.balanceOf(address(this));

        stakingPool.getRewards();
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + 12.8 ether - 1); // 40% of the amount
        assertTrue(ancestor.balanceOf(address(escrow)) >= 18.2 ether - 1); // 60% of the amount

        rewardDripper.modifyParameters("rewardPerBlock", 0.5 ether);
        hevm.roll(block.number + 32); // 32 blocks

        stakingPool.getRewards();
        assertTrue(ancestor.balanceOf(address(this)) >= previousBalance + 19 ether - 1);
        assertTrue(ancestor.balanceOf(address(escrow)) >= 28 ether - 1);
    }
}
