// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "../tangibleInterfaces/ITangibleInterfaces.sol";
import "../AddressAccessor.sol";
import "../constants/roles.sol";

abstract contract OnSaleTracker is AddressAccessor {
    struct TokenArray {
        uint256[] tokenIds;
    }
    struct ContractItem {
        bool selling;
        uint256 index;
    }

    struct TnftSaleItem {
        ITangibleNFT tnft;
        uint256 tokenId;
        uint256 indexInCurrentlySelling;
    }

    struct FractionSaleItem {
        ITangibleFractionsNFT ftnft;
        uint256 fractionId;
        uint256 indexInCurrentlySelling;
    }

    ITangibleFractionsNFT[] public fractionContractsOnSale;
    mapping(ITangibleFractionsNFT => ContractItem) public isFtnftOnSale;
    mapping(ITangibleFractionsNFT => uint256[]) public fractionTokensOnSale;
    mapping(ITangibleFractionsNFT => mapping(uint256 => FractionSaleItem))
        public fractionSaleMapper;

    //return whole array
    function getFractionContractsOnSale()
        external
        view
        returns (ITangibleFractionsNFT[] memory)
    {
        return fractionContractsOnSale;
    }

    //return size
    function fractionContractsOnSaleSize() external view returns (uint256) {
        return fractionContractsOnSale.length;
    }

    //return whole array
    function getFractionTokensOnSale(ITangibleFractionsNFT ftnft)
        external
        view
        returns (uint256[] memory)
    {
        return fractionTokensOnSale[ftnft];
    }

    //return whole batch arrays
    function getFractionTokensOnSaleBatch(
        ITangibleFractionsNFT[] calldata ftnfts
    ) external view returns (TokenArray[] memory result) {
        uint256 length = ftnfts.length;
        result = new TokenArray[](length);
        for (uint256 i; i < length; i++) {
            TokenArray memory temp = TokenArray(
                fractionTokensOnSale[ftnfts[i]]
            );
            result[i] = temp;
        }
        return result;
    }

    //return size
    function fractionTokensOnSaleSize(ITangibleFractionsNFT ftnft)
        external
        view
        returns (uint256)
    {
        return fractionTokensOnSale[ftnft].length;
    }

    ITangibleNFT[] public tnftCategoriesOnSale;
    mapping(ITangibleNFT => ContractItem) public isTnftOnSale;
    mapping(ITangibleNFT => uint256[]) public tnftTokensOnSale;
    mapping(ITangibleNFT => mapping(uint256 => TnftSaleItem))
        public tnftSaleMapper;

    //return whole array
    function getTnftCategoriesOnSale()
        external
        view
        returns (ITangibleNFT[] memory)
    {
        return tnftCategoriesOnSale;
    }

    //return size
    function tnftCategoriesOnSaleSize() external view returns (uint256) {
        return tnftCategoriesOnSale.length;
    }

    //return whole array
    function getTnftTokensOnSale(ITangibleNFT tnft)
        external
        view
        returns (uint256[] memory)
    {
        return tnftTokensOnSale[tnft];
    }

    //return whole batch arrays
    function getTnftTokensOnSaleBatch(ITangibleNFT[] calldata tnfts)
        external
        view
        returns (TokenArray[] memory result)
    {
        uint256 length = tnfts.length;
        result = new TokenArray[](length);
        for (uint256 i; i < length; i++) {
            TokenArray memory temp = TokenArray(tnftTokensOnSale[tnfts[i]]);
            result[i] = temp;
        }
        return result;
    }

    //return size
    function tnftTokensOnSaleSize(ITangibleNFT tnft)
        external
        view
        returns (uint256)
    {
        return tnftTokensOnSale[tnft].length;
    }

    function tnftSalePlacedExt(
        ITangibleNFT tnft,
        uint256 tokenId,
        bool place
    ) external onlyRole(CONTROLLER_ROLE) {
        tnftSalePlaced(tnft, tokenId, place);
    }

    function tnftSalePlaced(
        ITangibleNFT tnft,
        uint256 tokenId,
        bool place
    ) internal {
        if (place) {
            //check if something from this category is on sale already
            if (!isTnftOnSale[tnft].selling) {
                //add category to actively selling list
                tnftCategoriesOnSale.push(tnft);
                isTnftOnSale[tnft].selling = true;
                isTnftOnSale[tnft].index = tnftCategoriesOnSale.length - 1;
            }
            //something is added to marketplace

            tnftTokensOnSale[tnft].push(tokenId);
            TnftSaleItem memory tsi = TnftSaleItem(
                tnft,
                tokenId,
                (tnftTokensOnSale[tnft].length - 1)
            );
            tnftSaleMapper[tnft][tokenId] = tsi;
        } else {
            //something is removed from marketplace
            uint256 indexInTokenSale = tnftSaleMapper[tnft][tokenId]
                .indexInCurrentlySelling;
            _removeCurrentlySellingTnft(tnft, indexInTokenSale);
            delete tnftSaleMapper[tnft][tokenId];
            if (tnftTokensOnSale[tnft].length == 0) {
                //all tokens are removed, nothing in category is selling anymore
                _removeCategory(isTnftOnSale[tnft].index);
                delete isTnftOnSale[tnft];
            }
        }
    }

    function ftnftSalePlacedExt(
        ITangibleFractionsNFT ftnft,
        uint256 tokenId,
        bool place
    ) external onlyRole(CONTROLLER_ROLE) {
        ftnftSalePlaced(ftnft, tokenId, place);
    }

    function ftnftSalePlaced(
        ITangibleFractionsNFT ftnft,
        uint256 tokenId,
        bool place
    ) internal {
        if (place) {
            //check if something from this category is on sale already
            if (!isFtnftOnSale[ftnft].selling) {
                //add category to actively selling list
                fractionContractsOnSale.push(ftnft);
                isFtnftOnSale[ftnft].selling = true;
                isFtnftOnSale[ftnft].index = fractionContractsOnSale.length - 1;
            }
            //something is added to marketplace
            fractionTokensOnSale[ftnft].push(tokenId);
            FractionSaleItem memory fsi = FractionSaleItem(
                ftnft,
                tokenId,
                (fractionTokensOnSale[ftnft].length - 1)
            );
            fractionSaleMapper[ftnft][tokenId] = fsi;
        } else {
            //something is removed from marketplace
            uint256 indexInTokenSale = fractionSaleMapper[ftnft][tokenId]
                .indexInCurrentlySelling;
            _removeCurrentlySellingFraction(ftnft, indexInTokenSale);
            delete fractionSaleMapper[ftnft][tokenId];
            if (fractionTokensOnSale[ftnft].length == 0) {
                //all tokens are removed, nothing in category is selling anymore
                _removeFraction(isFtnftOnSale[ftnft].index);
                delete isFtnftOnSale[ftnft];
            }
        }
    }

    //this function is not preserving order, and we don't care about it
    function _removeCurrentlySellingFraction(
        ITangibleFractionsNFT ftnft,
        uint256 index
    ) internal {
        require(index < fractionTokensOnSale[ftnft].length, "IndexF");
        //take last token
        uint256 tokenId = fractionTokensOnSale[ftnft][
            fractionTokensOnSale[ftnft].length - 1
        ];

        //replace it with the one we are removing
        fractionTokensOnSale[ftnft][index] = tokenId;
        //set it's new index in saleData
        fractionSaleMapper[ftnft][tokenId].indexInCurrentlySelling = index;
        fractionTokensOnSale[ftnft].pop();
    }

    //this function is not preserving order, and we don't care about it
    function _removeCurrentlySellingTnft(ITangibleNFT tnft, uint256 index)
        internal
    {
        require(index < tnftTokensOnSale[tnft].length, "IndexT");
        //take last token
        uint256 tokenId = tnftTokensOnSale[tnft][
            tnftTokensOnSale[tnft].length - 1
        ];

        //replace it with the one we are removing
        tnftTokensOnSale[tnft][index] = tokenId;
        //set it's new index in saleData
        tnftSaleMapper[tnft][tokenId].indexInCurrentlySelling = index;
        tnftTokensOnSale[tnft].pop();
    }

    function _removeCategory(uint256 index) internal {
        require(index < tnftCategoriesOnSale.length, "IndexC");
        //take last token
        ITangibleNFT _tnft = tnftCategoriesOnSale[
            tnftCategoriesOnSale.length - 1
        ];

        //replace it with the one we are removing
        tnftCategoriesOnSale[index] = _tnft;
        //set it's new index in saleData
        isTnftOnSale[_tnft].index = index;
        tnftCategoriesOnSale.pop();
    }

    function _removeFraction(uint256 index) internal {
        require(index < fractionContractsOnSale.length, "IndexFr");
        //take last token
        ITangibleFractionsNFT _ftnft = fractionContractsOnSale[
            fractionContractsOnSale.length - 1
        ];

        //replace it with the one we are removing
        fractionContractsOnSale[index] = _ftnft;
        //set it's new index in saleData
        isFtnftOnSale[_ftnft].index = index;
        fractionContractsOnSale.pop();
    }
}
