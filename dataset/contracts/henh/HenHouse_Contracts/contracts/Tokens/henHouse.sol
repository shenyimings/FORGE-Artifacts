// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.7;

import './henHouseERC20.sol';
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract HenHouse is HenHouseERC20, ReentrancyGuard {
    using SafeMath for uint256;

    mapping(address => bool) bots;
    
    uint256 public maxSupply = 50 * 10**6 * 10**18;
    uint256 public supplyToDate;
    
    uint256 public amountSales = 5 * 10**6 * 10**18;
    uint256 public amountTeam = 75 * 10**5 * 10**18;
    uint256 public amountPlayToEarn = 175 * 10**5 * 10**18;
    uint256 public amountStaking = 10 * 10**6 * 10**18;
    uint256 public amountReserve = 65 * 10**5 * 10**18;
    uint256 public amountSponsors = 25 * 10**5 * 10**18;
    uint256 public amountAirDrop = 1 * 10**6 * 10**18;
    uint private contractCreateDate; // 2018-01-01 00:00:00
    
    mapping(uint256 => uint256) public halvingSchedules;
    mapping(uint256 => bool) public halvingDailyRunCheck;


    address public teamWallet;
    address public rewardsWallet;
    address public stakingWallet;
    address public reserveWallet;
    address public sponsorsWallet;
    address public airdropWallet;
    address public halvingManager;

    bool public antiBotEnabled;
    uint256 public antiBotDuration = 6 minutes;
    uint256 public antiBotTime;
    uint256 public antiBotAmount;

    modifier onlyHalvingManager(address _hm) {
        require(halvingManager == _hm, "not Halving Manager");
        _;
    }

    // just in case we need it, to be able to change the halving manager wallet
    function setHalvingManager(address _hm) public onlyOwner {
        halvingManager = _hm;
    }    

    constructor(string memory name, string memory symbol, address _router,address _team,address _rewards,address _staking,address _reserve,address _sponsor, address _airdrop)
        HenHouseERC20(name, symbol, _router)
    {
        teamWallet = _team;
        rewardsWallet = _rewards;
        stakingWallet = _staking;
        reserveWallet = _reserve;
        sponsorsWallet = _sponsor;
        airdropWallet = _airdrop;
        halvingManager = _msgSender();
        // only release the tokens for pre-sale and airdropp/events
        _mint(_msgSender(), amountAirDrop.add(amountSales) );

        contractCreateDate = block.timestamp;
        
        halvingSchedules[1] = 90; // day 0 to 90
        halvingSchedules[2] = 180; // day 91 to 180
        halvingSchedules[3] = 270; // day 181 to 270 and avobe
    }
    // function for excluding bots
    function setBots(address _bots) external onlyOwner {
        require(!bots[_bots]);

        bots[_bots] = true;
    }

    // function for handling bots on transfers
   function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (
            antiBotTime > block.timestamp &&
            amount > antiBotAmount &&
            bots[sender]
        ) {
            revert("Anti Bot");
        }
        super._transfer(sender, recipient, amount);
    }

    // Function to handle the halving schedule. We will be minting tokens from the day 1 to the end of the proyect
    // in 5 years
    function mintTokensOnHalvingSchedule() external onlyHalvingManager(_msgSender()) {
        require(_msgSender() != address(0), "0x is not accepted here");
        uint today_date = block.timestamp;
        uint days_from_creation = ((today_date - contractCreateDate) / 60 / 60 / 24) + 1; // diff in days
        uint total_to_mint = 0;
        require(!halvingDailyRunCheck[days_from_creation],"Halving daily schedule already ran");
        
        if(days_from_creation <= halvingSchedules[1]) {
            total_to_mint = 88 * 10**3 * 10**18;
        } 
        else if(days_from_creation <= halvingSchedules[2]){
            total_to_mint = 44 * 10**3 * 10**18;
        } 
        else if(days_from_creation <= halvingSchedules[3]){
            total_to_mint = 22 * 10**3 * 10**18;
        } 
        else if(days_from_creation > halvingSchedules[3]){
            total_to_mint = 20 * 10**3 * 10**18;
        }

        supplyToDate = supplyToDate + total_to_mint;
        require(supplyToDate < maxSupply, "Max supply reached");

        _mint(teamWallet, total_to_mint.mul(15).div(100) );
        _mint(rewardsWallet, total_to_mint.mul(35).div(100) );
        _mint(stakingWallet, total_to_mint.mul(20).div(100) );
        _mint(reserveWallet, total_to_mint.mul(13).div(100) );
        _mint(sponsorsWallet, total_to_mint.mul(5).div(100) );
        
        halvingDailyRunCheck[days_from_creation] = true;
    }    

}