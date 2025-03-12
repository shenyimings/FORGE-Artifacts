// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./BondingCurve/IBondingCurve.sol";
import "./NinjaToken.sol";
import "./NinjaTeam.sol";

contract NinjaAMO is Ownable {
    using SafeMath for uint256;

    uint256 public softcap; //Max 1M Ninja tokens soft cap
    uint256 public hardcap; //Max 2M Ninja tokens hard cap
    IBondingCurve public CURVE;
    NinjaToken public NINJA;
    uint256 public virtualBalance = 36000000000000000000; //virtual start with 36 BNB to adjust price for Curve
    uint32 public reserveRatio = 100000; // 100 000 ppm = %10 Connector Weight
    uint256 public virtualSupply = 1200000000000000000000000; //virtual supply as 1200000 minted already
    uint256 public totalNinjaSold;
    NinjaTeam public Team;

    struct ReferralBonus {
        uint256 count;
        uint256 amount;
    }

    mapping(address => uint256) public deposits;
    mapping(address => ReferralBonus) public bonus;
    mapping(address => uint256) public purchases;

    event ReferrerEarned(
        address indexed beneficiary,
        address indexed account,
        uint256 amount
    );
    event Minted(address sender, uint256 amount, uint256 deposit);
    constructor(
        IBondingCurve _curve,
        NinjaToken _ninja,
        NinjaTeam  _team
    ) public {
        CURVE = _curve;
        NINJA = _ninja;
        Team = _team;                       
    }

    receive() external payable {
        buy(msg.value);
    }
    function initialize(uint256 _softcap, uint256 _hardcap) public onlyOwner {
        require(_softcap <= 1000000000000000000000000, "Maximum softcap 1M ninja Tokens");
        require(_hardcap <= 2000000000000000000000000, "Maximum hardcap 2M ninja Tokens");
        softcap = _softcap;
        hardcap = _hardcap;    
    }
    // simple buy without Referral
    function buy(uint256 _deposit) public payable whenHardCapNotReached {
        require(msg.value == _deposit);
        require(msg.sender != address(0));
        require(_deposit > 0, "Deposit Must Greater then zero");
        uint256 estimate = getEstimatedContinuousMintReward(_deposit);
        uint256 _masterChefShare = estimate.mul(10).div(100); // 0.1x 
        NINJA.addRewardMWallet(_masterChefShare);
        _buy(_deposit, msg.sender, estimate);
    }

    //buy with Refferral
    function buyWithRef(address _referrer, uint256 _deposit)
        public
        payable
        whenHardCapNotReached
    {
        require(msg.value == _deposit);
        require(msg.sender != address(0));
        require(_deposit > 0, "Deposit Must Greater then zero");
        require(_referrer != address(0), "Referral code is invalid");
        require(_referrer != msg.sender,"You can't use your own referral code");
        uint256 estimate = getEstimatedContinuousMintReward(_deposit);
        uint256 _refferalShare = estimate.mul(10).div(100); // 0.1x 
        NINJA.mint(_referrer, _refferalShare);
        _buy(_deposit, msg.sender, estimate);
        bonus[_referrer].count = bonus[_referrer].count.add(1);
        bonus[_referrer].amount = bonus[_referrer].amount.add(_refferalShare);
        emit ReferrerEarned(_referrer, msg.sender, _refferalShare);
        
    }
    function getEstimatedContinuousMintReward(uint256 _reserveTokenAmount)
        public
        view
        returns (uint256)
    {
        return
            CURVE.calculatePurchaseReturn(
                virtualSupply,
                virtualBalance,
                reserveRatio,
                _reserveTokenAmount
            );
    }

   function withdrawBNB() public onlyOwner {
        uint256 BnbBal = address(this).balance;
        uint256 x3 = BnbBal.mul(30).div(100);
        uint256 x1 = BnbBal.mul(10).div(100);
        payable(Team.Donatello()).transfer(x3);
        payable(Team.Raphael()).transfer(x3);
        payable(Team.Michelangelo()).transfer(x3);
        payable(Team.Leonardo()).transfer(x1);
    }
    function _buy(uint256 _deposit, address _user, uint256 _estimate) private {
        NINJA.mint(_user, _estimate);
        uint256 _teamShare = _estimate.mul(30).div(100); // 0.3x 
        NINJA.mint(address(Team), _teamShare);
        virtualBalance = virtualBalance.add(_deposit);
        virtualSupply = virtualSupply.add(_estimate);
        totalNinjaSold = totalNinjaSold.add(_estimate);
        deposits[_user] = deposits[_user].add(_deposit);
        purchases[_user] = purchases[_user].add(_estimate);
        emit Minted(_user, _estimate, _deposit);
    }
    modifier whenHardCapNotReached() {
        require(
            totalNinjaSold < hardcap,
            "NinjaAMO Stopped : Sales reached at hardcap"
        );
        _;
    }

}
