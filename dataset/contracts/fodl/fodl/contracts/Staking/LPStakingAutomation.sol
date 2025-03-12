// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './LPStaking.sol';

contract LPStakingAutomation is Ownable {
    using SafeMath for uint256;

    IERC20 public immutable fodlToken;
    address public immutable treasury;
    LPStaking public immutable fodlEthSLPStaking;
    LPStaking public immutable fodlUsdcSLPStaking;

    uint256 public rewardNumber;

    constructor(
        address _fodlToken,
        address _treasury,
        address _fodlEthSLPStaking,
        address _fodlUsdcSLPStaking,
        uint256 _firstRewardNumber
    ) public {
        fodlToken = IERC20(_fodlToken);
        treasury = _treasury;
        fodlEthSLPStaking = LPStaking(_fodlEthSLPStaking);
        fodlUsdcSLPStaking = LPStaking(_fodlUsdcSLPStaking);
        rewardNumber = _firstRewardNumber;
    }

    function notifyRewards() external {
        uint256 amount = getRewardAmount(rewardNumber++);
        sendRewards(fodlEthSLPStaking, amount);
        sendRewards(fodlUsdcSLPStaking, amount);
    }

    function sendRewards(LPStaking stakingContract, uint256 amount) private {
        uint256 periodFinish = stakingContract.periodFinish();
        require(periodFinish - 1 hours < now, 'Too early to send rewards');
        require(periodFinish + 12 hours > now, 'Too late to send rewards');
        fodlToken.transferFrom(treasury, address(stakingContract), amount);
        stakingContract.notifyRewardAmount(amount);
    }

    function transferLPStakingOwnership(LPStaking stakingContract, address newOwner) external onlyOwner {
        stakingContract.transferOwnership(newOwner);
    }

    function getRewardAmount(uint256 index) private pure returns (uint256 amount) {
        amount = [
            370835,
            331858,
            306639,
            288351,
            274179,
            262708,
            253131,
            244949,
            237834,
            231557,
            225954,
            220905,
            216317,
            212119,
            208255,
            204678,
            201352,
            198247,
            195336,
            192600,
            190018,
            187577,
            185262,
            183062,
            180967,
            178967,
            177056,
            175225,
            173470,
            171784,
            170162,
            168600,
            167094,
            165641,
            164236,
            162878,
            161562,
            160288,
            159051,
            157851,
            156685,
            155552,
            154450,
            153376,
            152331,
            151312,
            150318,
            149348,
            148401,
            147476,
            146572,
            145688,
            144824,
            143978,
            143149,
            142338,
            141543,
            140763,
            139999,
            139249,
            138513,
            137791,
            137082,
            136385,
            135701,
            135028,
            134367,
            133717,
            133077,
            132448,
            131828,
            131219,
            130618,
            130027,
            129445,
            128871,
            128305,
            127748,
            127199,
            126657,
            126122,
            125595,
            125075,
            124562,
            124055,
            123555,
            123061,
            122573,
            122092,
            121616,
            121146,
            120682,
            120223,
            119769,
            119321,
            118877,
            118439,
            118005,
            117577,
            117153,
            116733,
            116318,
            115907,
            115501,
            115098,
            114700,
            114306,
            113915,
            113529,
            113146,
            112767,
            112392,
            112020,
            111651,
            111286,
            110925,
            110566,
            110211,
            109859,
            109510,
            109164,
            108821,
            108481,
            108144,
            107810,
            107478,
            107150,
            106824,
            106500,
            106179,
            105861,
            105545,
            105232,
            104921,
            104613,
            104306,
            104003,
            103701,
            103402,
            103105,
            102810,
            102517,
            102226,
            101937,
            101651,
            101366,
            101083,
            100803,
            100524,
            100247,
            99972,
            99699,
            99428,
            99158,
            98890,
            98624,
            98360,
            98097,
            97836,
            97577,
            97319,
            97063,
            96808,
            96555
        ][index];
        amount = amount.mul(1e18);
    }
}
