// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IToken {
    function decimals() external view returns (uint256);
    function transfer(address spender, uint value) external returns(bool);
    function transferFrom(address from, address to, uint value) external returns(bool);
}

struct Staking {
    address stakeToken;
    uint256 stakeAmount;
    uint256 startBlockNumber;
    uint256 lastClaimBlockNumber;
    uint256 closeBlockNumber;
    uint256 blockRewards;
    address referrer;
    uint256 claimedAmount;
    bool closed;
    address staker;
    uint256 packageIdx;
}

struct Package {
    uint256 amount;
    uint256 period;
    uint256 rate;
}

contract SmarTradeContract {
    address public owner;
    Package[] public packages;
    Staking[] public stakings;
    mapping(address => uint256[]) public stakingsIdxForUser;
    mapping(address => uint256[]) public stakingsReferIdxForUser;
    
    uint256 public constant referrerRate = 1000;
    uint256 public constant precision = 10000;

    uint256 public constant NumBlockPerDay = 7200; // Number of blocks per day

    event Staked(address indexed staker, address tokenAddr, uint256 packageIdx);
    event UnStaked(address indexed staker, address tokenAddr, uint256 packageIdx);
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    event PackageAdded(uint256 packageIdx, uint256 amount, uint256 period, uint256 rate);

    constructor() {
        owner = msg.sender;
        emit OwnerSet(address(0), owner);
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "not owner");
        _;
    }

    modifier onlyStaker(uint256 stakingIdx) {
        require(stakingIdx < stakings.length, "Invalid staking index");
        require(msg.sender == stakings[stakingIdx].staker, "Not staker");
        _;
    }

    function renewOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    function addPackages(uint256[] memory amounts, uint256[] memory dayCounts, uint256[] memory rates) public onlyOwner {
        for(uint256 i = 0; i < amounts.length; ++i) {
            addPackage(amounts[i], dayCounts[i], rates[i]);
        }
    }

    function addPackage(uint256 amount, uint256 dayCount, uint256 rate) public onlyOwner {
        Package memory package = Package(amount, dayCount * NumBlockPerDay, rate);
        packages.push(package);
        emit PackageAdded(packages.length - 1, amount, dayCount, rate);
    }

    function editPackage(uint256 packageIdx, uint256 amount, uint256 dayCount, uint256 rate) public onlyOwner {
        require(packageIdx < packages.length, "Invalid package index");
        packages[packageIdx].amount = amount;
        packages[packageIdx].period = dayCount * NumBlockPerDay;
        packages[packageIdx].rate = rate;
    }

    function getAllPackages() public view returns(Package[] memory) {
        return packages;
    }

    function getStakingIdxForUser(address user) public view returns(uint256[] memory) {
        return stakingsIdxForUser[user];
    }

    function getStakingReferIdxForUser(address user) public view returns(uint256[] memory) {
        return stakingsReferIdxForUser[user];
    }

    function getActiveStakingsCount() public view returns(uint256) {
        uint256 count = 0;
        for(uint256 i = 0; i < stakings.length; i ++) {
            if(!stakings[i].closed) {
                count ++;
            }
        }
        return count;
    }

    function getStakingsCount() public view returns(uint256) {
        return stakings.length;
    }

    function getActiveStakingsAmount() public view returns(uint256) {
        uint256 totalValue = 0;
        for(uint256 i = 0; i < stakings.length; i ++) {
            if(stakings[i].closed) continue;
            uint256 pi = stakings[i].packageIdx;
            totalValue += packages[pi].amount;
        }
        return totalValue;
    }

    function stake(uint256 packageIdx, address tokenAddr, address referrer) public onlyEOA {
        require(referrer != msg.sender && referrer != address(0), "Referrer is equal to staker or null");
        require(tokenAddr != address(0), "Invalid stake token address");
        require(packageIdx < packages.length, "Invalid package index");
        Package memory package = packages[packageIdx];
        Staking memory newStaking = Staking(
            tokenAddr,
            package.amount * (10 ** IToken(tokenAddr).decimals()),
            block.number,
            block.number,
            block.number + package.period,
            0,
            referrer,
            0,
            false,
            msg.sender,
            packageIdx
        );
        newStaking.blockRewards = newStaking.stakeAmount * package.rate / precision / NumBlockPerDay;

        bool transferTokenRes = IToken(newStaking.stakeToken).transferFrom(newStaking.staker, address(this), newStaking.stakeAmount);
        require(transferTokenRes);

        stakings.push(newStaking);
        stakingsIdxForUser[msg.sender].push(stakings.length - 1);
        stakingsReferIdxForUser[referrer].push(stakings.length - 1);

        emit Staked(msg.sender, tokenAddr, packageIdx);
    }

    function claim() public onlyEOA {
        uint256[] storage stakingsIdxArray = stakingsIdxForUser[msg.sender];
        for(uint256 i = 0; i < stakingsIdxArray.length; ++i) {
            claimEachStaking(stakingsIdxArray[i]);
        }
    }

    function claimEachStaking(uint256 stakingId) public onlyEOA onlyStaker(stakingId) {
        Staking storage staking = stakings[stakingId];
        
        if(staking.closed) return;

        uint256 rewards = calcRewards(stakingId);

        if(staking.closeBlockNumber <= block.number) {
            rewards += staking.stakeAmount;
            staking.closed = true;
        }

        staking.lastClaimBlockNumber = block.number;
        staking.claimedAmount = staking.claimedAmount + rewards;

        bool claimRes = IToken(staking.stakeToken).transfer(staking.staker, rewards);
        require(claimRes);
        if(staking.closed) {
            bool referRewardRes = IToken(staking.stakeToken).transfer(staking.referrer, (staking.claimedAmount - staking.stakeAmount) * referrerRate / precision);
            require(referRewardRes);
        }
    }

    function unStake(uint256 stakingId) public onlyEOA onlyStaker(stakingId) {
        Staking storage staking = stakings[stakingId];
        
        require(!staking.closed, "already closed");
        if(staking.closeBlockNumber < block.number) claimEachStaking(stakingId);

        if(staking.claimedAmount < staking.stakeAmount) {
            bool unstakeRes = IToken(staking.stakeToken).transfer(staking.staker, staking.stakeAmount - staking.claimedAmount);
            require(unstakeRes);
            staking.claimedAmount = staking.stakeAmount;
        }

        staking.closed = true;
        staking.lastClaimBlockNumber = block.number;
        
        emit UnStaked(msg.sender, staking.stakeToken, staking.packageIdx);
    }

    function calcRewards(uint256 stakeIdx) public view returns(uint256) {
        uint256 start = stakings[stakeIdx].lastClaimBlockNumber;
        uint256 end = stakings[stakeIdx].closeBlockNumber < block.number ? stakings[stakeIdx].closeBlockNumber : block.number;
        if(end <= start) return 0;
        uint256 rewards =  stakings[stakeIdx].blockRewards * (end - start);
        rewards = rewards + rewards * (end - start) * 4 / (stakings[stakeIdx].closeBlockNumber - start) / 11;
        return rewards;
    }

    function depositToVault(address token, address to, uint256 amount) public onlyOwner {
        bool depositRes = IToken(token).transfer(to, amount);
        require(depositRes);
    }
    
    modifier onlyEOA() {
        require(!isContract(msg.sender), "called by contract");
        _;
    }

    function isContract(address _addr) private view returns (bool) {
        return (_addr.code.length > 0);
    }

}