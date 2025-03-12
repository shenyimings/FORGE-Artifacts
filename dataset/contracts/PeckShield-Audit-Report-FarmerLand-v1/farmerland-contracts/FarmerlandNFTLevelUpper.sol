pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./WHEAT.sol";
import "./MasterChef.sol";
import "./FarmerLandNFT.sol";

// FarmerlandNFTLevelUpper
contract FarmerlandNFTLevelUpper is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    /**
     * @dev set which Nfts are allowed to be staked
     * Can only be called by the current operator.
     */
    function setNftAddressAllowList(address _series, bool allowed) external onlyOwner {
        require(_series != address(0), "_series cant be 0 address");
        nftAddressAllowListMap[_series] = allowed;
        
        emit NftAddressAllowListSet(_series, allowed);
    }

    mapping(address => bool) public nftAddressAllowListMap;

   function setBaseLevelUpCost(uint _baseLevelUpCost) external onlyOwner {
        require(_baseLevelUpCost >= 0.01 * 1e18, "cost too small!");
        require(_baseLevelUpCost <= 10 * 1e18, "cost too large!");
        baseLevelUpCost = _baseLevelUpCost;

        emit BaseLevelUpCostSet(baseLevelUpCost);
    }

   function setScalarLevelUpCost(uint _scalarLevelUpCost) external onlyOwner {
        require(_scalarLevelUpCost >= 0.01 * 1e18, "cost too small!");
        require(_scalarLevelUpCost <= 10 * 1e18, "cost too large!");
        scalarLevelUpCost = _scalarLevelUpCost;

        emit ScalarLevelUpCostSet(scalarLevelUpCost);
    }

    uint public baseLevelUpCost = 0.5 * 1e18;
    uint public scalarLevelUpCost = 0.045 * 1e18;

    WHEAT immutable wheatToken;

    uint public startTime;

    event NftAddressAllowListSet(address series, bool allowed);
    event BaseLevelUpCostSet(uint baseLevelUpCost);
    event ScalarLevelUpCostSet(uint ScalarLevelUpCost);
    event BaseBoostPerLevelSet(uint baseBoostPerLevel);
    event LevellingUpIsPausedSet(bool wasPause, bool isPaused);
    event MasterChefAddressSet(MasterChef oldMC, MasterChef newMC);
    event UsdcLobbyVolumeForMaxAbilityBoostSet(uint oldVolume, uint newVolume);
    event MaxAbilityBoostMultiplierSet(uint oldMaxAbilityBoost, uint newMaxAbilityBoost);
    event NFTLevelledUP(address sender, address series, uint tokenId, uint wheatRequried, uint startTokenLevel, uint newLevel);
    event StartTimeChanged(uint newStartTime);
    event TokenRecovered(address token, address recipient, uint amount);


    constructor(uint _startTime, WHEAT _wheatToken, MasterChef _nftMasterChef) {
        require(block.timestamp < _startTime, "cannot set start time in the past!");
        require(address(_wheatToken) != address(0), "_wheat cannot be the zero address");
        require(address(_nftMasterChef) != address(0), "_nftMasterChef cannot be the zero address");
    
        startTime = _startTime;
        wheatToken = _wheatToken;
        nftMasterChef = _nftMasterChef;
    }


    function set_levellingUpIsPaused(bool _levellingUpIsPaused) external onlyOwner() {
        bool oldPaused = levellingUpIsPaused;

        levellingUpIsPaused = _levellingUpIsPaused;

        emit LevellingUpIsPausedSet(oldPaused, _levellingUpIsPaused);
    }

    bool public levellingUpIsPaused = false;

    function set_nftMasterChef(MasterChef _nftMasterChef) external onlyOwner() {
        MasterChef oldMC = nftMasterChef;

        nftMasterChef = _nftMasterChef;
       
        emit MasterChefAddressSet(oldMC, _nftMasterChef);
    }

    MasterChef public nftMasterChef;

    function set_usdcLobbyVolumeForMaxAbilityBoost(uint _usdcLobbyVolumeForMaxAbilityBoost) external onlyOwner {
        require(_usdcLobbyVolumeForMaxAbilityBoost >= 1e6, "lobby investment too small!");
        require(_usdcLobbyVolumeForMaxAbilityBoost <= 10000e6, "lobby investment too large!");

        uint oldUsdcLobbyVolumeForMaxAbilityBoost = usdcLobbyVolumeForMaxAbilityBoost;

        usdcLobbyVolumeForMaxAbilityBoost = _usdcLobbyVolumeForMaxAbilityBoost;

        emit UsdcLobbyVolumeForMaxAbilityBoostSet(oldUsdcLobbyVolumeForMaxAbilityBoost, _usdcLobbyVolumeForMaxAbilityBoost);
    }

    function set_baseBoostPerLevel(uint _baseBoostPerLevel) external onlyOwner {
        require(_baseBoostPerLevel >= 10, "boost too small!");
        require(_baseBoostPerLevel <= 10000, "boost too large!");
        baseBoostPerLevel = _baseBoostPerLevel;

        emit BaseBoostPerLevelSet(baseBoostPerLevel);
    }

    function set_maxAbilityBoostMultiplier(uint _maxAbilityBoostMultiplier) external onlyOwner {
        require(_maxAbilityBoostMultiplier >= 11000, "boost too small!");
        require(_maxAbilityBoostMultiplier <= 15100, "boost too large!");

        uint oldMaxAbilityBoostMultiplier = maxAbilityBoostMultiplier;

        maxAbilityBoostMultiplier = _maxAbilityBoostMultiplier;

        emit MaxAbilityBoostMultiplierSet(oldMaxAbilityBoostMultiplier, _maxAbilityBoostMultiplier);
    }

    uint public usdcLobbyVolumeForMaxAbilityBoost = 300e6;

    uint public baseBoostPerLevel = 800;

    uint public maxAbilityBoostMultiplier = 15000;

    function getLobbyVolumeScore(address user) public view returns (uint) {
        uint currentDay = wheatToken.currentDay();
        uint totalUSDCStakedIn7Days;

        // check last 7 days of USDC Lobby deposits
        for (uint i = 0;i<7 && currentDay>=i;i++)
            totalUSDCStakedIn7Days+= wheatToken.getMapMemberLobbyEntryByDay(user, currentDay - i);

        if (totalUSDCStakedIn7Days >= usdcLobbyVolumeForMaxAbilityBoost)
            return 10000 + maxAbilityBoostMultiplier;
        else
            return 10000 + totalUSDCStakedIn7Days * maxAbilityBoostMultiplier / usdcLobbyVolumeForMaxAbilityBoost;
    }

    function levelUpNFT(address series, uint tokenId, uint levelsToUp) external nonReentrant {
        require(!levellingUpIsPaused, "levelling up is paused!");
        require(nftAddressAllowListMap[series], "nftNotAllowed to be upgraded!");
        require(address(nftMasterChef) != address(0), "contract needs configuring");
        require(block.timestamp >= startTime, "presale hasn't started yet, good things come to those that wait");
        require(levelsToUp > 0, "must upgrade by at least 1 level");

        uint startTokenLevel = FarmerLandNFT(series).getLevel(tokenId);
        uint MAX_LEVEL = FarmerLandNFT(series).MAX_LEVEL();

        require(startTokenLevel < MAX_LEVEL, "tokenId already at max level!");

        uint userWheatBalance = ERC20(wheatToken).balanceOf(msg.sender);

        if (startTokenLevel + levelsToUp > MAX_LEVEL)
            levelsToUp = MAX_LEVEL - startTokenLevel;

        // This calculates all of the WHEAT required to level up the consecutive levels
        // baseLevelUpCost * levelsToUp + (scalarLevelUpCost * (levelsToUp / 2) * (2 * (startTokenLevel) + (levelsToUp)))
        uint wheatRequried = baseLevelUpCost * levelsToUp + (scalarLevelUpCost * ((levelsToUp * 1e4) / 2) * (2 * (startTokenLevel) + (levelsToUp))) / 1e4;

        // If it is too much WHEAT we then instead sum each cost iteratively until they can't afford it
        if (wheatRequried > userWheatBalance) {
            wheatRequried = 0;
            uint currentLevel = startTokenLevel;

            for (;currentLevel < MAX_LEVEL;currentLevel++) {
                uint nextPayment = baseLevelUpCost + scalarLevelUpCost * currentLevel;
                if (wheatRequried + nextPayment > userWheatBalance)
                    break;
                wheatRequried+= nextPayment;
            }

            levelsToUp = currentLevel - startTokenLevel;
        }

        require(wheatRequried > 0 && levelsToUp > 0, "insufficient WHEAT balance to level up!");

        ERC20(wheatToken).safeTransferFrom(msg.sender, address(this), wheatRequried);

        uint oldAbility = FarmerLandNFT(series).getAbility(tokenId);

        uint newLevel = startTokenLevel + levelsToUp;

        FarmerLandNFT(series).setLevel(tokenId, newLevel);

        FarmerLandNFT(series).setAbility(tokenId, oldAbility + (levelsToUp * (baseBoostPerLevel * getLobbyVolumeScore(msg.sender))) / 1e4);

        if (nftMasterChef.isNftSeriesAllowed(series) && nftMasterChef.hasUserStakedNFT(msg.sender, series, tokenId))
            nftMasterChef.updateAbilityForDeposit(msg.sender, series, tokenId);

        emit NFTLevelledUP(msg.sender, series, tokenId, wheatRequried, startTokenLevel, newLevel);
    }

   function setStartTime(uint _newStartTime) external onlyOwner {
        startTime = _newStartTime;

        emit StartTimeChanged(_newStartTime);
    }
    // Recover tokens in case of error, only owner can use.
    function withdrawWHEAT(address recipient, uint recoveryAmount) external onlyOwner {
        if (recoveryAmount > 0)
            ERC20(wheatToken).safeTransfer(recipient, recoveryAmount);
        
        emit TokenRecovered(address(wheatToken), recipient, recoveryAmount);
    }
    // Recover tokens in case of error, only owner can use.
    function recoverTokens(address tokenAddress, address recipient, uint recoveryAmount) external onlyOwner {
        if (recoveryAmount > 0)
            ERC20(tokenAddress).safeTransfer(recipient, recoveryAmount);
        
        emit TokenRecovered(tokenAddress, recipient, recoveryAmount);
    }
}