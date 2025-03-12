// SPDX-License-Identifier: MIT

/**
 __      __  _____ _______________________________________   
/  \    /  \/  _  \\______   \______   \_   _____/\______ \  
\   \/\/   /  /_\  \|       _/|     ___/|    __)_  |    |  \ 
 \        /    |    \    |   \|    |    |        \ |    `   \
  \__/\  /\____|__  /____|_  /|____|   /_______  //_______  /
       \/         \/       \/                  \/         \/ 
 */

pragma solidity 0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {ITaxHandler} from "./interfaces/ITaxHandler.sol";
import {IPoolManager} from "./interfaces/IPoolManager.sol";

contract WarpedTaxHandler is ITaxHandler, Ownable {
    /// @notice limit number of NFT contracts
    uint8 public constant NFT_CONTRACTS_LIMIT = 10;
    /// @notice limit number of tax rate points
    uint8 public constant TAX_RATES_LIMIT = 10;

    /// @notice NFTs to be used to determine user tax level.
    IERC721[] public nftContracts;
    /// @notice Bits representing levels of each NFTs: 1,2,4,8
    mapping(IERC721 => uint8) public nftLevels;

    struct TaxRatePoint {
        uint256 threshold;
        uint256 rate;
    }

    TaxRatePoint[] public taxRates;
    uint256 public basisTaxRate;
    uint256 public constant maxTaxRate = 400;
    bool public taxDisabled;
    IPoolManager public poolManager;

    /// @notice Emitted when tax rates are updated.
    event TaxRatesUpdated(uint256[] thesholds, uint256[] rates, uint256 basisTaxRate);

    /// @notice Emitted when nft contracts and levels are added.
    event NFTsAdded(address[] contracts, uint8[] levels);

    /// @notice Emitted when nft contracts are removed.
    event NFTsRemoved(address[] contracts);

    /// @notice Emitted when tax is paused.
    event TaxPaused();

    /// @notice Emitted when tax is resumed.
    event TaxResumed();

    /// @notice Constructor of tax handler contract
    /// @param _poolManager exchange pool manager address
    /// @param _nftContracts array of addresses of NFT contracts
    /// @param _levels array of levels of NFT contracts
    constructor(IPoolManager _poolManager, address[] memory _nftContracts, uint8[] memory _levels) {
        poolManager = _poolManager;

        _addNFTs(_nftContracts, _levels);
        // init default tax rates
        basisTaxRate = 400;
        taxRates.push(TaxRatePoint(7, 100));
        taxRates.push(TaxRatePoint(5, 200));
        taxRates.push(TaxRatePoint(1, 300));
    }

    /**
     * @notice Reset tax rate points.
     * @param thresholds of user level.
     * @param rates of tax per each threshold.
     * @param basisRate basis tax rate.
     *
     * Requirements:
     *
     * - values of `thresholds` must be placed in descending order.
     */
    function setTaxRates(uint256[] memory thresholds, uint256[] memory rates, uint256 basisRate) external onlyOwner {
        require(thresholds.length == rates.length, "Invalid level points");
        require(thresholds.length <= TAX_RATES_LIMIT, "Tax rates limit exceeded");
        require(basisRate > 0, "Invalid base rate");
        require(basisRate <= maxTaxRate, "Base rate must be <= than max");

        delete taxRates;
        for (uint256 i = 0; i < thresholds.length; i++) {
            require(rates[i] <= maxTaxRate, "Rate must be less than max rate");
            if (i > 0) {
                require(thresholds[i] < thresholds[i - 1], "Thresholds not descending order");
            }
            taxRates.push(TaxRatePoint(thresholds[i], rates[i]));
        }
        basisTaxRate = basisRate;

        emit TaxRatesUpdated(thresholds, rates, basisRate);
    }

    /**
     * @notice Add addresses and their levels of NFTs(only ERC721).
     * @dev For future NFT launch, allow to add new NFT addresses and levels.
     * @param contracts NFT contract addresses.
     * @param levels NFT contract levels to be used for user level calculation.
     */
    function addNFTs(address[] memory contracts, uint8[] memory levels) external onlyOwner {
        require(contracts.length > 0 && levels.length > 0, "Invalid parameters");
        _addNFTs(contracts, levels);
    }

    /**
     * @notice Remove nft level by address.
     * @param contracts NFT contract addresses.
     */
    function removeNFTs(address[] memory contracts) external onlyOwner {
        require(contracts.length > 0, "Invalid parameters");
        for (uint8 i = 0; i < contracts.length; i++) {
            for (uint8 j = 0; j < nftContracts.length; j++) {
                if (address(nftContracts[j]) == contracts[i]) {
                    // safely remove NFT contract from array
                    if (j < nftContracts.length - 1) {
                        nftContracts[j] = nftContracts[nftContracts.length - 1];
                    }
                    nftContracts.pop();
                    break;
                }
            }
            nftLevels[IERC721(contracts[i])] = 0;
        }
        emit NFTsRemoved(contracts);
    }

    /**
     * @notice Set no tax for special period
     */
    function pauseTax() external onlyOwner {
        require(!taxDisabled, "Already paused");
        taxDisabled = true;
        emit TaxPaused();
    }

    /**
     * @notice Resume tax handling
     */
    function resumeTax() external onlyOwner {
        require(taxDisabled, "Not paused");
        taxDisabled = false;
        emit TaxResumed();
    }

    /**
     * @notice Get number of tokens to pay as tax.
     * @dev There is no easy way to differentiate between a user swapping
     * tokens and a user adding or removing liquidity to the pool. In both
     * cases tokens are transferred to or from the pool. This is an unfortunate
     * case where users have to accept being taxed on liquidity additions and
     * removal. To get around this issue a separate liquidity addition contract
     * can be deployed. This contract could be exempt from taxes if its
     * functionality is verified to only add and remove liquidity.
     * @param benefactor Address of the benefactor.
     * @param beneficiary Address of the beneficiary.
     * @param amount Number of tokens in the transfer.
     * @return taxAmount Number of tokens for tax
     */
    function getTax(address benefactor, address beneficiary, uint256 amount) external view override returns (uint256) {
        if (taxDisabled) {
            return 0;
        }

        // Transactions between regular users (this includes contracts) aren't taxed.
        if (!poolManager.isPoolAddress(benefactor) && !poolManager.isPoolAddress(beneficiary)) {
            return 0;
        }

        // Transactions between pools aren't taxed.
        if (poolManager.isPoolAddress(benefactor) && poolManager.isPoolAddress(beneficiary)) {
            return 0;
        }

        uint256 taxRate = 0;
        // If the benefactor is found in the set of exchange pools, then it's a buy transactions, otherwise a sell
        // transactions, because the other use cases have already been checked above.
        if (poolManager.isPoolAddress(benefactor)) {
            taxRate = _getTaxBasisPoints(beneficiary);
        } else {
            taxRate = _getTaxBasisPoints(benefactor);
        }

        return (amount * taxRate) / 10000;
    }

    /**
     * @notice Get percent of tax to pay for the given user.
     * @dev Basis tax percent will be varied based on user's ownership of NFTs
     * in the STARL metaverse. There are 3 user levels and user's level will be
     * determined by bit-or of nft levels he owned.
     * SATE: 8(4th bit), LM/LMvX: 4(3rd bit), PAL: 2(2nd bit), PN: 1(first bit)
     * bit-or >= 7 : 1%
     * bit-or >= 5 : 2%
     * bit-or >= 1 : 3%
     * @param user Address of user(buyer/seller address).
     * @return Number Basis tax percent in 2 decimal.
     */
    function _getTaxBasisPoints(address user) internal view returns (uint256) {
        uint256 userLevel = 0;
        // Max number of nft contracts is 10 so gas for the loop of nft contracts is less than about 141k.
        // Max number of tax rates is 10 so gas for the loop of tax rates is less than about 100k.
        // Total gas for both loops is less than about 241k so it will be not over the block gas limit.
        for (uint256 i = 0; i < nftContracts.length; i++) {
            IERC721 nft = nftContracts[i];
            if (nft.balanceOf(user) > 0) {
                userLevel = userLevel | nftLevels[nftContracts[i]];
            }
        }
        for (uint256 i = 0; i < taxRates.length; i++) {
            if (userLevel >= taxRates[i].threshold) {
                return taxRates[i].rate;
            }
        }
        return basisTaxRate;
    }

    function _addNFTs(address[] memory contracts, uint8[] memory levels) internal {
        require(contracts.length == levels.length, "Invalid parameters");
        require(contracts.length + nftContracts.length <= NFT_CONTRACTS_LIMIT, "No. of NFT contracts over limit");

        for (uint8 i = 0; i < contracts.length; i++) {
            require(contracts[i] != address(0), "contract address is zero address");
            require(IERC165(contracts[i]).supportsInterface(type(IERC721).interfaceId), "IERC721 not implemented");
            // nftLevels for existing contract is always bigger than zero.
            // So checking this value is enough to check the uniqueness of adding NFT contract address.
            require(nftLevels[IERC721(contracts[i])] == 0, "Duplicate NFT contract");
            require(levels[i] > 0, "Invalid NFT level");

            nftContracts.push(IERC721(contracts[i]));
            nftLevels[IERC721(contracts[i])] = levels[i];
        }

        emit NFTsAdded(contracts, levels);
    }
}
