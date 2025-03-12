pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import './FarmerLandNFT.sol';

// MasterChef is the master of Plush. He can make Plush and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once PLUSH is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is IERC721Receiver, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    function onERC721Received(
        address,
        address,
        uint,
        bytes calldata
    ) external override returns(bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // max NFTs a single user can stake in a pool. This is to ensure finite gas usage on emergencyWithdraw.
    uint public MAX_NFT_COUNT = 150;

    // Stores which nft series are currently allowed.
    EnumerableSet.AddressSet internal nftAddressAllowListSet;
    // Stores which nft series has ever been allowed, even if once removed.
    EnumerableSet.AddressSet internal nftAddressAllowListSetHistoric;

    // How much weighting an NFT has in the pool, before their ability boost is added.
    mapping(address => uint) internal baseWeightingMap;

    // Mapping of user address to total nfts staked.
    mapping(address => uint) public userStakeCounts;

    function hasUserStakedNFT(address _user, address _series, uint _tokenId) external view returns (bool) {
        return userStakedMap[_user][_series][_tokenId];
    }

    // Mapping of NFT contract address to which NFTs a user has staked.
    mapping(address => mapping(address => mapping(uint => bool))) public userStakedMap;
    // Mapping of NFT contract address to NFTs ability at the time a user has staked for the user.
    mapping(address => mapping(address => mapping(uint => uint))) public userAbilityOnStakeMap;
    // Mapping of NFT contract address to array of NFT IDs a user has staked.
    mapping(address => mapping(address => EnumerableSet.UintSet)) private userNftIdsMapArray;


    IERC20 public constant usdcCurrency = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 public immutable wheatCurrency;

    uint public totalUSDCCollected = 0;
    uint public totalWHEATCollected = 0;

    uint public accDepositUSDCRewardPerShare = 0;
    uint public accDepositWHEATRewardPerShare = 0;


    uint public promisedUSDC = 0;
    uint public promisedWHEAT = 0;

    // default to 12 hours
    uint public usdcDistributionTimeFrameSeconds = 12 hours;
    uint public wheatDistributionTimeFrameSeconds = 12 hours;

    // Info of each user.
    struct UserInfo {
        uint amount;         // How many LP tokens the user has provided.
        uint usdcRewardDebt;     // Reward debt
        uint wheatRewardDebt;     // Reward debt
    }

    // Info of each pool.
    struct PoolInfo {
        uint lastRewardTimestamp;  // Last block timestamp that USDC and WHEAT distribution occurs.
        uint totalLocked;      // total units locked in the pool
    }

    // Info of each pool.
    PoolInfo public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;
    // The block timestamp when emmissions start.
    uint public startTimestamp;

    event Deposit(address indexed user, bool isHarvest, address series, uint tokenId);
    event Withdraw(address indexed user, address series, uint tokenId);
    event EmergencyWithdraw(address indexed user,uint amount);
    event USDCTransferredToUser(address recipient, uint usdcAmount);
    event WHEATTransferredToUser(address recipient, uint usdcAmount);
    event SetUSDCDistributionTimeFrame(uint distributionTimeFrameSeconds);
    event SetWHEATDistributionTimeFrame(uint distributionTimeFrameSeconds);
    event NftAddressAllowListSet(address series, bool allowed);
    event NFTStakeAbilityRefreshed(address _user, address _series, uint _tokenId);

    constructor(
        uint _startTimestamp,
        address _wheatAddress
    ) public {
        poolInfo.lastRewardTimestamp = _startTimestamp;
        wheatCurrency = IERC20(_wheatAddress);
    }

    // View function to see pending USDCs on frontend.
    function pendingUSDC(address _user) external view returns (uint) {
        UserInfo storage user = userInfo[_user];

        return ((user.amount * accDepositUSDCRewardPerShare) / (1e24)) - user.usdcRewardDebt;
    }

    // View function to see pending USDCs on frontend.
    function pendingWHEAT(address _user) external view returns (uint) {
        UserInfo storage user = userInfo[_user];

        return ((user.amount * accDepositWHEATRewardPerShare) / (1e24)) - user.wheatRewardDebt;
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        PoolInfo storage pool = poolInfo;
        if (block.timestamp <= pool.lastRewardTimestamp)
            return;

        if (pool.totalLocked > 0) {
            uint usdcRelease = getUSDCDrip();

            if (usdcRelease > 0) {
                accDepositUSDCRewardPerShare = accDepositUSDCRewardPerShare + ((usdcRelease * 1e24) / pool.totalLocked);
                totalUSDCCollected = totalUSDCCollected + usdcRelease;
            }

            uint wheatRelease = getWHEATDrip();

            if (wheatRelease > 0) {
                accDepositWHEATRewardPerShare = accDepositWHEATRewardPerShare + ((wheatRelease * 1e24) / pool.totalLocked);
                totalWHEATCollected = totalWHEATCollected + wheatRelease;
            }
        }

        pool.lastRewardTimestamp = block.timestamp;
    }

    function updateAbilityForDeposit(address _userAddress, address _series, uint _tokenId) external nonReentrant {
        require(isNftSeriesAllowed(_series), "nftNotAllowed to be staked!");
        require(userStakedMap[_userAddress][_series][_tokenId], "nft not staked by specified user");

        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[_userAddress];

        updatePool();

        payPendingUSDCWHEATRewards(_userAddress);

        uint oldAbility = userAbilityOnStakeMap[_userAddress][_series][_tokenId];

        user.amount = user.amount - oldAbility;
        pool.totalLocked = pool.totalLocked - oldAbility;

        uint newAbility = FarmerLandNFT(_series).getAbility(_tokenId);

        userAbilityOnStakeMap[_userAddress][_series][_tokenId] = newAbility;

        user.amount = user.amount + newAbility;
        pool.totalLocked = pool.totalLocked + newAbility;

        user.usdcRewardDebt = ((user.amount * accDepositUSDCRewardPerShare) / 1e24);
        user.wheatRewardDebt = ((user.amount * accDepositWHEATRewardPerShare) / 1e24);

        emit NFTStakeAbilityRefreshed(_userAddress, _series, _tokenId);
    }

    // Deposit NFTs to MasterChef
    function deposit(address _series, uint _tokenId, bool isHarvest) public nonReentrant {
        require(isNftSeriesAllowed(_series), "nftNotAllowed to be staked!");
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];

        updatePool();

        payPendingUSDCWHEATRewards(msg.sender);

        if (!isHarvest) {
            userStakeCounts[msg.sender]++;
            require(userStakeCounts[msg.sender] <= MAX_NFT_COUNT,
                "you have aleady reached the maximum amount of NFTs you can stake in this pool");
            IERC721(_series).safeTransferFrom(msg.sender, address(this), _tokenId);

            userStakedMap[msg.sender][_series][_tokenId] = true;

            userNftIdsMapArray[msg.sender][_series].add(_tokenId);

            uint ability = FarmerLandNFT(_series).getAbility(_tokenId);

            userAbilityOnStakeMap[msg.sender][_series][_tokenId] = ability;

            user.amount = user.amount + baseWeightingMap[_series] + ability;
            pool.totalLocked = pool.totalLocked + baseWeightingMap[_series] + ability;
        }

        user.usdcRewardDebt = ((user.amount * accDepositUSDCRewardPerShare) / 1e24);
        user.wheatRewardDebt = ((user.amount * accDepositWHEATRewardPerShare) / 1e24);

        emit Deposit(msg.sender, isHarvest, _series, _tokenId);
    }

    // Withdraw NFT from MasterChef.
    function withdraw(address _series, uint _tokenId) external nonReentrant {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];

        updatePool();

        payPendingUSDCWHEATRewards(msg.sender);

        uint withdrawQuantity = 0;

        require(userStakedMap[msg.sender][_series][_tokenId], "nft not staked");

        userStakeCounts[msg.sender]--;

        userStakedMap[msg.sender][_series][_tokenId] = false;

        userNftIdsMapArray[msg.sender][_series].remove(_tokenId);

        withdrawQuantity = userAbilityOnStakeMap[msg.sender][_series][_tokenId];

        user.amount = user.amount - baseWeightingMap[_series] - withdrawQuantity;
        pool.totalLocked = pool.totalLocked - baseWeightingMap[_series] - withdrawQuantity;

        userAbilityOnStakeMap[msg.sender][_series][_tokenId] = 0;

        user.usdcRewardDebt = ((user.amount * accDepositUSDCRewardPerShare) / 1e24);
        user.wheatRewardDebt = ((user.amount * accDepositWHEATRewardPerShare) / 1e24);

        IERC721(_series).safeTransferFrom(address(this), msg.sender, _tokenId);

        emit Withdraw(msg.sender, _series, _tokenId);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() external nonReentrant {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        uint amount = user.amount;

        for (uint i = 0;i<nftAddressAllowListSetHistoric.length();i++) {
            address series = nftAddressAllowListSetHistoric.at(i);
            EnumerableSet.UintSet storage nftStakedCollection = userNftIdsMapArray[msg.sender][series];

            for (uint j = 0;j < nftStakedCollection.length();j++) {
                uint nftId = nftStakedCollection.at(j);

                userAbilityOnStakeMap[msg.sender][series][nftId] = 0;

                userStakedMap[msg.sender][series][nftId] = false;

                IERC721(series).safeTransferFrom(address(this), msg.sender, nftId);
            }

            // empty user nft Ids array
            delete userNftIdsMapArray[msg.sender][series];
        }

        user.amount = 0;
        user.usdcRewardDebt = 0;
        user.wheatRewardDebt = 0;

        userStakeCounts[msg.sender] = 0;

        // In the case of an accounting error, we choose to let the user emergency withdraw anyway
        if (pool.totalLocked >=  amount)
            pool.totalLocked = pool.totalLocked - amount;
        else
            pool.totalLocked = 0;

        emit EmergencyWithdraw(msg.sender, amount);
    }

    function viewStakerUserNFTs(address _series, address userAddress) public view returns (uint[] memory){
        EnumerableSet.UintSet storage nftStakedCollection = userNftIdsMapArray[userAddress][_series];

        uint[] memory nftStakedArray = new uint[](nftStakedCollection.length());

        for (uint i = 0;i < nftStakedCollection.length();i++)
           nftStakedArray[i] = nftStakedCollection.at(i);

        return nftStakedArray;
    }

    // Pay pending USDC and WHEAT.
    function payPendingUSDCWHEATRewards(address _user) internal {
        UserInfo storage user = userInfo[_user];

        uint usdcPending = ((user.amount * accDepositUSDCRewardPerShare) / 1e24) - user.usdcRewardDebt;

        if (usdcPending > 0) {
            // send rewards
            transferUSDCToUser(_user, usdcPending);
        }

        uint wheatPending = ((user.amount * accDepositWHEATRewardPerShare) / 1e24) - user.wheatRewardDebt;

        if (wheatPending > 0) {
            // send rewards
            transferWHEATToUser(_user, wheatPending);
        }
    }

    function isNftSeriesAllowed(address _series) public view returns (bool){
        return nftAddressAllowListSet.contains(_series);
    }

    /**
     * @dev set which Nfts are allowed to be staked
     * Can only be called by the current operator.
     */
    function setNftAddressAllowList(address _series, bool allowed, uint baseWeighting) external onlyOwner {
        require(_series != address(0), "_series cant be 0 address");

        bool wasOnceAdded = nftAddressAllowListSetHistoric.contains(_series);
        require(wasOnceAdded || baseWeighting > 0 && baseWeighting <= 200e4, "baseWeighting out of range!");

        if (!wasOnceAdded) {
            baseWeightingMap[_series] = baseWeighting;

            if (allowed)
                nftAddressAllowListSetHistoric.add(_series);
        }

        bool alreadyIsAdded = nftAddressAllowListSet.contains(_series);

        if (allowed) {
            if (!alreadyIsAdded) {
                nftAddressAllowListSet.add(_series);
            }
        } else {
            if (alreadyIsAdded) {
                nftAddressAllowListSet.remove(_series);
            }
        }

        emit NftAddressAllowListSet(_series, allowed);
    }

    /**
     * @dev set the maximum amount of NFTs a user is allowed to stake, useful if
     * too much gas is used by emergencyWithdraw
     * Can only be called by the current operator.
     */
    function set_MAX_NFT_COUNT(uint new_MAX_NFT_COUNT) external onlyOwner {
        require(new_MAX_NFT_COUNT >= 20, "MAX_NFT_COUNT must be greater than 0");
        require(new_MAX_NFT_COUNT <= 150, "MAX_NFT_COUNT must be less than 150");

        MAX_NFT_COUNT = new_MAX_NFT_COUNT;
    }

    /**
     * Get the rate of USDC the masterchef is emitting
     */
    function getUSDCDripRate() external view returns (uint) {
        uint usdcBalance = usdcCurrency.balanceOf(address(this));
        if (promisedUSDC > usdcBalance)
            return 0;
        else
            return (usdcBalance - promisedUSDC) / usdcDistributionTimeFrameSeconds;
    }

    /**
     * Get the rate of WHEAT the masterchef is emitting
     */
    function getWHEATDripRate() external view returns (uint) {
        uint wheatBalance = wheatCurrency.balanceOf(address(this));
        if (promisedWHEAT > wheatBalance)
            return 0;
        else
            return (wheatBalance - promisedWHEAT) / wheatDistributionTimeFrameSeconds;
    }

    /**
     * get the amount of new USDC we have taken account for, and update lastUSDCDistroTimestamp and promisedUSDC
     */
    function getUSDCDrip() internal returns (uint) {
        uint usdcBalance = usdcCurrency.balanceOf(address(this));
        if (promisedUSDC > usdcBalance)
            return 0;

        uint usdcAvailable = usdcBalance - promisedUSDC;

        // only provide a drip if there has been some seconds passed since the last drip
        uint blockSinceLastDistro = block.timestamp > poolInfo.lastRewardTimestamp ? block.timestamp - poolInfo.lastRewardTimestamp : 0;

        // We distribute the usdc assuming the old usdc balance wanted to be distributed over usdcDistributionTimeFrameSeconds seconds.
        uint usdcRelease = (blockSinceLastDistro * usdcAvailable) / usdcDistributionTimeFrameSeconds;

        usdcRelease = usdcRelease > usdcAvailable ? usdcAvailable : usdcRelease;

        promisedUSDC += usdcRelease;

        return usdcRelease;
    }

    /**
     * get the amount of new WHEAT we have taken account for, and update lastWHEATDistroTimestamp and promisedWHEAT
     */
    function getWHEATDrip() internal returns (uint) {
        uint wheatBalance = wheatCurrency.balanceOf(address(this));
        if (promisedWHEAT > wheatBalance)
            return 0;

        uint wheatAvailable = wheatBalance - promisedWHEAT;

        // only provide a drip if there has been some seconds passed since the last drip
        uint blockSinceLastDistro = block.timestamp > poolInfo.lastRewardTimestamp ? block.timestamp - poolInfo.lastRewardTimestamp : 0;

        // We distribute the wheat assuming the old wheat balance wanted to be distributed over wheatDistributionTimeFrameSeconds seconds.
        uint wheatRelease = (blockSinceLastDistro * wheatAvailable) / wheatDistributionTimeFrameSeconds;

        wheatRelease = wheatRelease > wheatAvailable ? wheatAvailable : wheatRelease;

        promisedWHEAT += wheatRelease;

        return wheatRelease;
    }

    /**
     * @dev send usdc to a user
     */
    function transferUSDCToUser(address recipient, uint amount) internal {
        uint usdcBalance = usdcCurrency.balanceOf(address(this));
        if (usdcBalance < amount)
            amount = usdcBalance;

        promisedUSDC -= amount;

        usdcCurrency.safeTransfer(recipient, amount);

        emit USDCTransferredToUser(recipient, amount);
    }

    /**
     * @dev send wheat to a user
     * Can only be called by the current operator.
     */
    function transferWHEATToUser(address recipient, uint amount) internal {
        uint wheatBalance = wheatCurrency.balanceOf(address(this));
        if (wheatBalance < amount)
            amount = wheatBalance;

        promisedWHEAT -= amount;

        require(wheatCurrency.transfer(recipient, amount), "transfer failed!");

        emit WHEATTransferredToUser(recipient, amount);
    }

    /**
     * @dev set the number of seconds we should use to calculate the USDC drip rate.
     * Can only be called by the current operator.
     */
    function setUSDCDistributionTimeFrame(uint _usdcDistributionTimeFrame) external onlyOwner {
        require(_usdcDistributionTimeFrame > 0, "_usdcDistributionTimeFrame out of range!");
        require(_usdcDistributionTimeFrame < 32 days, "_usdcDistributionTimeFrame out of range!");

        usdcDistributionTimeFrameSeconds = _usdcDistributionTimeFrame;

        emit SetUSDCDistributionTimeFrame(usdcDistributionTimeFrameSeconds);
    }

    /**
     * @dev set the number of seconds we should use to calculate the WHEAT drip rate.
     * Can only be called by the current operator.
     */
    function setWHEATDistributionTimeFrame(uint _wheatDistributionTimeFrame) external onlyOwner {
        require(_wheatDistributionTimeFrame > 0, "_wheatDistributionTimeFrame out of range!");
        require(_wheatDistributionTimeFrame < 32 days, "_usdcDistributionTimeFrame out of range!");

        wheatDistributionTimeFrameSeconds = _wheatDistributionTimeFrame;

        emit SetWHEATDistributionTimeFrame(wheatDistributionTimeFrameSeconds);
    }
}
