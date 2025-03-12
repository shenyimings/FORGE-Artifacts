// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IFlashStrategy.sol";
import "./interfaces/IFlashFToken.sol";
import "./interfaces/IFlashNFT.sol";
import "./interfaces/IERC20C.sol";
import "./interfaces/IFlashFTokenFactory.sol";

contract FlashProtocol is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20C;

    address public immutable flashNFTAddress;
    address immutable flashFTokenFactoryAddress;

    // Define the structure for each strategy
    struct StrategyInformation {
        address fTokenAddress;
        address principalTokenAddress;
    }
    mapping(address => StrategyInformation) public strategies;

    // This will store the NFT ID to StakeID mapping
    mapping(uint256 => uint256) public nftIdMappingsToStakeIds;

    // This will store how many stakes we have
    uint256 public stakeCount = 0;

    // The global fToken mint fee
    uint96 public globalMintFee = 0;
    address public globalMintFeeRecipient = 0x5089722613C2cCEe071C39C59e9889641f435F15;

    // This defines the structure of the Stake information we store
    struct StakeStruct {
        address stakerAddress; // Address of staker
        address strategyAddress; // Address of strategy being used
        uint256 stakeStartTs; // Unix timestamp of when stake started
        uint256 stakeDuration; // Time in seconds from start time until stake ends
        uint256 stakedAmount; // The amount of tokens staked
        bool active; // Stake has been removed/unstaked
        uint256 nftId; // NFT id if set
        uint256 fTokensToUser; // How many fERC20 tokens were minted
        uint256 fTokensFee; // How many fERC20 tokens were taken as fee
        uint256 totalFTokenBurned;
        uint256 totalStakedWithdrawn;
    }
    mapping(uint256 => StakeStruct) public stakes;

    // Define events
    event StrategyRegistered(
        address indexed _strategyAddress,
        address indexed _principalTokenAddress,
        address indexed _fTokenAddress
    );
    event Staked(uint256 _stakeId);
    event Unstaked(uint256 _stakeId, uint256 _tokensReturned, uint256 _fTokensBurned, bool _stakeFinished);
    event NFTIssued(uint256 _stakeId, uint256 nftId);
    event NFTRedeemed(uint256 _stakeId, uint256 nftId);

    constructor(address _flashNFTAddress, address _flashFTokenFactoryAddress) public {
        flashNFTAddress = _flashNFTAddress;
        flashFTokenFactoryAddress = _flashFTokenFactoryAddress;
    }

    function registerStrategy(
        address _strategyAddress,
        address _principalTokenAddress,
        string calldata _fTokenName,
        string calldata _fTokenSymbol
    ) external {
        require(strategies[_strategyAddress].principalTokenAddress == address(0));

        address flashFToken = IFlashFTokenFactory(flashFTokenFactoryAddress).createFToken(_fTokenName, _fTokenSymbol);

        // Store the appropriate information
        strategies[_strategyAddress].fTokenAddress = flashFToken;
        strategies[_strategyAddress].principalTokenAddress = _principalTokenAddress;

        IFlashStrategy(_strategyAddress).setFTokenAddress(flashFToken);

        emit StrategyRegistered(_strategyAddress, _principalTokenAddress, flashFToken);
    }

    function stake(
        address _strategyAddress,
        uint256 _tokenAmount,
        uint256 _stakeDuration,
        address _fTokensTo,
        bool _issueNFT
    ) public returns (StakeStruct memory _stake) {
        require(strategies[_strategyAddress].principalTokenAddress != address(0));
        require(
            _stakeDuration >= 60 && _stakeDuration <= IFlashStrategy(_strategyAddress).getMaxStakeDuration(),
            "ISD"
        );

        // Transfer the tokens from caller to the strategy contract
        IERC20C(strategies[_strategyAddress].principalTokenAddress).transferFrom(
            msg.sender,
            address(_strategyAddress),
            _tokenAmount
        );

        // Determine how many fERC20 tokens to mint (ask strategy)
        uint256 tokensToMint = IFlashStrategy(_strategyAddress).quoteMintFToken(_tokenAmount, _stakeDuration);

        // Deposit into the strategy
        uint256 principalAfterDeductions = IFlashStrategy(_strategyAddress).depositPrincipal(_tokenAmount);

        // Calculate fee and if this is more than 0, transfer fee
        uint256 fee = (tokensToMint * globalMintFee) / 10000;
        if (fee > 0) {
            IERC20C(strategies[_strategyAddress].fTokenAddress).mint(globalMintFeeRecipient, fee);
        }

        // Mint fERC20 tokens to the user
        IERC20C(strategies[_strategyAddress].fTokenAddress).mint(_fTokensTo, (tokensToMint - fee));

        // Save the stake details
        stakeCount = stakeCount + 1;
        stakes[stakeCount] = StakeStruct(
            msg.sender,
            _strategyAddress,
            block.timestamp,
            _stakeDuration,
            principalAfterDeductions,
            true,
            0,
            (tokensToMint - fee),
            fee,
            0,
            0
        );

        // Mint NFT if requested
        if (_issueNFT) {
            issueNFT(stakeCount);
        }

        emit Staked(stakeCount);

        return stakes[stakeCount];
    }

    function unstake(
        uint256 _id,
        bool _isNFT,
        uint256 _fTokenToBurn
    ) external nonReentrant returns (uint256 _principalReturned, uint256 _fTokensBurned) {
        StakeStruct memory p;
        uint256 stakeId;
        address returnAddress;
        if (_isNFT) {
            stakeId = nftIdMappingsToStakeIds[_id];
            p = stakes[stakeId];
            returnAddress = msg.sender;
            require(p.nftId == _id, "SNM");
            require(IFlashNFT(flashNFTAddress).ownerOf(_id) == msg.sender, "NNO");

            // Burn the NFT
            IFlashNFT(flashNFTAddress).burn(_id);
            emit NFTRedeemed(stakeId, _id);
        } else {
            stakeId = _id;
            p = stakes[stakeId];
            returnAddress = p.stakerAddress;

            require(p.nftId == 0, "NTR");
            require(p.stakerAddress == msg.sender, "NSO");
        }
        require(p.active == true, "SNE");

        uint256 principalToReturn;
        uint256 percentageIntoStake = (((block.timestamp - p.stakeStartTs) * (10**18)) / p.stakeDuration);

        if (percentageIntoStake >= (10**18)) {
            // Stake has ended, simply return principal
            principalToReturn = p.stakedAmount - p.totalStakedWithdrawn;
            emit Unstaked(stakeId, principalToReturn, 0, true);

            delete stakes[stakeId];
        } else {
            require(block.timestamp >= (p.stakeStartTs + 3600), "MIN DUR 1HR");

            // Stake has not ended yet, user is trying to withdraw early
            uint256 fTokenBurnForFullUnstake = ((((10**18) - percentageIntoStake) * (p.fTokensToUser + p.fTokensFee)) /
                (10**18));
            bool stakeFinished;

            if (p.totalFTokenBurned > fTokenBurnForFullUnstake) {
                // The total number of fTokens burned is greater than the amount required, no burn required
                fTokenBurnForFullUnstake = 0;
            } else {
                fTokenBurnForFullUnstake = fTokenBurnForFullUnstake - p.totalFTokenBurned;
            }

            // Ensure the user cannot burn more fTokens than required
            if (_fTokenToBurn > fTokenBurnForFullUnstake) {
                _fTokenToBurn = fTokenBurnForFullUnstake;
            }

            // Is the user trying to withdraw everything early?
            if (_fTokenToBurn == fTokenBurnForFullUnstake) {
                // Yes, return all principal
                principalToReturn = p.stakedAmount - p.totalStakedWithdrawn;
                stakeFinished = true;
            } else {
                // No - only a partial withdraw
                principalToReturn =
                    (((_fTokenToBurn * (10**18)) / (p.fTokensToUser + p.fTokensFee)) * p.stakedAmount) /
                    (10**18);
            }

            // Burn these fTokens
            IERC20C(strategies[p.strategyAddress].fTokenAddress).burnFrom(msg.sender, _fTokenToBurn);

            // Update stake information
            stakes[stakeId].totalFTokenBurned = p.totalFTokenBurned + _fTokenToBurn;
            stakes[stakeId].totalStakedWithdrawn = p.totalStakedWithdrawn + principalToReturn;

            emit Unstaked(stakeId, principalToReturn, _fTokenToBurn, stakeFinished);
        }
        require(principalToReturn > 0);
        require(p.stakedAmount >= stakes[stakeId].totalStakedWithdrawn);

        // Remove tokens from Strategy and transfer to user
        IFlashStrategy(p.strategyAddress).withdrawPrincipal(principalToReturn);
        IERC20C(strategies[p.strategyAddress].principalTokenAddress).transfer(returnAddress, principalToReturn);

        return (principalToReturn, _fTokenToBurn);
    }

    function issueNFT(uint256 _stakeId) public returns (uint256 _nftId) {
        StakeStruct memory p = stakes[_stakeId];
        require(p.active == true && p.nftId == 0 && p.stakerAddress == msg.sender);

        // Mint the NFT
        uint256 nftId = IFlashNFT(flashNFTAddress).mint(msg.sender);

        // Store the NFT ID
        stakes[_stakeId].nftId = nftId;

        // Update the NFT Mapping so we can look it up later
        nftIdMappingsToStakeIds[nftId] = _stakeId;

        emit NFTIssued(_stakeId, nftId);

        return nftId;
    }

    function setMintFeeInfo(address _feeRecipient, uint96 _feePercentageBasis) external onlyOwner {
        require(_feePercentageBasis <= 2000);
        globalMintFeeRecipient = _feeRecipient;
        globalMintFee = _feePercentageBasis;
    }

    function getStakeInfo(uint256 _id, bool _isNFT) external view returns (StakeStruct memory _stake) {
        uint256 stakeId;
        if (_isNFT) {
            stakeId = nftIdMappingsToStakeIds[_id];
            require(stakes[stakeId].nftId == _id);
        } else {
            stakeId = _id;
        }

        return stakes[stakeId];
    }

    function flashStake(
        address _strategyAddress,
        uint256 _tokenAmount,
        uint256 _stakeDuration,
        uint256 _minimumReceived,
        address _yieldTo,
        bool _mintNFT
    ) external nonReentrant {
        // Stake
        uint256 fTokensMinted = stake(_strategyAddress, _tokenAmount, _stakeDuration, _yieldTo, _mintNFT).fTokensToUser;

        IERC20C fToken = IERC20C(strategies[_strategyAddress].fTokenAddress);
        fToken.transferFrom(msg.sender, address(this), fTokensMinted);

        // Approve, burn and send yield to specified address
        fToken.approve(_strategyAddress, fTokensMinted);
        IFlashStrategy(_strategyAddress).burnFToken(fTokensMinted, _minimumReceived, _yieldTo);
    }
}
