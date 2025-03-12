pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import './libs/IBEP20.sol';
import './libs/SafeBEP20.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract ModComp is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each mod.
    struct UserInfo {
        uint256 lastBlockClaim; // last claimed block
        uint256 claimPerBlock; //  block payment
        uint256 endBlock; // end of compensation
    }

    // TEA TOKEN
    IBEP20 public paymentToken;

    // Info of each mod
    mapping (address => UserInfo) public userInfo;

    event Claim(address indexed user, uint256 amount);
    event AddMod(address indexed user, uint256 claimPerBlock);
    event RemoveMod(address indexed user);

    constructor(
        IBEP20 _paymentToken
    ) public {
        paymentToken = _paymentToken;
    }

    function claim() public {
        uint256 reward = pendingReward(msg.sender);
        if (reward > 0) {
            UserInfo storage user = userInfo[msg.sender];
            user.lastBlockClaim = min(block.number, user.endBlock);
            paymentToken.transfer(address(msg.sender), reward);
            emit Claim(msg.sender, reward);     
        }
    }

    // View function to see pending Reward on frontend.
    function pendingReward(address userAddress) public view returns (uint256) {
        UserInfo storage user = userInfo[userAddress];
        uint256 claimableBlocks = min(block.number, user.endBlock) - user.lastBlockClaim;
        uint256 claimablePayment = claimableBlocks.mul(user.claimPerBlock);
        return claimablePayment;
    }

    function addMod(address mod, uint256 claimPerBlock) public onlyOwner {
        UserInfo storage user = userInfo[mod];
        user.lastBlockClaim = block.number;
        user.claimPerBlock = claimPerBlock;
        user.endBlock = 1115342314;
        emit AddMod(mod, claimPerBlock);
    }

    function removeMod(address mod) public onlyOwner {
        delete userInfo[mod];
        emit RemoveMod(mod);
    }

    function updateCompensation(address mod, uint256 claimPerBlock) public onlyOwner {
        UserInfo storage user = userInfo[mod];
        user.claimPerBlock = claimPerBlock;
    }

    /**
     * @dev block = 0 sets the current block as the endBlock.
     */
    function stopCompensation(address mod, uint256 endBlock) public onlyOwner {
        UserInfo storage user = userInfo[mod];
        if (endBlock == 0) {
            user.endBlock = block.number;
        } else {
            user.endBlock = endBlock;
        }
    }

    // Withdraw reward. EMERGENCY ONLY.
    function emergencyPaymentWithdraw(uint256 amount) public onlyOwner {
        paymentToken.safeTransfer(address(msg.sender), amount);
    }

     /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

}