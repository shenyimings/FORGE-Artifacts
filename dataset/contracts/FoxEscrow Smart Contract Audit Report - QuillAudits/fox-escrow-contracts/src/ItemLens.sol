// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./interfaces/IERC20.sol";
import "./interfaces/IItemOffer.sol";
import "./interfaces/IItemOfferFactory.sol";
import "./interfaces/IOwnable.sol";

contract ItemLens {
    // supported stablecoins
    address public constant USDC = 0xC6A6cD8E4a0134b37E3595DBac6f738970fC01A6; //0x985458E523dB3d53125813eD68c274899e9DfAb4;
    address public constant USDT = 0xC6A6cD8E4a0134b37E3595DBac6f738970fC01A6; // 0x3C2B8Be99c50593081EAA2A724F0B8285F5aba8f;
    address public constant DAI = 0xC6A6cD8E4a0134b37E3595DBac6f738970fC01A6; // 0xEf977d2f931C1978Db5F6747666fa1eACB0d0339;
    address public constant UST = 0xE6FCfd410a993572713c47a3638478288d06aB2d; //0x224e64ec1BDce3870a6a6c777eDd450454068FEC;
    address public constant BUSD = 0x3F9E6D6328D83690d74a75C016D90D7e26A7188c; //0xE176EBE47d621b984a73036B9DA5d834411ef734;

    function getVolume(IItemOfferFactory factory) public view returns (uint256 sum) {
        address[5] memory stables = [USDC, USDT, DAI, UST, BUSD];
        address factoryOwner = IOwnable(address(factory)).owner();

        uint256 volume;
        for (uint256 i; i < stables.length; i++) {
            volume += IERC20(stables[i]).balanceOf(factoryOwner) * (10**(18 - IERC20(stables[i]).decimals()));
        }
        sum = volume * 100;
    }

    function getOfferInfo(IItemOffer offer)
        public
        view
        returns (
            address itemAddress,
            uint256 totalItems,
            address tokenWanted,
            uint256 priceWanted
        )
    {
        return (
            offer.itemAddress(),
            offer.totalItems(),
            offer.tokenWanted(),
            offer.priceWanted()
        );
    }

    function getActiveOffersPruned(IItemOfferFactory factory) public view returns (IItemOffer[] memory) {
        IItemOffer[] memory activeOffers = factory.getActiveOffers();
        // determine size of memory array
        uint count;
        for (uint i; i < activeOffers.length; i++) {
            if (address(activeOffers[i]) != address(0)) {
                count++;
            }
        }
        IItemOffer[] memory pruned = new IItemOffer[](count);
        for (uint j; j < count; j++) {
            pruned[j] = activeOffers[j];
        }
        return pruned;
    }

    function getAllActiveOfferInfo(IItemOfferFactory factory)
        public
        view
        returns (
            address[] memory itemAddresses,
            address[] memory offerAddresses,
            uint256[] memory itemBalances,
            address[] memory tokenWanted,
            uint256[] memory priceWanted
        )
    {
        IItemOffer[] memory activeOffers = factory.getActiveOffers();
        uint256 offersLength = activeOffers.length;
        itemAddresses = new address[](offersLength);
        offerAddresses = new address[](offersLength);
        itemBalances = new uint256[](offersLength);
        tokenWanted = new address[](offersLength);
        priceWanted = new uint256[](offersLength);
        uint256 count;
        for (uint256 i; i < activeOffers.length; i++) {
            if (address(activeOffers[i]) != address(0)) {
                address itemAddress = activeOffers[i].itemAddress();
                uint256 bal = activeOffers[i].totalItems();
                if (bal > 0) {
                    itemAddresses[count] = itemAddress;
                    offerAddresses[count] = address(activeOffers[i]);
                    itemBalances[count] = bal;
                    tokenWanted[count] = activeOffers[i].tokenWanted();
                    priceWanted[count] = activeOffers[i].priceWanted();
                    count++;
                }
            }
        }
    }
}
