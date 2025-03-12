// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol"; // to prevent reentry attacks
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "contracts/DogeVerseToken.sol";
import "contracts/DogeChampionsConsumable.sol";
import "contracts/DogeChampionsNFT.sol";

contract DogeChampionsHolderRewardProtocol is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable
{

    uint256 public dividendPerNFT;
    mapping(uint256 => uint256) public paidDividendToNFTs;

    DogeChampionsConsumable private dogeChampionsConsumable;
    DogeVerseToken private dogeVerseToken;
    DogeChampionsNFT private dogeChampionsNFT;

    uint256 private maximumFiniteSupply;

    address private dogeVerseTokenAddress;

    bool public isClaimEnabled;

    /*
     * @author modifier that prevents calls from addresses rather than DogeVerseToken contract
     */
    modifier onlyDogeVerseTokenAndOwner
    {
        require(msg.sender == owner() || msg.sender == dogeVerseTokenAddress, "Only DogeVerseToken contract can access this function.");
        _;
    }

    /*
     * @author plain good old constructor
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor()
    {
        _disableInitializers();
    }

    function initialize() initializer public {
        __Ownable_init();
        __ReentrancyGuard_init();

        dividendPerNFT = 0;
        maximumFiniteSupply = 30000;
        isClaimEnabled = false;
    }

    /*
     * @author sets token contract related fields
     */
    function setDogeVerseTokenContract(address payable contractAddress) public onlyOwner
    {
        dogeVerseToken = DogeVerseToken(contractAddress);
        dogeVerseTokenAddress = contractAddress;
    }

    /*
     * @author sets consumable contract related fields
     */
    function setConsumableContract(address contractAddress) public onlyOwner
    {
        dogeChampionsConsumable = DogeChampionsConsumable(contractAddress);
    }

    /*
     * @author sets nft contract related fields
     */
    function setNFTContract(address contractAddress) public onlyOwner
    {
        dogeChampionsNFT = DogeChampionsNFT(contractAddress);
    }

    /*
     * @author sets isClaimEnabled field - this will be set to true after presale of $DVT ends
     */
    function setClaimEnabled(bool value) public onlyOwner
    {
        isClaimEnabled = value;
    }

    /*
     * @author increased dividend yield amount per NFT
     */
    function increaseDividendPerNFT(uint256 amount) public onlyDogeVerseTokenAndOwner {
        dividendPerNFT += (amount / maximumFiniteSupply);
    }

    /*
     * @author withdraws BNB rewards of user to his / her wallet
     */
    function withdrawRewards() public
    {
        require(isClaimEnabled, "Can't claim $DVT rewards before presale ends.");
        uint256[] memory holdings = dogeChampionsNFT.getPlayableIds(msg.sender);
        uint256 balance = 0;

        for (uint256 i = 0; i < holdings.length; i++)
        {
            if (holdings[i] != 0)
            {
                balance += dividendPerNFT - paidDividendToNFTs[holdings[i]];
                paidDividendToNFTs[holdings[i]] = dividendPerNFT;
            }
        }

        dogeVerseToken.transfer(msg.sender, balance);
    }

    /*
     * @author returns BNB reward balance of given wallet address
     */
    function getRewardBalance(address walletAddress) public view returns(uint256)
    {
        uint256[] memory holdings = dogeChampionsNFT.getPlayableIds(walletAddress);
        uint256 balance = 0;

        for (uint256 i = 0; i < holdings.length; i++)
        {
            if (holdings[i] != 0)
            {
                balance += dividendPerNFT - paidDividendToNFTs[holdings[i]];
            }
        }

        return balance;
    }
}