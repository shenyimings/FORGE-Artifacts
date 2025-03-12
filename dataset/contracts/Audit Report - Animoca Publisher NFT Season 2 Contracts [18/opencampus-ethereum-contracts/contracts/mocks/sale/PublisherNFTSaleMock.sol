// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC1155} from "@animoca/ethereum-contracts/contracts/token/ERC1155/interfaces/IERC1155.sol";
import {IForwarderRegistry} from "@animoca/ethereum-contracts/contracts/metatx/interfaces/IForwarderRegistry.sol";
import {ILayerZeroEndpoint} from "@layerzerolabs/solidity-examples/contracts/interfaces/ILayerZeroEndpoint.sol";
import {EDUCreditsManager} from "./../../payment/EDUCreditsManager.sol";
import {PublisherNFTSale} from "./../../sale/PublisherNFTSale.sol";

contract PublisherNFTSaleMock is PublisherNFTSale {
    constructor(
        IERC1155 genesisToken,
        EDUCreditsManager eduCreditsManager,
        ILayerZeroEndpoint lzEndpoint,
        uint16 lzDstChainId,
        uint256 mintPrice,
        uint256 mintSupplyLimit,
        uint256 mintLimitPerAddress,
        uint256[] memory timestamps,
        uint256[] memory discountThresholds,
        uint256[] memory discountPercentages,
        IForwarderRegistry forwarderRegistry
    )
        PublisherNFTSale(
            genesisToken,
            eduCreditsManager,
            lzEndpoint,
            lzDstChainId,
            mintPrice,
            mintSupplyLimit,
            mintLimitPerAddress,
            timestamps,
            discountThresholds,
            discountPercentages,
            forwarderRegistry
        )
    {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
