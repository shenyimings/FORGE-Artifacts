// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./interfaces/IERC20.sol";
import "./interfaces/ILockedToken.sol";
import "./interfaces/ILockedTokenOffer.sol";
import "./interfaces/IOfferFactory.sol";
import "./interfaces/IOwnable.sol";

contract LockedTokenLens {
    // supported stablecoins
    address public constant USDC = 0xC6A6cD8E4a0134b37E3595DBac6f738970fC01A6; //0x985458E523dB3d53125813eD68c274899e9DfAb4;
    address public constant USDT = 0xC6A6cD8E4a0134b37E3595DBac6f738970fC01A6; // 0x3C2B8Be99c50593081EAA2A724F0B8285F5aba8f;
    address public constant DAI = 0xC6A6cD8E4a0134b37E3595DBac6f738970fC01A6; // 0xEf977d2f931C1978Db5F6747666fa1eACB0d0339;
    address public constant UST = 0xE6FCfd410a993572713c47a3638478288d06aB2d; //0x224e64ec1BDce3870a6a6c777eDd450454068FEC;
    address public constant BUSD = 0x3F9E6D6328D83690d74a75C016D90D7e26A7188c; //0xE176EBE47d621b984a73036B9DA5d834411ef734;

    function getVolume(IOfferFactory factory) external view returns (uint256 sum) {
        address[5] memory stables = [USDC, USDT, DAI, UST, BUSD];
        address factoryOwner = IOwnable(address(factory)).owner();

        uint256 volume;
        for (uint256 i; i < stables.length; i++) {
            volume += IERC20(stables[i]).balanceOf(factoryOwner) * (10**(18 - IERC20(stables[i]).decimals()));
        }
        sum = volume * 100;
    }

    function getOfferInfo(ILockedTokenOffer offer)
        external
        view
        returns (
            address lockedToken,
            uint256 lockedTokenBalance,
            address tokenWanted,
            uint256 amountWanted
        )
    {
        return (
            offer.lockedTokenAddress(),
            ILockedToken(offer.lockedTokenAddress()).totalBalanceOf(address(offer)),
            offer.tokenWanted(),
            offer.amountWanted()
        );
    }

    function getActiveOffersPruned(IOfferFactory factory) external view returns (ILockedTokenOffer[] memory) {
        ILockedTokenOffer[] memory activeOffers = factory.getActiveOffers();
        // determine size of memory array
        uint count;
        for (uint i; i < activeOffers.length; i++) {
            if (address(activeOffers[i]) != address(0)) {
                count++;
            }
        }
        ILockedTokenOffer[] memory pruned = new ILockedTokenOffer[](count);
        for (uint j; j < count; j++) {
            pruned[j] = activeOffers[j];
        }
        return pruned;
    }

    function getAllActiveOfferInfo(IOfferFactory factory)
    external
    view
    returns (
        address[] memory lockedTokens,
        address[] memory offerAddresses,
        uint256[] memory lockedBalances,
        address[] memory tokenWanted,
        uint256[] memory amountWanted
    )
    {
        ILockedTokenOffer[] memory offers = factory.getActiveOffers();
        uint256 offersLength = offers.length;
        lockedTokens = new address[](offersLength);
        offerAddresses = new address[](offersLength);
        lockedBalances = new uint256[](offersLength);
        tokenWanted = new address[](offersLength);
        amountWanted = new uint256[](offersLength);
        uint256 count;
        for (uint256 i; i < offers.length; i++) {
            if (address(offers[i]) != address(0)) {
                address lockedTokenAddress = offers[i].lockedTokenAddress();
                uint256 bal = offers[i].totalLockedToken();
                if (bal > 0) {
                    lockedTokens[count] = lockedTokenAddress;
                    lockedBalances[count] = bal;
                    offerAddresses[count] = address(offers[i]);
                    tokenWanted[count] = offers[i].tokenWanted();
                    amountWanted[count] = offers[i].amountWanted();
                    count++;
                }
            }
        }
    }

    function getOfferInfo(ILockedTokenOffer[] calldata offers)
        public
        view
        returns (
            address[] memory lockedTokens,
            address[] memory offerAddresses,
            uint256[] memory lockedBalances,
            address[] memory tokenWanted,
            uint256[] memory amountWanted
        )
    {
        uint256 offersLength = offers.length;
        lockedTokens = new address[](offersLength);
        offerAddresses = new address[](offersLength);
        lockedBalances = new uint256[](offersLength);
        tokenWanted = new address[](offersLength);
        amountWanted = new uint256[](offersLength);
        uint256 count;
        for (uint256 i; i < offers.length; i++) {
            if (address(offers[i]) != address(0)) {
                address lockedTokenAddress = offers[i].lockedTokenAddress();
                uint256 bal = offers[i].totalLockedToken();
                if (bal > 0) {
                    lockedTokens[count] = lockedTokenAddress;
                    lockedBalances[count] = bal;
                    offerAddresses[count] = address(offers[i]);
                    tokenWanted[count] = offers[i].tokenWanted();
                    amountWanted[count] = offers[i].amountWanted();
                    count++;
                }
            }
        }
    }
}
