// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./constants/addresses.sol";
import "./constants/roles.sol";
import "./interfaces/ITreasuryTracker.sol";
import "./tangibleInterfaces/ITangibleMarketplace.sol";
import "./tangibleInterfaces/ICurrencyFeed.sol";
import "./tangibleInterfaces/IPriceOracle.sol";
import "./AddressAccessor.sol";

contract TreasuryTracker is AddressAccessor, ITreasuryTracker {
    struct TokenArray {
        uint256[] tokenIds;
    }
    struct ContractItem {
        bool selling;
        uint256 index;
        uint256 indexInTnftMap;
    }

    struct TnftTreasuryItem {
        address tnft;
        uint256 tokenId;
        uint256 indexInCurrentlySelling;
    }

    struct FractionTreasuryItem {
        address ftnft;
        uint256 fractionId;
        uint256 indexInCurrentlySelling;
    }

    //fractions
    address[] public fractionContractsInTreasury;
    mapping(address => address[]) public tnftFractionsContracts;
    mapping(address => ContractItem) public isFtnftInTreasury;
    mapping(address => uint256[]) public fractionTokensInTreasury;
    mapping(address => FractionIdData[]) public fractionTokensDataInTreasury;
    mapping(address => mapping(uint256 => FractionTreasuryItem))
        public fractiInTreasuryMapper;

    //return whole array
    function getFractionContractsInTreasury()
        external
        view
        returns (address[] memory)
    {
        return fractionContractsInTreasury;
    }

    function getTnftFractionContractsInTreasury(address tnft)
        external
        view
        returns (address[] memory)
    {
        return tnftFractionsContracts[tnft];
    }

    //return size
    function fractionContractsInTreasurySize() external view returns (uint256) {
        return fractionContractsInTreasury.length;
    }

    function tnftFractionContractsInTreasurySize(address tnft)
        external
        view
        returns (uint256)
    {
        return tnftFractionsContracts[tnft].length;
    }

    //return whole array
    function getFractionTokensInTreasury(address ftnft)
        external
        view
        returns (uint256[] memory)
    {
        return fractionTokensInTreasury[ftnft];
    }

    //return whole batch arrays
    function getFractionTokensInTreasuryBatch(address[] calldata ftnfts)
        external
        view
        returns (TokenArray[] memory result)
    {
        uint256 length = ftnfts.length;
        result = new TokenArray[](length);
        for (uint256 i; i < length; i++) {
            TokenArray memory temp = TokenArray(
                fractionTokensInTreasury[ftnfts[i]]
            );
            result[i] = temp;
        }
        return result;
    }

    //return size
    function fractionTokensInTreasurySize(address ftnft)
        external
        view
        returns (uint256)
    {
        return fractionTokensInTreasury[ftnft].length;
    }

    function getFractionTokensDataInTreasury(address ftnft)
        external
        view
        returns (FractionIdData[] memory fData)
    {
        return fractionTokensDataInTreasury[ftnft];
    }

    address[] public tnftCategoriesInTreasury;
    mapping(address => ContractItem) public isTnftInTreasury;
    mapping(address => uint256[]) public tnftTokensInTreasury;
    mapping(address => mapping(uint256 => TnftTreasuryItem))
        public tnftSaleMapper;

    //return whole array
    function getTnftCategoriesInTreasury()
        external
        view
        returns (address[] memory)
    {
        return tnftCategoriesInTreasury;
    }

    //return size
    function tnftCategoriesInTreasurySize() external view returns (uint256) {
        return tnftCategoriesInTreasury.length;
    }

    //return whole array
    function getTnftTokensInTreasury(address tnft)
        external
        view
        returns (uint256[] memory)
    {
        return tnftTokensInTreasury[tnft];
    }

    //return whole batch arrays
    function getTnftTokensInTreasuryBatch(address[] calldata tnfts)
        external
        view
        returns (TokenArray[] memory result)
    {
        uint256 length = tnfts.length;
        result = new TokenArray[](length);
        for (uint256 i; i < length; i++) {
            TokenArray memory temp = TokenArray(tnftTokensInTreasury[tnfts[i]]);
            result[i] = temp;
        }
        return result;
    }

    //return size
    function tnftTokensInTreasurySize(address tnft)
        external
        view
        returns (uint256)
    {
        return tnftTokensInTreasury[tnft].length;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function tnftTreasuryPlaced(
        address tnft,
        uint256 tokenId,
        bool place
    ) external override {
        require(
            msg.sender == addressProvider.getAddress(TREASURY_ADDRESS),
            "No treasury"
        );

        if (place) {
            //check if something from this category is on sale already
            if (!isTnftInTreasury[tnft].selling) {
                //add category to actively selling list
                tnftCategoriesInTreasury.push(tnft);
                isTnftInTreasury[tnft].selling = true;
                isTnftInTreasury[tnft].index =
                    tnftCategoriesInTreasury.length -
                    1;
            }
            //something is added to marketplace

            tnftTokensInTreasury[tnft].push(tokenId);
            TnftTreasuryItem memory tsi = TnftTreasuryItem(
                tnft,
                tokenId,
                (tnftTokensInTreasury[tnft].length - 1)
            );
            tnftSaleMapper[tnft][tokenId] = tsi;
        } else {
            //something is removed from marketplace
            uint256 indexInTokenSale = tnftSaleMapper[tnft][tokenId]
                .indexInCurrentlySelling;
            _removeCurrentlySellingTnft(tnft, indexInTokenSale);
            delete tnftSaleMapper[tnft][tokenId];
            if (tnftTokensInTreasury[tnft].length == 0) {
                //all tokens are removed, nothing in category is selling anymore
                _removeCategory(isTnftInTreasury[tnft].index);
                delete isTnftInTreasury[tnft];
            }
        }
    }

    function ftnftTreasuryPlaced(
        address ftnft,
        uint256 tokenId,
        bool place
    ) external override {
        require(
            msg.sender == addressProvider.getAddress(TREASURY_ADDRESS),
            "No treasury"
        );

        if (place) {
            //check if something from this category is on sale already
            if (!isFtnftInTreasury[ftnft].selling) {
                //add category to actively selling list
                fractionContractsInTreasury.push(ftnft);
                //store fraction in appropriate tnft map
                address tnft = _fetchTnftForFraction(ftnft);
                tnftFractionsContracts[tnft].push(ftnft);

                isFtnftInTreasury[ftnft].selling = true;
                isFtnftInTreasury[ftnft].index =
                    fractionContractsInTreasury.length -
                    1;
                isFtnftInTreasury[ftnft].indexInTnftMap =
                    tnftFractionsContracts[tnft].length -
                    1;
            }
            //something is added to marketplace
            fractionTokensInTreasury[ftnft].push(tokenId);
            //fill fraction data
            FractionIdData memory fData;
            fData.fractionId = tokenId;
            fData.share = ITangibleFractionsNFT(ftnft).fractionShares(tokenId);
            fData.tnft = address(ITangibleFractionsNFT(ftnft).tnft());
            fData.tnftTokenId = ITangibleFractionsNFT(ftnft).tnftTokenId();
            fractionTokensDataInTreasury[ftnft].push(fData);

            FractionTreasuryItem memory fsi = FractionTreasuryItem(
                ftnft,
                tokenId,
                (fractionTokensInTreasury[ftnft].length - 1)
            );
            fractiInTreasuryMapper[ftnft][tokenId] = fsi;
        } else {
            //something is removed from marketplace
            uint256 indexInTokenSale = fractiInTreasuryMapper[ftnft][tokenId]
                .indexInCurrentlySelling;
            _removeCurrentlySellingFraction(ftnft, indexInTokenSale);
            delete fractiInTreasuryMapper[ftnft][tokenId];
            if (fractionTokensInTreasury[ftnft].length == 0) {
                //all tokens are removed, nothing in category is selling anymore
                address tnft = _fetchTnftForFraction(ftnft);
                _removeFraction(isFtnftInTreasury[ftnft].index);
                _removeFractionFromTnftMap(
                    tnft,
                    isFtnftInTreasury[ftnft].indexInTnftMap
                );
                delete isFtnftInTreasury[ftnft];
            }
        }
    }

    function _fetchTnftForFraction(address ftnft)
        internal
        view
        returns (address tnft)
    {
        //fetch tnft address
        address marketplace = addressProvider.getAddress(
            TANGIBLE_MARKETPLACE_ADDRESS
        );
        IFactoryExt factory = ITangibleMarketplace(marketplace).factory();
        tnft = address(
            factory.fractionToTnftAndId(ITangibleFractionsNFT(ftnft)).tnft
        );
    }

    //this function is not preserving order, and we don't care about it
    function _removeCurrentlySellingFraction(address ftnft, uint256 index)
        internal
    {
        require(index < fractionTokensInTreasury[ftnft].length, "IndexF");
        //take last token
        uint256 tokenId = fractionTokensInTreasury[ftnft][
            fractionTokensInTreasury[ftnft].length - 1
        ];
        FractionIdData memory fData = fractionTokensDataInTreasury[ftnft][
            fractionTokensDataInTreasury[ftnft].length - 1
        ];

        //replace it with the one we are removing
        fractionTokensInTreasury[ftnft][index] = tokenId;
        fractionTokensDataInTreasury[ftnft][index] = fData;
        //set it's new index in saleData
        fractiInTreasuryMapper[ftnft][tokenId].indexInCurrentlySelling = index;
        fractionTokensInTreasury[ftnft].pop();
        fractionTokensDataInTreasury[ftnft].pop();
    }

    function updateFractionData(address ftnft, uint256 tokenId)
        external
        override
    {
        uint256 indexInTokenSale = fractiInTreasuryMapper[ftnft][tokenId]
            .indexInCurrentlySelling;
        fractionTokensDataInTreasury[ftnft][indexInTokenSale]
            .share = ITangibleFractionsNFT(ftnft).fractionShares(tokenId);
    }

    //this function is not preserving order, and we don't care about it
    function _removeCurrentlySellingTnft(address tnft, uint256 index) internal {
        require(index < tnftTokensInTreasury[tnft].length, "IndexT");
        //take last token
        uint256 tokenId = tnftTokensInTreasury[tnft][
            tnftTokensInTreasury[tnft].length - 1
        ];

        //replace it with the one we are removing
        tnftTokensInTreasury[tnft][index] = tokenId;
        //set it's new index in saleData
        tnftSaleMapper[tnft][tokenId].indexInCurrentlySelling = index;
        tnftTokensInTreasury[tnft].pop();
    }

    function _removeCategory(uint256 index) internal {
        require(index < tnftCategoriesInTreasury.length, "IndexC");
        //take last token
        address _tnft = tnftCategoriesInTreasury[
            tnftCategoriesInTreasury.length - 1
        ];

        //replace it with the one we are removing
        tnftCategoriesInTreasury[index] = _tnft;
        //set it's new index in saleData
        isTnftInTreasury[_tnft].index = index;
        tnftCategoriesInTreasury.pop();
    }

    function _removeFraction(uint256 index) internal {
        require(index < fractionContractsInTreasury.length, "IndexFr");
        //take last token
        address _ftnft = fractionContractsInTreasury[
            fractionContractsInTreasury.length - 1
        ];

        //replace it with the one we are removing
        fractionContractsInTreasury[index] = _ftnft;
        //set it's new index in saleData
        isFtnftInTreasury[_ftnft].index = index;
        fractionContractsInTreasury.pop();
    }

    function _removeFractionFromTnftMap(address tnft, uint256 index) internal {
        require(index < tnftFractionsContracts[tnft].length, "IndexTFr");
        //take last token
        address _ftnft = tnftFractionsContracts[tnft][
            tnftFractionsContracts[tnft].length - 1
        ];

        //replace it with the one we are removing
        tnftFractionsContracts[tnft][index] = _ftnft;
        //set it's new index in saleData
        isFtnftInTreasury[_ftnft].indexInTnftMap = index;
        tnftFractionsContracts[tnft].pop();
    }

    // segment for handling treasury item price
    struct CurrencyData {
        uint256 valueInNativeCurrency;
        uint256 valueInNativeCurrencyEscrow;
        uint256 latestOraclePrices;
        IPriceOracle currencyOracle;
        bool supported;
    }
    mapping(string => CurrencyData) public currencyInfo;
    string[] public treasuryItemsCurrencies;

    function setCurrencyData(
        string calldata currency,
        CurrencyData calldata cData
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        //just for adding in array
        if (!currencyInfo[currency].supported) {
            currencyInfo[currency].supported = true;
            treasuryItemsCurrencies.push(currency);
        }
        // set rwa that are not in escrow
        currencyInfo[currency].valueInNativeCurrency = cData
            .valueInNativeCurrency;
        //set escrow data if any
        currencyInfo[currency].valueInNativeCurrencyEscrow = cData
            .valueInNativeCurrencyEscrow;
        currencyInfo[currency].latestOraclePrices = cData
            .currencyOracle
            .latestPrices();
        currencyInfo[currency].currencyOracle = cData.currencyOracle;
    }

    function updateTotalNativeValue(
        string memory currency,
        uint256 totalValue,
        uint256 totalValueEscrow
    ) external onlyRole(CONTROLLER_ROLE) {
        currencyInfo[currency].valueInNativeCurrency = totalValue;
        currencyInfo[currency].valueInNativeCurrencyEscrow = totalValueEscrow;
        currencyInfo[currency].latestOraclePrices = currencyInfo[currency]
            .currencyOracle
            .latestPrices();
    }

    function addValueAfterPurchase(
        string calldata currency,
        uint256 value,
        bool notInEscrow,
        uint256 ptAmount,
        uint8 ptDecimals
    ) external {
        require(
            msg.sender == addressProvider.getAddress(TREASURY_ADDRESS),
            "No treasury"
        );
        address underlying = addressProvider.getAddress(UNDERLYING_ADDRESS);
        if (notInEscrow) {
            currencyInfo[currency].valueInNativeCurrency += value;
        } else {
            ptAmount = _convertToCorrectDecimals(
                ptAmount,
                ptDecimals,
                IERC20Metadata(underlying).decimals()
            );
            currencyInfo[currency].valueInNativeCurrencyEscrow += ptAmount;
        }
    }

    function _convertToCorrectDecimals(
        uint256 price,
        uint8 inTokenDecimals,
        uint8 outTokenDecimals
    ) internal pure returns (uint256) {
        if (uint256(inTokenDecimals) > outTokenDecimals) {
            return price / (10**(inTokenDecimals - outTokenDecimals));
        } else if (uint256(inTokenDecimals) < outTokenDecimals) {
            return price * (10**(outTokenDecimals - inTokenDecimals));
        }
        return price;
    }

    function subValueAfterPurchase(string calldata currency, uint256 value)
        external
    {
        require(
            msg.sender == addressProvider.getAddress(TREASURY_ADDRESS),
            "No treasury"
        );
        if (currencyInfo[currency].valueInNativeCurrency >= value) {
            currencyInfo[currency].valueInNativeCurrency -= value;
        } else {
            currencyInfo[currency].valueInNativeCurrency = 0;
        }
    }

    function removeCurrency(uint256 index)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        delete currencyInfo[treasuryItemsCurrencies[index]];
        treasuryItemsCurrencies[index] = treasuryItemsCurrencies[
            treasuryItemsCurrencies.length - 1
        ];
        treasuryItemsCurrencies.pop();
    }

    function currencySize() external view returns (uint256) {
        return treasuryItemsCurrencies.length;
    }

    function getRwaUsdValue(IERC20Metadata token)
        external
        view
        returns (
            uint256 usdValue,
            uint256 usdValueEscrow,
            bool valueNotLatest
        )
    {
        ICurrencyFeed currencyFeed = ICurrencyFeed(
            addressProvider.getAddress(CURRENCY_FEED_ADDRESS)
        );
        uint256 length = treasuryItemsCurrencies.length;
        uint8 oracleDecimal;

        for (uint256 i; i < length; i++) {
            string memory currency = treasuryItemsCurrencies[i];
            oracleDecimal = currencyInfo[currency].currencyOracle.decimals();
            if (currencyInfo[currency].supported) {
                AggregatorV3Interface priceFeed = currencyFeed
                    .currencyPriceFeeds(currency);
                (, int256 price, , , ) = priceFeed.latestRoundData();
                if (price < 0) {
                    price = 0;
                }
                //add conversion premium
                uint256 toUSDRatio = uint256(price) +
                    currencyFeed.conversionPremiums(currency);
                usdValue +=
                    (convertPriceToUSDCustom(
                        token,
                        currencyInfo[currency].valueInNativeCurrency,
                        oracleDecimal
                    ) * toUSDRatio) /
                    10**uint256(priceFeed.decimals());

                //escrow is already set to underlying decimals and is already in USD
                usdValueEscrow += currencyInfo[currency]
                    .valueInNativeCurrencyEscrow;

                //check if we have latest value of RWAs in native currencies
                if (
                    currencyInfo[currency].latestOraclePrices !=
                    currencyInfo[currency].currencyOracle.latestPrices()
                ) {
                    valueNotLatest = true;
                }
            }
        }
    }

    function convertPriceToUSDCustom(
        IERC20Metadata paymentToken,
        uint256 price,
        uint8 decimals
    ) internal view returns (uint256) {
        require(
            decimals > uint8(0) && decimals <= uint8(18),
            "Invalid _decimals"
        );
        if (uint256(decimals) > paymentToken.decimals()) {
            return price / (10**(uint256(decimals) - paymentToken.decimals()));
        } else if (uint256(decimals) < paymentToken.decimals()) {
            return price * (10**(paymentToken.decimals() - uint256(decimals)));
        }
        return price;
    }
}
