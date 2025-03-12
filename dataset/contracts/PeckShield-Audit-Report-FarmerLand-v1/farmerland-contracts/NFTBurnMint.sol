pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./FarmerLandNFT.sol";

// NFTBurnMint
contract NFTBurnMint is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public constant founder = 0xC43f13A64fd351C8846660B5D02dB344829859b8;

    /**
     * @dev set which Nfts are allowed to be staked
     * Can only be called by the current operator.
     */
    function setNftAddressAllowList(address _series, bool allowed) external onlyOwner {
        require(_series != address(0), "_series cant be 0 address");
        nftAddressAllowListMap[_series] = allowed;
        
        emit NftAddressAllowListSet(_series, allowed);
    }

    mapping(address => bool) public admins;

    mapping(address => bool) public nftAddressAllowListMap;

    FarmerLandNFT public immutable mintingNFT;
    uint public startTime;


    event NftAddressAllowListSet(address series, bool allowed);

    event BurnMintingIsPaused(bool wasPause, bool isPaused);
    event NFT_COST_INCREASE_INTERVAL_Changed(uint oldVal, uint newVal);
    event NFT_BURN_COST_Changed(uint oldVal, uint newVal);

    event BurnMinted(address sender, address[] series, uint[] tokenIds, uint desiredMints);
    event StartTimeChanged(uint newStartTime);
    event TokenRecovered(address token, address recipient, uint amount);
    event AdminSet(address admin, bool value);

    constructor(uint _startTime, FarmerLandNFT _mintingNFT) {
        require(address(_mintingNFT) != address(0), "mintingNFT can't be 0 address!");
        
        mintingNFT = _mintingNFT;
        startTime = _startTime;

        admins[founder] = true;
        admins[msg.sender] = true;
    }

    function set_burnMintingIsPaused(bool _burnMintingIsPaused) external {
        require(admins[msg.sender], "sender not admin!");
        bool oldPaused = burnMintingIsPaused;

        burnMintingIsPaused = _burnMintingIsPaused;

        emit BurnMintingIsPaused(oldPaused, burnMintingIsPaused);
    }

    function set_NFT_COST_INCREASE_INTERVAL(uint _NFT_COST_INCREASE_INTERVAL, bool forceMintCountReset) external {
        require(admins[msg.sender], "sender not admin!");
        require(_NFT_COST_INCREASE_INTERVAL > 0, "NFT_COST_INCREASE_INTERVAL can't be 0!");
        require(NFT_COST_INCREASE_INTERVAL != _NFT_COST_INCREASE_INTERVAL, "Updating value is the same as the old one!");
    
        uint oldVal = NFT_COST_INCREASE_INTERVAL;

        NFT_COST_INCREASE_INTERVAL = _NFT_COST_INCREASE_INTERVAL;

        // We will reset mintsSinceLastPriceIncrease if it will cause a cost increase immediately on the next mint,
        // to stop unintended levelling up, if the accumulated mint count is now larger than the new interval.
        if (forceMintCountReset || mintsSinceLastPriceIncrease >= NFT_COST_INCREASE_INTERVAL)
            mintsSinceLastPriceIncrease = 0;

        emit NFT_COST_INCREASE_INTERVAL_Changed(oldVal, NFT_COST_INCREASE_INTERVAL);
    }

    function set_NFT_BURN_COST(uint _NFT_BURN_COST) external {
        require(admins[msg.sender], "sender not admin!");
        require(_NFT_BURN_COST > 0, "_NFT_BURN_COST can't be 0!");
        uint oldVal = NFT_BURN_COST;

        NFT_BURN_COST = _NFT_BURN_COST;

        emit NFT_BURN_COST_Changed(oldVal, NFT_BURN_COST);
    }

    bool public burnMintingIsPaused = true;

    // Every NFT_COST_INCREASE_INTERVAL NFT mints, results in NFT_BURN_COST increasing by 1.
    // As people can mint many NFTs in 1 txn, we need to factor in the cost as more NFTs are minted.
    uint public NFT_COST_INCREASE_INTERVAL = 50;

    // The current number of NFTs required to be burnt to mint 1 new NFT.
    // This is meant to increase as more are minted.
    uint public NFT_BURN_COST = 7;

    uint public totalMints = 0;

    // A counter to track how many new mints weve done since the last price increase,
    // used to calculate how many more mints are left before the next price increase.
    uint public mintsSinceLastPriceIncrease = 0;

    function getBurnCost(uint desiredMints) public view returns (uint) {
        uint mintsUntilNextPriceIncrease = NFT_COST_INCREASE_INTERVAL - mintsSinceLastPriceIncrease;
        uint burnCost;

        if (desiredMints <= mintsUntilNextPriceIncrease) {
            return NFT_BURN_COST * desiredMints;
        } else {
            burnCost= NFT_BURN_COST * mintsUntilNextPriceIncrease;
        }

        uint TMP_NFT_BURN_COST = NFT_BURN_COST+1;

        uint i = mintsUntilNextPriceIncrease;

        // We now jump whole intervals per burnCost increase.
        mintsUntilNextPriceIncrease = NFT_COST_INCREASE_INTERVAL;

        while (true) {
            uint mintsLeft = desiredMints - i;
            if (mintsLeft <= mintsUntilNextPriceIncrease) {
                burnCost+= TMP_NFT_BURN_COST * mintsLeft;
                break;
            } else {
                burnCost+= TMP_NFT_BURN_COST * mintsUntilNextPriceIncrease;
            }
            i+=mintsUntilNextPriceIncrease;
            TMP_NFT_BURN_COST++;
        }
        return burnCost;
    }

    function burnMintNFTs(address[] calldata series, uint[] calldata tokenIds, uint desiredMints) external nonReentrant {
        require(!burnMintingIsPaused, "minting is paused!");
        require(block.timestamp >= startTime, "minting hasn't started yet, good things come to those that wait");
        require(series.length == tokenIds.length, "series array must equal tokenIds array");
        require(desiredMints > 0, "desiredMints can't be 0!");

        // Calculates the number of NFTs needed to be burnt to mint desiredMints number of NFTs.
        // If the sender is an admin, they get free mints. 
        uint totalNFTBurns = admins[msg.sender] ? 0 : getBurnCost(desiredMints);
        require(tokenIds.length >= totalNFTBurns, "insuffient nfts supplied for burn+mint!");

        // We don't want free mints to effect the pricing.
        if (!admins[msg.sender]) {
            uint mintsSinceLastPriceIncreaseToOrderFullfillment = (mintsSinceLastPriceIncrease + desiredMints);
        
            NFT_BURN_COST+= mintsSinceLastPriceIncreaseToOrderFullfillment/NFT_COST_INCREASE_INTERVAL;
            mintsSinceLastPriceIncrease = mintsSinceLastPriceIncreaseToOrderFullfillment%NFT_COST_INCREASE_INTERVAL;
        }
        
        totalMints+=desiredMints;

        for (uint i = 0;i<totalNFTBurns;i++) {
            require(nftAddressAllowListMap[series[i]], "NFT not valid for minting credit!");
            FarmerLandNFT(series[i]).safeTransferFrom(msg.sender, BURN_ADDRESS, tokenIds[i]);
        }

        mintingNFT.mint(msg.sender, desiredMints);

        emit BurnMinted(msg.sender, series, tokenIds, desiredMints);
    }

   function setStartTime(uint _newStartTime) external onlyOwner {
        startTime = _newStartTime;

        emit StartTimeChanged(_newStartTime);
    }
    // Recover tokens in case of error, only owner can use.
    function recoverTokens(address tokenAddress, address recipient, uint recoveryAmount) external onlyOwner {
        if (recoveryAmount > 0)
            ERC20(tokenAddress).safeTransfer(recipient, recoveryAmount);
        
        emit TokenRecovered(tokenAddress, recipient, recoveryAmount);
    }
    // Recover tokens in case of error, only owner can use.
    function recoverNFTs(address tokenAddress, address recipient, uint tokenId) external onlyOwner {
        FarmerLandNFT(tokenAddress).safeTransferFrom(address(this), recipient, tokenId);
        
        emit TokenRecovered(tokenAddress, recipient, tokenId);
    }

    function setAdmins(address _newAdmin, bool status) public onlyOwner {
        admins[_newAdmin] = status;

        emit AdminSet(_newAdmin, status);
    }
}