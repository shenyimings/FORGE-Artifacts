pragma solidity >=0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "../RewardDripper.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
    function roll(uint256) virtual public;
}

contract Caller {
    RewardDripper dripper;

    constructor (RewardDripper dripper_) public {
        dripper = dripper_;
    }

    function doDrip() public {
        dripper.dripReward();
    }

    function doTransferTokenOut(address dst, uint256 amount) public {
        dripper.transferTokenOut(dst, amount);
    }

    function doModifyParameters(bytes32 param, uint256 data) public {
        dripper.modifyParameters(param, data);
    }

    function doModifyParameters(bytes32 param, address data) public {
        dripper.modifyParameters(param, data);
    }

    function doAddAuthorization(address data) public {
        dripper.addAuthorization(data);
    }

    function doRemoveAuthorization(address data) public {
        dripper.removeAuthorization(data);
    }
}

contract Requestor {

    function request(address dripper) public {
        RewardDripper(dripper).dripReward();
    }

}

contract RewardDripperTest is DSTest {
    Hevm hevm;

    RewardDripper dripper;
    Requestor requestor;
    DSToken coin;
    Caller unauth;

    address alice = address(0x4567);
    uint256 initTokenAmount = 100 ether;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.roll(5000000000);

        // Create token
        coin = new DSToken("RAI", "RAI");

        requestor = new Requestor();

        dripper = new RewardDripper(
            address(requestor),
            address(coin),
            1 ether // rewardPerBlock
        );

        unauth = new Caller(dripper);

        coin.mint(address(dripper), initTokenAmount);
    }

    // --- Tests ---
    function test_correct_setup() public {
        assertEq(dripper.rewardPerBlock(), 1 ether);
        assertEq(dripper.requestor(), address(requestor));
        assertEq(address(dripper.rewardToken()), address(coin));
        assertEq(dripper.lastRewardBlock(), block.number);
    }

    function testFail_setup_null_requestor() public {
        dripper = new RewardDripper(
            address(0),
            address(coin),
            1 ether
        );
    }

    function testFail_setup_null_token() public {
        dripper = new RewardDripper(
            address(requestor),
            address(0),
            1 ether
        );
    }

    function testFail_setup_null_reward() public {
        dripper = new RewardDripper(
            address(requestor),
            address(coin),
            0
        );
    }

    function test_add_authorization() public {
        dripper.addAuthorization(address(0xfab));
        assertEq(dripper.authorizedAccounts(address(0xfab)), 1);
    }

    function test_remove_authorization() public {
        dripper.removeAuthorization(address(this));
        assertEq(dripper.authorizedAccounts(address(this)), 0);
    }

    function testFail_add_authorization_unauthorized() public {
        unauth.doAddAuthorization(address(0xfab));
    }

    function testFail_remove_authorization_unauthorized() public {
        unauth.doRemoveAuthorization(address(this));
    }

    function test_modify_parameters() public {
        dripper.modifyParameters("lastRewardBlock", 1 ether);
        assertEq(dripper.lastRewardBlock(), 1 ether);

        dripper.modifyParameters("rewardPerBlock", 2 ether);
        assertEq(dripper.rewardPerBlock(), 2 ether);

        dripper.modifyParameters("requestor", address(0xbeef));
        assertEq(dripper.requestor(), address(0xbeef));
    }

    function testFail_modify_parameters_invalid_last_block() public {
        dripper.modifyParameters("lastRewardBlock", block.number - 1);
    }

    function testFail_modify_parameters_invalid_reward_per_block() public {
        dripper.modifyParameters("rewardPerBlock", 0);
    }

    function testFail_modify_parameters_invalid_param_address() public {
        dripper.modifyParameters("invalid", address(1));
    }

    function testFail_modify_parameters_invalid_param_uint() public {
        dripper.modifyParameters("invalid", 1);
    }

    function testFail_modify_parameters_unauthorized_address() public {
        unauth.doModifyParameters("requestor", address(1));
    }

    function testFail_modify_parameters_unauthorized_uint() public {
        unauth.doModifyParameters("rewardPerBlock", 5 ether);
    }

    function test_transfer_token_out() public {
        dripper.transferTokenOut(address(0xfab), 25 ether);
        assertEq(coin.balanceOf(address(0xfab)), 25 ether);
    }

    function testFail_transfer_token_null_dst() public {
        dripper.transferTokenOut(address(0), 25 ether);
    }

    function testFail_transfer_token_null_amount() public {
        dripper.transferTokenOut(address(0xfab), 0);
    }

    function testFail_transfer_token_unauthorized() public {
        unauth.doTransferTokenOut(address(0xfab), 50 ether);
    }

    function test_drip_reward() public {
        hevm.roll(block.number + 1);
        requestor.request(address(dripper));
        assertEq(coin.balanceOf(address(requestor)), 1 ether);
        assertEq(dripper.lastRewardBlock(), block.number);

        // requsting again same block
        requestor.request(address(dripper));
        assertEq(coin.balanceOf(address(requestor)), 1 ether); // unchanged
        assertEq(dripper.lastRewardBlock(), block.number);

        hevm.roll(block.number + 1);
        requestor.request(address(dripper));
        assertEq(coin.balanceOf(address(requestor)), 2 ether);
        assertEq(dripper.lastRewardBlock(), block.number);

        // requsting again same block
        requestor.request(address(dripper));
        assertEq(coin.balanceOf(address(requestor)), 2 ether); // unchanged
        assertEq(dripper.lastRewardBlock(), block.number);

        hevm.roll(block.number + 20);
        requestor.request(address(dripper));
        assertEq(coin.balanceOf(address(requestor)), 22 ether);
        assertEq(dripper.lastRewardBlock(), block.number);

        hevm.roll(block.number + 120);
        requestor.request(address(dripper));
        assertEq(coin.balanceOf(address(requestor)), initTokenAmount); // transferred what is left
        assertEq(dripper.lastRewardBlock(), block.number);

        hevm.roll(block.number + 120);
        requestor.request(address(dripper)); // does not revert without balance
        assertEq(dripper.lastRewardBlock(), block.number);
    }

    function testFail_drip_unauthorized() public {
        hevm.roll(block.number + 1);
        unauth.doDrip();
    }
}
